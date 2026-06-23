# Волна 6: плагин 3D v1 + регрессия 0-5.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Generate demos =="
python scripts/generate_wave0_demo_assets.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Flutter wave 6 tests =="
Push-Location client
flutter test test/wave6_3d_test.dart --reporter compact
$w6 = $LASTEXITCODE
Pop-Location
if ($w6 -ne 0) { exit $w6 }

Write-Host "== Wave 0-5 regression =="
& "$PSScriptRoot/run-wave5-regression.ps1"
exit $LASTEXITCODE
