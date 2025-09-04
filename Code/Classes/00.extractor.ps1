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