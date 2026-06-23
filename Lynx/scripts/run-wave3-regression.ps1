# Волна 3: export + player + регрессия 0–2.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Generate demos =="
python scripts/generate_wave0_demo_assets.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Flutter wave 3 tests =="
Push-Location client
flutter test test/wave3_export_test.dart --reporter compact
$w3 = $LASTEXITCODE
Pop-Location
if ($w3 -ne 0) { exit $w3 }

Write-Host "== Export CLI smoke =="
& "$PSScriptRoot/export-player.ps1" -Project projects/platformer-wave2 -Preset data
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Wave 0-2 regression =="
& "$PSScriptRoot/run-wave2-regression.ps1"
exit $LASTEXITCODE
