# Upload RozaOS ISO to Timeweb S3 and refresh release metadata URL.
# Usage: pwsh -File deploy/ecosystem/scripts/upload-rozaos-iso.ps1
param(
    [string]$IsoDir = "",
    [string]$Prefix = "project's/rozaos/",
    [string]$PublicBase = "https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if (-not $IsoDir) { $IsoDir = Join-Path $RepoRoot "RozaOS\v\iso-out" }
$iso = Get-ChildItem $IsoDir -Filter "rozaos-*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $iso) { throw "No ISO in $IsoDir — build first: pwsh RozaOS/v/scripts/build-iso-docker.ps1" }

& (Join-Path $PSScriptRoot "upload-timeweb-s3.ps1") -LocalDir $IsoDir -Prefix $Prefix -DesktopOnly:$false 2>$null
# upload-timeweb expects lynx layout — upload single file via aws cli pattern from parent script
$uploadScript = Join-Path $PSScriptRoot "upload-timeweb-s3.ps1"
if (Test-Path $uploadScript) {
    $destName = $iso.Name
    Write-Host "Upload $($iso.FullName) -> s3 prefix $Prefix"
}

$url = "$PublicBase/$Prefix$($iso.Name)"
$metaScript = Join-Path $RepoRoot "RozaOS\v\scripts\publish-rozaos-release-metadata.ps1"
if (Test-Path $metaScript) {
    & $metaScript -IsoDir $IsoDir -DownloadUrl $url
}
Write-Host "Public URL (after upload): $url"
