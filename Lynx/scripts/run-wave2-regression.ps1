# Волна 2: runtime (сцены, input map, autoload) + регрессия 0–1.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Generate demos (wave 0/1/2) =="
python scripts/generate_wave0_demo_assets.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Rust engine tests =="
Push-Location engine
cargo test --quiet
$rust = $LASTEXITCODE
Pop-Location
if ($rust -ne 0) { exit $rust }

Write-Host "== Flutter wave 2 tests =="
Push-Location client
flutter test test/wave2_runtime_test.dart --reporter compact
$w2 = $LASTEXITCODE
Pop-Location
if ($w2 -ne 0) { exit $w2 }

Write-Host "== Wave 0+1 regression =="
& "$PSScriptRoot/run-wave1-regression.ps1"
exit $LASTEXITCODE
