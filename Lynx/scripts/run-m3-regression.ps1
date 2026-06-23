# M3: forward 3D + lynx.3d JSON + engine link + M2 regression.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests =="
Push-Location lynx-core
cargo test --quiet
$t1 = $LASTEXITCODE
if ($t1 -ne 0) { Pop-Location; exit $t1 }

Write-Host "== lynx-m3-demo --frames 2 =="
cargo build --features pal_win_d3d12 --bin lynx-m3-demo --quiet
$b = $LASTEXITCODE
if ($b -ne 0) { Pop-Location; exit $b }
.\target\debug\lynx-m3-demo.exe --frames 2
$d = $LASTEXITCODE
Pop-Location
if ($d -ne 0) { exit $d }

Write-Host "== engine tests =="
Push-Location engine
cargo test --quiet
$t2 = $LASTEXITCODE
Pop-Location
if ($t2 -ne 0) { exit $t2 }

Write-Host "== M2 regression =="
& "$PSScriptRoot/run-m2-regression.ps1"
exit $LASTEXITCODE
