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