function New-MergerEmptyProcessor {
    [CmdletBinding()]
    [OutputType([EmptyProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    New-Object EmptyProcessor -ArgumentList $BuildType
}