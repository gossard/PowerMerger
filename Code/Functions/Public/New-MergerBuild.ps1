function New-MergerBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [MergerProcessor]$Processor,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [MergerRequest]$Request
    )
    process {
        (New-Object MergerBuilder).Build($Request, $Processor)
    }
}