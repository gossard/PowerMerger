# Built on 09/04/2025 14:42:59

# --- Content from PreContent.ps1 ---

using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions
using namespace System.Management.Automation

# --- Content from 00.extractor.ps1 ---

class ValueExtractionResult {

    [bool]$Found
    [object]$ExtractedValue

    hidden ValueExtractionResult([bool]$Found, [object]$ExtractedValue) {
        $this.Found = $Found
        $this.ExtractedValue = $ExtractedValue
    }

    static [ValueExtractionResult]Found([object]$ExtractedValue) {
        return [ValueExtractionResult]::new($true, $ExtractedValue)
    }

    static [ValueExtractionResult]NotFound() {
        return [ValueExtractionResult]::new($false, $null)
    }

}

<# abstract #> class ValueExtractor {

    <# abstract #> [ValueExtractionResult]ExtractValue([string]$Selector, [object]$DataSource) {
        throw [NotImplementedException]::new()
    }

}

class PropertyValueExtractor : ValueExtractor {

    PropertyValueExtractor() : base() {}

    [ValueExtractionResult]ExtractValue([string]$Selector, [object]$DataSource) {
        if([string]::IsNullOrWhiteSpace($Selector)) {
            return [ValueExtractionResult]::NotFound()
        }
        [string[]]$Properties = $Selector.Split('.')
        [object]$CurrentValue = $DataSource

        foreach($Property in $Properties) {
            if($null -eq $CurrentValue) {
                return [ValueExtractionResult]::NotFound()
            }
            [PSPropertyInfo]$PropertyInfo = $CurrentValue.psobject.Properties[$Property]
            if($null -eq $PropertyInfo) {
                return [ValueExtractionResult]::NotFound()
            }
            $CurrentValue = $PropertyInfo.Value
        }
        return [ValueExtractionResult]::Found($CurrentValue)
    }

}

class HashtableValueExtractor : ValueExtractor {

    HashtableValueExtractor() : base() {}

    [ValueExtractionResult]ExtractValue([string]$Selector, [object]$DataSource) {
        if([string]::IsNullOrWhiteSpace($Selector) -or ($DataSource -isnot [hashtable])) {
            return [ValueExtractionResult]::NotFound()
        }
        if($DataSource.ContainsKey($Selector)) {
            return [ValueExtractionResult]::Found($DataSource[$Selector])
        } else {
            return [ValueExtractionResult]::NotFound()
        }
    }

}

class SmartValueExtractor : ValueExtractor {

    hidden [ValueExtractor]$_propertyExtractor
    hidden [ValueExtractor]$_hashtableExtractor

    SmartValueExtractor() : base() {
        $this._propertyExtractor = [PropertyValueExtractor]::new()
        $this._hashtableExtractor = [HashtableValueExtractor]::new()
    }

    [ValueExtractionResult]ExtractValue([string]$Selector, [object]$DataSource) {
        if($null -eq $DataSource) {
            return [ValueExtractionResult]::NotFound()
        }
        if($DataSource -is [hashtable]) {
            return $this._hashtableExtractor.ExtractValue($Selector, $DataSource)
        }
        return $this._propertyExtractor.ExtractValue($Selector, $DataSource)
    }

}

# --- Content from 01.field.object.ps1 ---

class ModifierEntry {

    [string]$Identifier
    [string]$Argument
    [bool]$HasArgument

    hidden ModifierEntry([string]$Identifier, [string]$Argument, [bool]$HasArgument) {
        $this.Identifier = $Identifier
        $this.Argument = $Argument
        $this.HasArgument = $HasArgument
    }

    static [ModifierEntry]CreateWithArgument([string]$Identifier, [string]$Argument) {
        return [ModifierEntry]::new([ModifierEntry]::_validateIdentifier($Identifier), $Argument, $true)
    }

    static [ModifierEntry]CreateWithoutArgument([string]$Identifier) {
        return [ModifierEntry]::new([ModifierEntry]::_validateIdentifier($Identifier), $null, $false)
    }

