# Upload releases/sites-bundle to Timeweb S3 (for server-apply-sites-from-s3.sh).
Param(
  [string]$BundleDir = "",
  [string]$Bucket = "bc39a46d-ee3d-4707-9e3f-9529afb602da",
  [string]$Endpoint = "https://s3.twcstorage.ru",
  [string]$Prefix = "deploy/sites/latest/",
  [string]$SecretsFile = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if (-not $BundleDir) {
  $BundleDir = Join-Path $RepoRoot "releases\sites-bundle"
}
if (-not (Test-Path (Join-Path $BundleDir "manifest.json"))) {
  throw "Missing bundle. Run: .\deploy\ecosystem\scripts\build-sites-local.ps1"
}

if (-not $SecretsFile) {
  $SecretsFile = Join-Path $RepoRoot "deploy\ecosystem\s3.secrets"
}
if (Test-Path $SecretsFile) {
  Get-Content $SecretsFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
      $k = $Matches[1].Trim()
      $v = $Matches[2].Trim().Trim('"')
      Set-Item -Path "env:$k" -Value $v
    }
  }
}
if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
  throw "Missing S3 keys in $SecretsFile"
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
  throw "aws CLI not found"
}

$env:AWS_DEFAULT_REGION = "ru-1"
if (-not $Prefix.EndsWith("/")) { $Prefix += "/" }
$s3dest = "s3://${Bucket}/${Prefix}"

Write-Host "[s3] sync $BundleDir -> $s3dest"
aws s3 sync $BundleDir $s3dest --endpoint-url $Endpoint --delete

$zipPath = Join-Path (Split-Path $BundleDir -Parent) "sites-bundle.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
# tar -a = zip с прямыми слэшами (Linux unzip не ломается на backslash)
Push-Location $BundleDir
& tar.exe -a -cf $zipPath waypoint-club waypoint-metric lynx-hub roza manifest.json
Pop-Location
if (-not (Test-Path $zipPath)) {
  throw "Failed to create $zipPath (need tar.exe on Windows 10+)"
}
$zipKey = "deploy/sites/sites-bundle.zip"
Write-Host "[s3] upload zip -> s3://${Bucket}/${zipKey}"
aws s3 cp $zipPath "s3://${Bucket}/${zipKey}" --endpoint-url $Endpoint

$base = "$Endpoint/${Bucket}/${Prefix}"
$zipUrl = "$Endpoint/${Bucket}/${zipKey}"
Write-Host ""
Write-Host "Uploaded. S3 prefix:"
Write-Host "  $base"
Write-Host "ZIP (server SITES_MODE=s3):"
Write-Host "  $zipUrl"
Write-Host ""
Write-Host "On VPS:"
Write-Host "  sudo bash deploy/ecosystem/scripts/server-deploy-all-sites.sh"
