# M1: Lynx Core Win32 + D3D12 clear demo (Windows only).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core unit tests =="
Push-Location lynx-core
cargo test --quiet
$t = $LASTEXITCODE
if ($t -ne 0) { Pop-Location; exit $t }

Write-Host "== lynx-m1-demo build =="
cargo build --features pal_win_d3d12 --bin lynx-m1-demo --quiet
$b = $LASTEXITCODE
if ($b -ne 0) { Pop-Location; exit $b }

Write-Host "== lynx-m1-demo --frames 2 =="
.\target\debug\lynx-m1-demo.exe --frames 2
$d = $LASTEXITCODE
Pop-Location
exit $d