    hidden static [string]_validateIdentifier([string]$Identifier) {
        if([string]::IsNullOrWhiteSpace($Identifier)) {
            throw [ArgumentException]::new('Identifier cannot be null or empty.')
        }
        return $Identifier
    }

}

class Field {

    [string]$RawText
    [string]$Selector
    [List[ModifierEntry]]$Modifiers

    hidden Field([string]$RawText, [string]$Selector, [List[ModifierEntry]]$Modifiers) {
        $this.RawText = $RawText
        $this.Selector = $Selector
        $this.Modifiers = $Modifiers
    }

    static [Field]Create([string]$RawText, [string]$Selector, [List[ModifierEntry]]$Modifiers) {
        if([string]::IsNullOrWhiteSpace($RawText)) {
            throw [ArgumentException]::new('RawText cannot be null or empty.')
        }
        if([string]::IsNullOrWhiteSpace($Selector)) {
            throw [ArgumentException]::new('Selector cannot be null or empty.')
        }
        if($null -eq $Modifiers) {
            throw [ArgumentException]::new('Modifiers cannot be null.')
        }
        return [Field]::new($RawText, $Selector, $Modifiers)
    }

    static [Field]CreateEmpty() {
        return [Field]::new([string]::Empty, [string]::Empty, [List[ModifierEntry]]::new())
    }

    [string]ToString() {
        return $this.RawText
    }

}

# --- Content from 02.field.modifier.ps1 ---

<# abstract #> class FieldModifier {

    <# abstract #> [string]GetIdentifier() {
        throw [NotImplementedException]::new()
    }

    <# abstract #> [object]GetModifiedValue([object]$DataSource, [string]$Selector, [object]$ResolvedValue, [string]$ModifierArgument) {
        throw [NotImplementedException]::new()
    }

}

class OrElseModifier : FieldModifier {

    OrElseModifier() : base() {}

    [string]GetIdentifier() {
        return "orelse"
    }

    [object]GetModifiedValue([object]$DataSource, [string]$Selector, [object]$ResolvedValue, [string]$ModifierArgument) {
        if($null -eq $ResolvedValue) {
            return $ModifierArgument
        }
        if(($ResolvedValue -is [string]) -and ($ResolvedValue.Length -eq 0)) {
            return $ModifierArgument
        }
        return $ResolvedValue
    }

}

class ToLowerModifier : FieldModifier {

    ToLowerModifier() : base() {}

    [string]GetIdentifier() {
        return "tolower"
    }

    [object]GetModifiedValue([object]$DataSource, [string]$Selector, [object]$ResolvedValue, [string]$ModifierArgument) {
        if($null -eq $ResolvedValue) {
            return $null
        }
        return $ResolvedValue.ToString().ToLower()
    }

}

class ToUpperModifier : FieldModifier {

    ToUpperModifier() : base() {}

    [string]GetIdentifier() {
        return "toupper"
    }

    [object]GetModifiedValue([object]$DataSource, [string]$Selector, [object]$ResolvedValue, [string]$ModifierArgument) {
        if($null -eq $ResolvedValue) {
            return $null
        }
        return $ResolvedValue.ToString().ToUpper()
    }

}

# --- Content from 03.field.format.ps1 ---

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

# --- Content from 04.field.factory.ps1 ---

class FieldFactory {

    [FieldFormatter]$FieldFormatter

    FieldFactory([FieldFormatter]$FieldFormatter) {
        if($null -eq $FieldFormatter) {
            throw [ArgumentException]::new("FieldFormatter cannot be null.")
        }
        $this.FieldFormatter = $FieldFormatter
    }

    [Field]CreateFromSelector([string]$Selector) {
        return $this.CreateFromComponents($Selector, [List[ModifierEntry]]::new())
    }

    [Field]CreateFromComponents([String]$Selector, [List[ModifierEntry]]$Modifiers) {
        [string]$RawTextField = $this.FieldFormatter.Format($Selector, $Modifiers)
        return [Field]::Create($RawTextField, $Selector, $Modifiers)
    }

}

# --- Content from 05.field.resolution.ps1 ---

class FieldResolver {

