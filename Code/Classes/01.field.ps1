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
        return $Field.Replace($this.FieldWrapper, [string]::Empty)
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