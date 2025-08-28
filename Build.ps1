function Get-SortedPs1Files([string]$FolderPath) {
    Get-ChildItem $FolderPath -Filter '*.ps1' -File -Recurse | Sort-Object 'Name'
}

[System.Text.UTF8Encoding]$TargetEncoding = [System.Text.UTF8Encoding]::new($false)

[string]$ModuleName = "PowerMerger"
[string]$ModulePath   = Join-Path $PSScriptRoot -ChildPath "$($ModuleName).psm1"
[string]$ManifestPath = Join-Path $PSScriptRoot -ChildPath "$($ModuleName).psd1"

$Classes          = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Classes")
$PublicFunctions  = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Functions\Public")
$PrivateFunctions = Get-SortedPs1Files (Join-Path $PSScriptRoot -ChildPath "Code\Functions\Private")
$PreContent       = Get-Item           (Join-Path $PSScriptRoot -ChildPath "Code\PreContent.ps1")
$PostContent      = Get-Item           (Join-Path $PSScriptRoot -ChildPath "Code\PostContent.ps1")

$SourceFiles = @()
$SourceFiles += $PreContent
$SourceFiles += $Classes
$SourceFiles += $PublicFunctions
$SourceFiles += $PrivateFunctions
$SourceFiles += $PostContent

[System.Text.StringBuilder]$ModuleContent = [System.Text.StringBuilder]::new()

[void]$ModuleContent.AppendLine("# Built on $(Get-Date)")

foreach($File in $SourceFiles) {
    [void]$ModuleContent.AppendLine([string]::Empty)
    [void]$ModuleContent.AppendLine("# --- Content from $($File.Name) ---")
    [void]$ModuleContent.AppendLine([string]::Empty)
    [void]$ModuleContent.AppendLine([System.IO.File]::ReadAllText($File.FullName))
}

[System.IO.File]::WriteAllText($ModulePath, $ModuleContent.ToString(), $TargetEncoding)

if($null -eq $PublicFunctions) {
    Update-ModuleManifest $ManifestPath -FunctionsToExport '*'
} else {
    Update-ModuleManifest $ManifestPath -FunctionsToExport $PublicFunctions.BaseName
}