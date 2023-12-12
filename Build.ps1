function Get-SortedPs1Files([string]$FolderPath) {
    Get-ChildItem $FolderPath -Filter '*.ps1' -File -Recurse | Sort-Object 'Name'
}

[string]$Encoding = "utf8"

[string]$ModuleName = "MyModule"
[string]$ModulePath   = Join-Path $PSScriptRoot -ChildPath "$($ModuleName).psm1"
[string]$ManifestPath = Join-Path $PSScriptRoot -ChildPath "$($ModuleName).psd1"

$Classes          = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Classes")
$PublicFunctions  = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Functions\Public")
$PrivateFunctions = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Functions\Private")
$PreContent       = Get-Item           (Join-Path $PSScriptRoot -ChildPath "Code\PreContent.ps1")
$PostContent      = Get-Item           (Join-Path $PSScriptRoot -ChildPath "Code\PostContent.ps1")

"# Built on $(Get-Date)" | Out-File $ModulePath -Encoding $Encoding

$ModuleFiles = @()
$ModuleFiles += $PreContent
$ModuleFiles += $Classes
$ModuleFiles += $PublicFunctions
$ModuleFiles += $PrivateFunctions
$ModuleFiles += $PostContent

$ModuleFiles | Get-Content | Out-File $ModulePath -Encoding $Encoding -Append

if($null -eq $PublicFunctions) {
    Update-ModuleManifest $ManifestPath -FunctionsToExport '*'
} else {
    Update-ModuleManifest $ManifestPath -FunctionsToExport $PublicFunctions.BaseName
}