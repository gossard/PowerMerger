<#
NOTE: While this class centralizes syntax rules, an implicit contract exists between consumers like the Formatter, Parser, etc.
They must remain perfectly synchronized. Any change here must be carefully reflected across all consumers to prevent desynchronization.
#>
class FieldSyntax {

    [string]$FieldWrapper
    [string]$FieldPartSeparator
    [string]$ModifierArgumentSeparator

    [string]$FieldWrapperTemplate
    [string]$FieldContentTemplate
    [string]$ModifierFormattingTemplate

    [string]$FieldContentExtractionPattern
    [string]$FindingPattern
    [string]$ModifierPattern

    FieldSyntax([string]$FieldWrapper) {
        $this.Initialize($FieldWrapper, '|', ':')
    }

    hidden [void]Initialize([string]$FieldWrapper, [string]$FieldPartSeparator, [string]$ModifierArgumentSeparator) {
        $this._requireNonNullOrWhiteSpace($FieldWrapper, "FieldWrapper")
        $this._requireNonNullOrWhiteSpace($FieldPartSeparator, "FieldPartSeparator")
        $this._requireNonNullOrWhiteSpace($ModifierArgumentSeparator, "ModifierArgumentSeparator")
        $this._requireDifferent($FieldWrapper, "FieldWrapper", $FieldPartSeparator, "FieldPartSeparator")
        $this._requireDifferent($FieldWrapper, "FieldWrapper", $ModifierArgumentSeparator, "ModifierArgumentSeparator")
        $this._requireDifferent($FieldPartSeparator, "FieldPartSeparator", $ModifierArgumentSeparator, "ModifierArgumentSeparator")

        $this.FieldWrapper = $FieldWrapper
        $this.FieldPartSeparator = $FieldPartSeparator
        $this.ModifierArgumentSeparator = $ModifierArgumentSeparator

        $this.FieldWrapperTemplate = "$($this.FieldWrapper){0}$($this.FieldWrapper)"
        $this.FieldContentTemplate = "{0}$($this.FieldPartSeparator){1}"
        $this.ModifierFormattingTemplate = "{0}$($this.ModifierArgumentSeparator){1}"

        [string]$EscapedWrapper = [regex]::Escape($this.FieldWrapper)
        [string]$EscapedModifierArgumentSeparator = [regex]::Escape($this.ModifierArgumentSeparator)

        $this.FieldContentExtractionPattern = "$($EscapedWrapper)(.*?)$($EscapedWrapper)"
        $this.FindingPattern = "$($EscapedWrapper).*?$($EscapedWrapper)"

        <#
        Pattern for a modifier string (e.g., "tolower", "orelse : 'default'").
        ^\s*                    - Start anchor, optional leading whitespace.
        (\w+)                   - Capture group 1: The identifier (e.g., "orelse").
        \s*                     - Optional whitespace between identifier and separator.
        (?:...)?                - Optional non-capturing group for the argument part.
            $($...Separator)\s* - The separator, then optional whitespace.
            (.*)                - Capture group 2: The argument.
        $                       - End anchor.
        #>
        $this.ModifierPattern = "^\s*(\w+)\s*(?:$($EscapedModifierArgumentSeparator)\s*(.*))?$"
    }

    hidden [void]_requireNonNullOrWhiteSpace([string]$Value, [string]$Name) {
        if([string]::IsNullOrWhiteSpace($Value)) {
            throw [ArgumentException]::new("{0} cannot be null or empty." -f $Name)
        }
    }

    hidden [void]_requireDifferent([string]$LeftValue, [string]$LeftName, [string]$RightValue, [string]$RightName) {
        if($LeftValue -eq $RightValue) {
            throw [ArgumentException]::new("{0}('{1}') and {2}('{3}') cannot be the same." -f $LeftName, $LeftValue, $RightName, $RightValue)
        }
    }

}

class FieldFormatter {

    [FieldSyntax]$Syntax

    FieldFormatter([FieldSyntax]$Syntax) {
        if($null -eq $Syntax) {
            throw [System.ArgumentException]::new("Syntax cannot be null.")
        }
        $this.Syntax = $Syntax
    }

    [string]Format([string]$Selector, [List[ModifierEntry]]$Modifiers) {
        return $this._wrap($this._formatContent($Selector, $Modifiers))
    }

    hidden [string]_wrap([string]$Content) {
        return $this.Syntax.FieldWrapperTemplate -f $Content
    }

    hidden [string]_formatModifier([ModifierEntry]$Modifier) {
        if(-not $Modifier.HasArgument) {
            return $Modifier.Identifier
        }
        return $this.Syntax.ModifierFormattingTemplate -f $Modifier.Identifier, $Modifier.Argument
    }

