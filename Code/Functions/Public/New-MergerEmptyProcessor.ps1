function New-MergerEmptyProcessor {
    [CmdletBinding()]
    [OutputType([EmptyProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    [EmptyProcessor]::new($BuildType)
}