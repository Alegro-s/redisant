# Волна 4: web parity + version gate + регрессия 0-3.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Generate demos =="
python scripts/generate_wave0_demo_assets.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Rust engine tests =="
Push-Location engine
cargo test --quiet
$rust = $LASTEXITCODE
Pop-Location
if ($rust -ne 0) { exit $rust }

Write-Host "== Flutter wave 4 tests =="
Push-Location client
flutter test test/wave4_platform_test.dart --reporter compact
$w4 = $LASTEXITCODE
Pop-Location
if ($w4 -ne 0) { exit $w4 }

Write-Host "== Wave 0-3 regression =="
& "$PSScriptRoot/run-wave3-regression.ps1"
exit $LASTEXITCODE
