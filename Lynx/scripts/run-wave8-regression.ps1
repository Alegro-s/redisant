# Волна 8: Cloud marketplace API + lynx-core stub + регрессия 7.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests =="
Push-Location lynx-core
cargo test --quiet
$core = $LASTEXITCODE
Pop-Location
if ($core -ne 0) { exit $core }

Write-Host "== lynx-server build =="
Push-Location server
cargo build --quiet
$srv = $LASTEXITCODE
Pop-Location
if ($srv -ne 0) { exit $srv }

Write-Host "== Flutter wave 8 tests =="
Push-Location client
flutter test test/wave8_cloud_test.dart test/wave7_marketplace_test.dart --reporter compact
$w8 = $LASTEXITCODE
Pop-Location
if ($w8 -ne 0) { exit $w8 }

Write-Host "== Wave 7 regression =="
& "$PSScriptRoot/run-wave7-regression.ps1"
exit $LASTEXITCODE
