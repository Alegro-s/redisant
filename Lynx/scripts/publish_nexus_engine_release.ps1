
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Target = "release",
  [string]$EngineDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
if ($EngineDir -eq "") { $EngineDir = Join-Path $Root "engine" }

Write-Host "=== NEXUS engine build $Version ($Target) ===" -ForegroundColor Cyan
Push-Location $EngineDir
try {
  cargo build --$Target
} finally {
  Pop-Location
}

$OutName = if ($Target -eq "release") { "release" } else { "debug" }
$Dll = Join-Path $EngineDir "target\$OutName\engine.dll"
$So = Join-Path $EngineDir "target\$OutName\libengine.so"
$Dy = Join-Path $EngineDir "target\$OutName\libengine.dylib"

$Dist = Join-Path $Root "dist\engine_$Version"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

if (Test-Path $Dll) {
  Copy-Item $Dll (Join-Path $Dist "engine.dll") -Force
  Write-Host "Copied engine.dll" -ForegroundColor Green
}
if (Test-Path $So) {
  Copy-Item $So (Join-Path $Dist "libengine.so") -Force
  Write-Host "Copied libengine.so" -ForegroundColor Green
}
if (Test-Path $Dy) {
  Copy-Item $Dy (Join-Path $Dist "libengine.dylib") -Force
  Write-Host "Copied libengine.dylib" -ForegroundColor Green
}

$BuiltAt = Get-Date -Format o
$ManifestSnippet = @"
{
  "releases": [
    {
      "version": "$Version",
      "notes": "Built $BuiltAt",
      "artifacts": {
        "windows": { "url": "https://YOUR_CDN/nexus/engine/$Version/windows.zip", "sha256": "REPLACE_ME" },
        "linux": { "url": "https://YOUR_CDN/nexus/engine/$Version/linux.zip", "sha256": "REPLACE_ME" },
        "macos": { "url": "https://YOUR_CDN/nexus/engine/$Version/macos.zip", "sha256": "REPLACE_ME" }
      }
    }
  ],
  "recommended_version": "$Version"
}
"@

$ManifestSnippet | Set-Content (Join-Path $Dist "manifest_snfragment.json") -Encoding UTF8

Write-Host ""
Write-Host "Done: $Dist" -ForegroundColor Cyan
Write-Host "1) Zip engine.dll (Windows) / libengine.so / libengine.dylib per platform; upload zips to HTTPS."
Write-Host "2) sha256 in manifest = hash of the LIBRARY file after extract (e.g. engine.dll), not the zip. Edit manifest_snfragment.json."
Write-Host "3) Merge fragment into full manifest or set nexus_engine_policy.manifest_url."
Write-Host "4) For .nexus encryption, use server upload pipeline: uploads/engine/$Version.nexus"
