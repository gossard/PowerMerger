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
        [hashtable]$StaticFields,

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
            [boolean]$FirstLine = $true
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
            $TemplatePath, $TemplateContent, $FieldWrapper, $DynamicContentField, $StaticFields, $ProgressGranularity)
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