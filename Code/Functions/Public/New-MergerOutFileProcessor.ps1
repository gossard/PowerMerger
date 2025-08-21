function New-MergerOutFileProcessor {
    [CmdletBinding(DefaultParameterSetName='Combined')]
    [OutputType([OutFileProcessor])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Combined')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$FileName,

        [Parameter(Mandatory=$true, ParameterSetName='Separated')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$PropertyName,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DestDir = '.',

        [Parameter(Mandatory=$false)]
        [string]$Extension
    )
    if($PSCmdlet.ParameterSetName -eq 'Combined') {
        New-Object OutFileProcessor -ArgumentList ([BuildType]::Combined), $FileName, $DestDir, $Extension
    } else {
        New-Object OutFileProcessor -ArgumentList ([BuildType]::Separated), $PropertyName, $DestDir, $Extension
    }
}