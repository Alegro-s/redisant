# Wave 10 / Block C: BT debug FFI, UI layout v2, regression.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== engine behavior_tree tests =="
Push-Location engine
cargo test behavior_tree:: --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== flutter wave10 + wave9 =="
Push-Location client
flutter test test/wave10_editor_test.dart test/wave9_editor_test.dart --reporter compact
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== wave9 regression =="
& "$PSScriptRoot/run-wave9-regression.ps1"
exit $LASTEXITCODE
