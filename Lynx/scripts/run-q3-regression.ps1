# Q3: Windows Core 3D viewport (FFI + export preset).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== engine + lynx-core (viewport FFI) =="
Push-Location engine
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== Flutter platform tests (windows3dRuntime) =="
Push-Location client
flutter test test/wave11_platform_test.dart --reporter compact
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== M13 regression chain =="
& "$PSScriptRoot/run-m13-regression.ps1"
exit $LASTEXITCODE
