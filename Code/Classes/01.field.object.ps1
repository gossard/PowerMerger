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