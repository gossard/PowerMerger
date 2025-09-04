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