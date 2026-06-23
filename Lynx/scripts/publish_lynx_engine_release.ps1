
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [string]$Target = "release",
  [string]$EngineDir = "",
  [string]$Platform = "windows",
  [string]$LynxCoreVersion = "0.6.0-m6"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
if ($EngineDir -eq "") { $EngineDir = Join-Path $Root "engine" }

Write-Host "=== Lynx Engine $Version ($Platform) -> .lynxengine ===" -ForegroundColor Cyan
Push-Location $EngineDir
try {
  cargo build --$Target --no-default-features
} finally {
  Pop-Location
}

Write-Host "Compiling HLSL shaders..."
& (Join-Path $Root 'lynx-core\scripts\compile-shaders.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Tip: full shell pack -> scripts\build-lynx-engine-full-pack.ps1 -Version $Version"

$Dist = Join-Path $Root "dist\lynx_engine_$Version"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

$OutPack = Join-Path $Dist "$Platform.lynxengine"
$PackScript = Join-Path $PSScriptRoot "pack_lynx_engine.py"

python $PackScript `
  --version $Version `
  --platform $Platform `
  --engine-dir $EngineDir `
  --lynx-core-version $LynxCoreVersion `
  -o $OutPack

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$BuiltAt = Get-Date -Format o
$ManifestSnippet = @"
{
  "releases": [
    {
      "version": "$Version",
      "notes": "Lynx Engine built $BuiltAt",
      "artifacts": {
        "windows": {
          "url": "https://YOUR_CDN/lynx/engine/$Version/windows.lynxengine",
          "sha256": "REPLACE_AFTER_UPLOAD"
        }
      }
    }
  ],
  "recommended_version": "$Version"
}
"@

$ManifestSnippet | Set-Content (Join-Path $Dist "manifest_snfragment.json") -Encoding UTF8

Write-Host ""
Write-Host "Done:" -ForegroundColor Green
Write-Host "  Pack:     $OutPack"
Write-Host "  Manifest: $(Join-Path $Dist 'manifest_snfragment.json')"
Write-Host "Upload .lynxengine to CDN; merge manifest into /engine/manifest API."
