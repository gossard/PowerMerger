class MergerRequest {

    [string]$TemplatePath
    [string]$TemplateContent
    [FieldFormat]$FieldFormat
    [string]$DynamicContentField
    [hashtable]$StaticFields
    [int]$ProgressGranularity
    [System.Collections.Generic.List[object]]$Objects

    MergerRequest(
        [string]$TemplatePath,
        [string]$TemplateContent,
        [string]$FieldWrapper,
        [string]$DynamicContentField,
        [hashtable]$StaticFields,
        [int]$ProgressGranularity) {

        $this.TemplatePath = $TemplatePath
        $this.TemplateContent = $TemplateContent
        $this.FieldFormat = New-Object FieldFormat -ArgumentList $FieldWrapper
        $this.DynamicContentField = $this.FieldFormat.Format($DynamicContentField)
        $this.StaticFields = @{}
        foreach($Key in $StaticFields.Keys) {
            $this.StaticFields[$this.FieldFormat.Format($Key)] = $StaticFields[$Key]
        }
        $this.ProgressGranularity = $ProgressGranularity
        $this.Objects = New-Object System.Collections.Generic.List[object]
    }

    [void]AddObject($Object) {
        if($null -ne $Object) {
            $this.Objects.Add($Object)
        }
    }

}