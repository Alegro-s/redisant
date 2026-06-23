# Wave 9 / Block B: AnimationPlayer v2, key events, tile collision preview, parity doc.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== engine animation tests =="
Push-Location engine
cargo test animation:: --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== flutter wave9_editor_test =="
Push-Location client
flutter test test/wave9_editor_test.dart --reporter compact
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== wave5 editor (animation codec) =="
Push-Location client
flutter test test/wave5_editor_test.dart --reporter compact
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== M5-M6 regression =="
& "$PSScriptRoot/run-m5-m6-regression.ps1"
exit $LASTEXITCODE
