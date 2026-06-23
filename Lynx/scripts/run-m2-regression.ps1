# M2: 2D batch + D3D12 demo + engine/lynx-core tests.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests =="
Push-Location lynx-core
cargo test --quiet
$t1 = $LASTEXITCODE
if ($t1 -ne 0) { Pop-Location; exit $t1 }

Write-Host "== lynx-m2-demo =="
cargo build --features pal_win_d3d12 --bin lynx-m2-demo --quiet
$b = $LASTEXITCODE
if ($b -ne 0) { Pop-Location; exit $b }
.\target\debug\lynx-m2-demo.exe --frames 2
$d = $LASTEXITCODE
Pop-Location
if ($d -ne 0) { exit $d }

Write-Host "== engine tests (batch_sync + lynx-core link) =="
Push-Location engine
cargo test --quiet
$t2 = $LASTEXITCODE
Pop-Location
if ($t2 -ne 0) { exit $t2 }

Write-Host "== M1 regression =="
& "$PSScriptRoot/run-m1-regression.ps1"
exit $LASTEXITCODE