    [ValueExtractor]$ValueExtractor
    [Dictionary[string, FieldModifier]]$Modifiers

    FieldResolver() {
        $this.ValueExtractor = [SmartValueExtractor]::new()
        $this.Modifiers = [Dictionary[string, FieldModifier]]::new()
        $this._registerDefaultModifiers()
    }

    hidden [void]_registerDefaultModifiers() {
        $this._registerModifier([OrElseModifier]::new())
        $this._registerModifier([ToLowerModifier]::new())
        $this._registerModifier([ToUpperModifier]::new())
    }

    hidden [void]_registerModifier([FieldModifier]$Modifier) {
        $this.Modifiers.Add($Modifier.GetIdentifier().ToLower(), $Modifier)
    }

    [object]Resolve([Field]$Field, [object]$DataSource) {
        return $this.Resolve($Field, $DataSource, $null)
    }

    [object]Resolve([Field]$Field, [object]$DataSource, [object]$FallbackDataSource) {
        [ValueExtractionResult]$PrimaryResult = $this.ValueExtractor.ExtractValue($Field.Selector, $DataSource)
        if($PrimaryResult.Found) {
            return $this.ApplyModifiers($Field, $DataSource, $PrimaryResult.ExtractedValue)
        }
        if($null -ne $FallbackDataSource) {
            [ValueExtractionResult]$FallbackResult = $this.ValueExtractor.ExtractValue($Field.Selector, $FallbackDataSource)
            if($FallbackResult.Found) {
                return $this.ApplyModifiers($Field, $FallbackDataSource, $FallbackResult.ExtractedValue)
            }
        }
        return $this.ApplyModifiers($Field, $DataSource, $null)
    }

    [object]ApplyModifiers([Field]$Field, [object]$DataSource, [object]$ResolvedValue) {
        foreach($ModifierEntry in $Field.Modifiers) {
            if($this.Modifiers.ContainsKey($ModifierEntry.Identifier)) {
                [FieldModifier]$Modifier = $this.Modifiers[$ModifierEntry.Identifier]
                $ResolvedValue = $Modifier.GetModifiedValue($DataSource, $Field.Selector, $ResolvedValue, $ModifierEntry.Argument)
            } else {
                Write-Warning "Modifier not found: {0}." -f $ModifierEntry.Identifier
            }
        }
        return $ResolvedValue
    }

}

# --- Content from 06.request.ps1 ---

class MergerRequest {

    [string]$TemplatePath
    [string]$TemplateContent
    [string]$FieldWrapper
    [string]$DynamicContentField
    [object]$StaticData
    [int]$ProgressGranularity
    [List[object]]$Objects

    MergerRequest(
        [string]$TemplatePath,
        [string]$TemplateContent,
        [string]$FieldWrapper,
        [string]$DynamicContentField,
        [object]$StaticData,
        [int]$ProgressGranularity) {

        $this.TemplatePath = $TemplatePath
        $this.TemplateContent = $TemplateContent
        $this.FieldWrapper = $FieldWrapper
        $this.DynamicContentField = $DynamicContentField
        $this.StaticData = $StaticData
        $this.ProgressGranularity = $ProgressGranularity
        $this.Objects = [List[object]]::new()
    }

    [void]AddObject([object]$Object) {
        if($null -ne $Object) {
            $this.Objects.Add($Object)
        }
    }

}

# --- Content from 07.event.ps1 ---

enum BuildEventType {
    BuildBegin
    MergingObject
    ContentGenerated
    BuildEnd
}

class BuildEvent {

    [MergerRequest]$Request
    [BuildEventType]$EventType
    [object]$Object
    [int]$ObjectCount
    [string]$Content

    hidden [BuildEvent]_set([MergerRequest]$Request, [BuildEventType]$EventType, [object]$Object, [int]$ObjectCount, [string]$Content) {
        $this.Request = $Request
        $this.EventType = $EventType
        $this.Object = $Object
        $this.ObjectCount = $ObjectCount
        $this.Content = $Content
        return $this
    }

