# Волна 7: маркетплейс + регрессия 6.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Flutter wave 7 tests =="
Push-Location client
flutter test test/wave7_marketplace_test.dart --reporter compact
$w7 = $LASTEXITCODE
Pop-Location
if ($w7 -ne 0) { exit $w7 }

Write-Host "== Wave 6 regression =="
& "$PSScriptRoot/run-wave6-regression.ps1"
exit $LASTEXITCODE
