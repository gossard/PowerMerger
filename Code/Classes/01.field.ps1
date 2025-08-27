class FieldFormat {

    [string]$FieldWrapper
    [string]$Pattern

    FieldFormat([string]$FieldWrapper) {
        $this.FieldWrapper = $FieldWrapper
        $this.Pattern = $this.FormatUnsafe('(.*?)')
    }

    hidden [string]FormatUnsafe([string]$Field) {
        return "{0}{1}{0}" -f $this.FieldWrapper, $Field
    }

    [string]Format([string]$Field) {
        if($Field -match $this.Pattern) {
            return $Field
        }
        return $this.FormatUnsafe($Field)
    }

    [string]Unformat([string]$Field) {
        [System.Text.RegularExpressions.Match]$Match = [regex]::Match($Field, $this.Pattern)
        if($Match.Success) {
            return $Match.Groups[1].Value
        }
        return $Field
    }

}

class FieldResolver {

    [FieldFormat]$FieldFormat

    FieldResolver([FieldFormat]$FieldFormat) {
        $this.FieldFormat = $FieldFormat
    }

    [object]Resolve([object]$Object, [string]$Field) {
        if($null -eq $Object) {
            return $null
        }
        [string]$PropertyPath = $this.FieldFormat.Unformat($Field)

        return [PowerMergerUtils]::GetNestedPropertyValue($Object, $PropertyPath)
    }

}