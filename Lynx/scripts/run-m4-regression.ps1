# M4: LynxScript v1 + dual-run + M3 regression.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests (script + scene3d + glb) =="
Push-Location lynx-core
cargo test --quiet
$t1 = $LASTEXITCODE
Pop-Location
if ($t1 -ne 0) { exit $t1 }

Write-Host "== engine tests (lynxscript bridge) =="
Push-Location engine
cargo test --quiet
$t2 = $LASTEXITCODE
Pop-Location
if ($t2 -ne 0) { exit $t2 }

Write-Host "== M3 regression (includes m3-demo) =="
& "$PSScriptRoot/run-m3-regression.ps1"
exit $LASTEXITCODE
