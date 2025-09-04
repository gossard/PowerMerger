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