    [BuildEvent]BuildBegin([MergerRequest]$Request) {
        return $this._set($Request, [BuildEventType]::BuildBegin, $null, 0, [string]::Empty)
    }

    [BuildEvent]MergingObject([object]$Object) {
        return $this._set($this.Request, [BuildEventType]::MergingObject, $Object, $this.ObjectCount + 1, [string]::Empty)
    }

    [BuildEvent]ContentGenerated([object]$Object, [string]$Content) {
        return $this._set($this.Request, [BuildEventType]::ContentGenerated, $Object, $this.ObjectCount, $Content)
    }

    [BuildEvent]BuildEnd() {
        return $this._set($this.Request, [BuildEventType]::BuildEnd, $null, $this.ObjectCount, [string]::Empty)
    }

}

<# abstract #> class BuildListener {

    <# abstract #> [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        throw [NotImplementedException]::new()
    }

}

# --- Content from 08.buildtype.ps1 ---

enum BuildType {
    Combined
    Separated
}

# --- Content from 09.processor.ps1 ---

<# abstract #> class MergerProcessor : BuildListener {

    [List[object]]$Output

    MergerProcessor() : base() {
        $this.Output = [List[object]]::new()
    }

    <# abstract #> [BuildType]GetRequiredBuildType() {
        throw [NotImplementedException]::new()
    }

}

class EmptyProcessor : MergerProcessor {

    [BuildType]$BuildType

