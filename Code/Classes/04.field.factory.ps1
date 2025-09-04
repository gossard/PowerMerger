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