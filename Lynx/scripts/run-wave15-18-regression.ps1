# Wave 15–18 — Phase II regression (Stable Tick, Engine shell, Cart, Arcade)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== [E15] cargo build engine =="
Push-Location engine
cargo build --release
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
cargo test input_frame --release 2>$null
Pop-Location

Write-Host "== [E17] Flutter cart + phase II tests =="
Push-Location client
flutter pub get
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
flutter test test/wave15_18_test.dart --reporter compact
$ft = $LASTEXITCODE
Pop-Location
if ($ft -ne 0) { exit $ft }

Write-Host "== [E17] pack lynx-tetris cart =="
$dist = Join-Path $Root "dist\samples"
New-Item -ItemType Directory -Path $dist -Force | Out-Null
Push-Location client
dart run tool/pack_lynx_cart.dart (Join-Path $Root "projects\lynx-tetris") (Join-Path $dist "Lynx-Tetris.lynxcart")
Pop-Location

Write-Host "run-wave15-18-regression: OK"
exit 0