    hidden [string]_formatModifiers([List[ModifierEntry]]$Modifiers) {
        return ($Modifiers | ForEach-Object { $this._formatModifier($_) }) -join $this.Syntax.FieldPartSeparator
    }

    hidden [string]_formatContent([string]$Selector, [List[ModifierEntry]]$Modifiers) {
        if(($null -eq $Modifiers) -or ($Modifiers.Count -eq 0)) {
            return $Selector
        }
        return $this.Syntax.FieldContentTemplate -f $Selector, $this._formatModifiers($Modifiers)
    }

}

class FieldParser {

    [FieldSyntax]$Syntax
    hidden [hashtable]$_fieldCache

    FieldParser([FieldSyntax]$Syntax) {
        if($null -eq $Syntax) {
            throw [System.ArgumentException]::new("Syntax cannot be null.")
        }
        $this.Syntax = $Syntax
        $this._fieldCache = @{}
    }

    [List[Field]]ParseAll([object]$Template) {
        if($null -eq $Template) {
            return [List[Field]]::new()
        }
        [hashtable]$UniqueFields = [ordered]@{}

        $AllMatches = [regex]::Matches($Template, $this.Syntax.FindingPattern)

        foreach($Match in $AllMatches) {
            [string]$RawTextField = $Match.Value
            $UniqueFields[$RawTextField] = $this.Parse($RawTextField)
        }

        [List[Field]]$Fields = [List[Field]]::new()
        foreach($Field in $UniqueFields.Values) {
            $Fields.Add($Field)
        }
        return $Fields
    }

    [Field]Parse([string]$RawTextField) {
        if([string]::IsNullOrWhiteSpace($RawTextField)) {
            return [Field]::CreateEmpty()
        }
        if($this._fieldCache.ContainsKey($RawTextField)) {
            return $this._fieldCache[$RawTextField]
        }
        [string]$Content = $this._extractContent($RawTextField)
        if([string]::IsNullOrWhiteSpace($Content)) {
            return [Field]::CreateEmpty()
        }
        [string[]]$SelectorAndModifiers = $Content.Split($this.Syntax.FieldPartSeparator, 2)
        [string]$Selector = $SelectorAndModifiers[0].Trim()
        [List[ModifierEntry]]$Modifiers = $null

        if($SelectorAndModifiers.Length -gt 1) {
            $Modifiers = $this._parseModifiers($SelectorAndModifiers[1])
        } else {
            $Modifiers = [List[ModifierEntry]]::new()
        }
        [Field]$Field = [Field]::Create($RawTextField, $Selector, $Modifiers)
        $this._fieldCache[$RawTextField] = $Field
        return $Field
    }

    hidden [string]_removeQuotes([string]$Str) {
        if([string]::IsNullOrWhiteSpace($Str)) {
            return [string]::Empty
        }
        if(($Str.StartsWith('"') -and $Str.EndsWith('"')) -or ($Str.StartsWith("'") -and $Str.EndsWith("'"))) {
            return $Str.Substring(1, $Str.Length - 2)
        }
        return $Str
    }

    hidden [string]_extractContent([string]$RawTextField) {
        [Match]$Match = [regex]::Match($RawTextField, $this.Syntax.FieldContentExtractionPattern)
        if(-not $Match.Success) {
            return [string]::Empty
        }
        return $Match.Groups[1].Value
    }

    hidden [ModifierEntry]_parseModifier([string]$ModifierString) {
        [Match]$Match = [regex]::Match($ModifierString, $this.Syntax.ModifierPattern)
        if(-not $Match.Success) {
            throw "Bad modifier format: {0}." -f $ModifierString
        }
        [string]$Identifier = $Match.Groups[1].Value.Trim().ToLower()

        if($Match.Groups[2].Success) {
            [string]$Argument = $this._removeQuotes($Match.Groups[2].Value.Trim())
            return [ModifierEntry]::CreateWithArgument($Identifier, $Argument)
        }
        return [ModifierEntry]::CreateWithoutArgument($Identifier)
    }

    hidden [List[ModifierEntry]]_parseModifiers([string]$ModifiersString) {
        if([string]::IsNullOrWhiteSpace($ModifiersString)) {
            return [List[ModifierEntry]]::new()
        }
        [List[ModifierEntry]]$Modifiers = [List[ModifierEntry]]::new()
        [string[]]$EachModifier = $ModifiersString.Split($this.Syntax.FieldPartSeparator)
        foreach($Modifier in $EachModifier) {
            $Modifiers.Add($this._parseModifier($Modifier))
        }
        return $Modifiers
    }

}