    EmptyProcessor([BuildType]$BuildType) : base() {
        $this.BuildType = $BuildType
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {}

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

class OutStringProcessor : MergerProcessor {

    [BuildType]$BuildType

    OutStringProcessor([BuildType]$BuildType) : base() {
        $this.BuildType = $BuildType
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        if($BuildEvent.EventType -eq [BuildEventType]::ContentGenerated) {
            $this.Output.Add($BuildEvent.Content)
        }
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

class OutFileProcessor : MergerProcessor {

    hidden static [ValueExtractor]$_fileNameExtractor = [PropertyValueExtractor]::new()

    [BuildType]$BuildType
    [string]$FileOrProperty
    [string]$DestDir
    [string]$Extension

    OutFileProcessor([BuildType]$BuildType, [string]$FileOrProperty, [string]$DestDir, [string]$Extension) : base() {
        $this.BuildType = $BuildType
        $this.FileOrProperty = $FileOrProperty
        $this.DestDir = $DestDir
        $this.Extension = $Extension
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        switch ($BuildEvent.EventType) {
            ([BuildEventType]::BuildBegin) { $this._initExtension($BuildEvent) }
            ([BuildEventType]::ContentGenerated) { $this._outFile($BuildEvent) }
        }
    }

    hidden [void]_initExtension([BuildEvent]$BuildEvent) {
        # Priority:
        # 1: Given Extension
        # 2: Given FileName (if Combined)
        # 3: TemplatePath
        [string[]]$Paths = @()
        if($this._isCombined()) {
            $Paths += $this.FileOrProperty
        }
        $Paths += $BuildEvent.Request.TemplatePath
        foreach($Path in $Paths) {
            if([string]::IsNullOrWhiteSpace($this.Extension)) {
                $this.Extension = [Path]::GetExtension($Path)
            }
        }
    }

    hidden [void]_outFile([BuildEvent]$BuildEvent) {
        [string]$FileName = $null
        if($this._isCombined()) {
            $FileName = $this.FileOrProperty
        } else {
            $FileName = [OutFileProcessor]::_fileNameExtractor.ExtractValue($this.FileOrProperty, $BuildEvent.Object).ExtractedValue
            if([string]::IsNullOrWhiteSpace($FileName)) {
                $FileName = $this._generateFileName($BuildEvent)
            }
        }
        $FileName = [Path]::ChangeExtension($FileName, $this.Extension)
        [string]$FilePath = Join-Path $this.DestDir -ChildPath $FileName

        New-Item -Path $this.DestDir -ItemType Directory -Force
        Out-File -FilePath $FilePath -InputObject $BuildEvent.Content -Force
    }

    hidden [string]_generateFileName([BuildEvent]$BuildEvent) {
        [string]$Total = $BuildEvent.Request.Objects.Count.ToString()
        [string]$Index = $BuildEvent.ObjectCount
        while($Index.Length -lt $Total.Length) {
            $Index = '0' + $Index
        }
        return "noname(index-{0})" -f $Index
    }

    hidden [bool]_isCombined() {
        return $this.BuildType -eq [BuildType]::Combined
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

# --- Content from 10.progress.ps1 ---

class BuildProgress : BuildListener {

    BuildProgress() : base() {}

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        if($BuildEvent.EventType -eq [BuildEventType]::BuildEnd) {
            Write-Progress -Activity $BuildEvent.EventType -Completed
            return
        }
        [int]$Total = $BuildEvent.Request.Objects.Count
        if($Total -ne 0) {
            [int]$Count = $BuildEvent.ObjectCount
            [int]$PercentComplete = ($Count / $Total) * 100
            if(($PercentComplete % $BuildEvent.Request.ProgressGranularity) -eq 0) {
                [string]$Status = "{0}/{1}" -f $Count, $Total
                Write-Progress -Activity $BuildEvent.EventType -Status $Status -PercentComplete $PercentComplete
            }
        }
    }

}

# --- Content from 11.builder.ps1 ---

class ContentBuffer {

    [StringBuilder]$Buffer

    ContentBuffer() {
        $this.Buffer = [StringBuilder]::new()
    }

    [string]ToString() {
        return $this.Buffer.ToString()
    }

    [void]Set([string]$Value) {
        $this.Buffer.Clear().Append($Value)
    }

    [void]NewLine() {
        $this.Buffer.AppendLine([string]::Empty)
    }

    [void]Append([string]$Value) {
        $this.Buffer.Append($Value)
    }

    [void]Clear() {
        $this.Buffer.Clear()
    }

    [void]ReplaceField([string]$Field, $Value) {
        if($null -eq $Value) {
            $Value = [string]::Empty
        }
        $this.Buffer.Replace($Field, $Value)
    }

}

<# abstract #> class MergerContent {

    [ContentBuffer]$Tmp
    [ContentBuffer]$Content
    [string]$Template
    [List[Field]]$Fields

    MergerContent() {
        $this.Tmp = [ContentBuffer]::new()
        $this.Content = [ContentBuffer]::new()
        $this.Template = [string]::Empty
        $this.Fields = [List[Field]]::new()
    }

    <# abstract #> [bool]IsDynamic() {
        throw [NotImplementedException]::new()
    }

}

class MasterContent : MergerContent {

    MasterContent() : base() {}

    [bool]IsDynamic() {
        return $false
    }

}

class DynamicContent : MergerContent {

    [Field]$PlaceholderField

    DynamicContent([Field]$PlaceholderField) : base() {
        $this.PlaceholderField = $PlaceholderField
    }

    [bool]IsDynamic() {
        return $true
    }

}

class MergerBuilder {

    [MergerRequest]$Request
    [MergerProcessor]$Processor

    [MasterContent]$MasterContent
    [List[DynamicContent]]$DynamicContents
    [List[BuildListener]]$Listeners
    [BuildEvent]$BuildEvent
    [FieldSyntax]$FieldSyntax
    [FieldFormatter]$FieldFormatter
    [FieldParser]$FieldParser
    [FieldFactory]$FieldFactory
    [FieldResolver]$FieldResolver

    [List[object]]Build([MergerRequest]$Request, [MergerProcessor]$Processor) {
        $this.Request = $Request
        $this.Processor = $Processor

        $this.MasterContent = [MasterContent]::new()
        $this.DynamicContents = [List[DynamicContent]]::new()
        $this.Listeners = [List[BuildListener]]::new()
        $this.Listeners.Add($this.Processor)
        if($this.Request.ProgressGranularity -gt 0) {
            $this.Listeners.Add([BuildProgress]::new())
        }
        $this.BuildEvent = [BuildEvent]::new()
        $this.FieldSyntax = [FieldSyntax]::new($this.Request.FieldWrapper)
        $this.FieldFormatter = [FieldFormatter]::new($this.FieldSyntax)
        $this.FieldParser = [FieldParser]::new($this.FieldSyntax)
        $this.FieldFactory = [FieldFactory]::new($this.FieldFormatter)
        $this.FieldResolver = [FieldResolver]::new()

        $this._buildInternal()
        return $this.Processor.Output
    }

    hidden [void]_buildInternal() {
        [Field]$DynamicContentField = $this.FieldFactory.CreateFromSelector($this.Request.DynamicContentField)

        $this._notifyAll($this.BuildEvent.BuildBegin($this.Request))
        # ========================
        # Extract Dynamic Sections
        # ========================
        [bool]$NewLine = $false # Content begin (Master)
        [MergerContent]$CurrentContent = $this.MasterContent
        foreach($Line in ($this.Request.TemplateContent -split '\r?\n')) {
            if($Line -match $DynamicContentField.RawText) {
                if($CurrentContent.IsDynamic()) {
                    $CurrentContent = $this.MasterContent
                    $NewLine = $true
                } else {
                    [DynamicContent]$NewContent = $this._newDynamicContent()
                    $this.MasterContent.Tmp.NewLine()
                    $this.MasterContent.Tmp.Append($NewContent.PlaceholderField.RawText)
                    $CurrentContent = $NewContent
                    $NewLine = $false # Content begin (Dynamic)
                }
            } else {
                if($NewLine) {
                    $CurrentContent.Tmp.NewLine()
                }
                $NewLine = $true
                $CurrentContent.Tmp.Append($Line)
            }
        }
        if($CurrentContent.IsDynamic()) {
            throw "The dynamic section is not closed (a '{0}' field is missing)." -f $DynamicContentField.RawText
        }
        # ===========
        # Find Fields
        # ===========
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Fields = $this.FieldParser.ParseAll($Dynamic.Tmp)
        }
        $this.MasterContent.Fields = $this.FieldParser.ParseAll($this.MasterContent.Tmp)
        [string[]]$DynamicPlaceholders = $this.DynamicContents.PlaceholderField.RawText
        $this.MasterContent.Fields.RemoveAll({
            param($Element)
            $DynamicPlaceholders -contains $Element.RawText
        })
        # ======================================
        # Resolve static fields in MasterContent
        # ======================================
        foreach($Field in $this.MasterContent.Fields) {
            $this.MasterContent.Tmp.ReplaceField($Field.RawText, $this.FieldResolver.Resolve($Field, $this.Request.StaticData))
        }
        # ==============
        # Init Templates
        # ==============
        $this.MasterContent.Template = $this.MasterContent.Tmp.ToString()
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Template = $Dynamic.Tmp.ToString()
        }
        # =============
        # Merge Objects
        # =============
        [bool]$FirstObject = $true
        foreach($Object in $this.Request.Objects) {

            $this._notifyAll($this.BuildEvent.MergingObject($Object))

            foreach($Dynamic in $this.DynamicContents) {

                $Dynamic.Tmp.Set($Dynamic.Template)

                foreach($Field in $Dynamic.Fields) {
                    $Dynamic.Tmp.ReplaceField($Field.RawText, $this.FieldResolver.Resolve($Field, $Object, $this.Request.StaticData))
                }
                switch ($this.Processor.GetRequiredBuildType()) {
                    ([BuildType]::Separated) {
                        $Dynamic.Content.Set($Dynamic.Tmp.ToString())
                    }
                    ([BuildType]::Combined) {
                        if(-not $FirstObject) {
                            $Dynamic.Content.NewLine()
                        }
                        $Dynamic.Content.Append($Dynamic.Tmp.ToString())
                    }
                }
            }
            $FirstObject = $false

            if ($this.Processor.GetRequiredBuildType() -eq [BuildType]::Separated) {
                $this._generateContentAndNotify($Object)
            }
        }
        if ($this.Processor.GetRequiredBuildType() -eq [BuildType]::Combined) {
            $this._generateContentAndNotify($null)
        }
        #===========================================
        $this._notifyAll($this.BuildEvent.BuildEnd())
    }

    hidden [DynamicContent]_newDynamicContent() {
        [string]$Selector = "Dynamic$($this.DynamicContents.Count)"
        [DynamicContent]$Content = [DynamicContent]::new($this.FieldFactory.CreateFromSelector($Selector))
        $this.DynamicContents.Add($Content)
        return $Content
    }

    hidden [void]_generateContentAndNotify($Object) {
        $this.MasterContent.Content.Set($this.MasterContent.Template)
        foreach($Dynamic in $this.DynamicContents) {
            $this.MasterContent.Content.ReplaceField($Dynamic.PlaceholderField.RawText, $Dynamic.Content.ToString())
        }
        $this._notifyAll($this.BuildEvent.ContentGenerated($Object, $this.MasterContent.Content.ToString()))
    }

    hidden [void]_notifyAll([BuildEvent]$BuildEvent) {
        foreach($Listener in $this.Listeners) {
            $Listener.BuildStateChanged($BuildEvent)
        }
    }

}

# --- Content from Invoke-MergerBuild.ps1 ---

function Invoke-MergerBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [MergerProcessor]$Processor,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [MergerRequest]$Request
    )
    process {
        ([MergerBuilder]::new()).Build($Request, $Processor)
    }
}

