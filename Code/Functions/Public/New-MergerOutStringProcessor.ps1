function New-MergerOutStringProcessor {
    [CmdletBinding()]
    [OutputType([OutStringProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    New-Object OutStringProcessor -ArgumentList $BuildType
}