# --- Content from New-MergerEmptyProcessor.ps1 ---

function New-MergerEmptyProcessor {
    [CmdletBinding()]
    [OutputType([EmptyProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    [EmptyProcessor]::new($BuildType)
}

# --- Content from New-MergerOutFileProcessor.ps1 ---

function New-MergerOutFileProcessor {
    [CmdletBinding(DefaultParameterSetName='Combined')]
    [OutputType([OutFileProcessor])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Combined')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$FileName,

        [Parameter(Mandatory=$true, ParameterSetName='Separated')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$PropertyName,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DestDir = '.',

        [Parameter(Mandatory=$false)]
        [string]$Extension
    )
    if($PSCmdlet.ParameterSetName -eq 'Combined') {
        [OutFileProcessor]::new([BuildType]::Combined, $FileName, $DestDir, $Extension)
    } else {
        [OutFileProcessor]::new([BuildType]::Separated, $PropertyName, $DestDir, $Extension)
    }
}

# --- Content from New-MergerOutStringProcessor.ps1 ---

function New-MergerOutStringProcessor {
    [CmdletBinding()]
    [OutputType([OutStringProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    [OutStringProcessor]::new($BuildType)
}

# --- Content from New-MergerRequest.ps1 ---

function New-MergerRequest {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [OutputType([MergerRequest])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$TemplatePath,

        [Parameter(Mandatory=$true, ParameterSetName='Content')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$TemplateContent,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$FieldWrapper = '%',

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DynamicContentField = 'Dynamic',

        [Parameter(Mandatory=$false)]
        [object]$StaticData,

        [Parameter(Mandatory=$false)]
        [ValidateRange(0, 100)]
        [int]$ProgressGranularity = 0,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]]$Object
    )
    begin{
        if($PSCmdlet.ParameterSetName -eq 'Path') {
            # Strange behavior with this:
            # $TemplateContent = Get-Content -Path $TemplatePath -Raw -Force

            [StringBuilder]$Sb = [StringBuilder]::new()
            [bool]$FirstLine = $true
            Get-Content -Path $TemplatePath -Force | ForEach-Object {
                if(-not $FirstLine) {
                    $Sb.AppendLine([string]::Empty) > $null
                }
                $FirstLine = $false
                $Sb.Append($_) > $null
            }
            $TemplateContent = $Sb.ToString()
        }
        [MergerRequest]$Request = [MergerRequest]::new(
            $TemplatePath, $TemplateContent, $FieldWrapper, $DynamicContentField, $StaticData, $ProgressGranularity)
    }
    process{
        foreach($Obj in $Object) {
            $Request.AddObject($Obj)
        }
    }
    end{
        $Request
    }
}

# --- Content from PostContent.ps1 ---


