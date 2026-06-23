# M5–M6: LynxScript v2, SceneRuntime, legacy_lua off build, wasm32, M4 regression.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests =="
Push-Location lynx-core
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

Write-Host "== engine tests (legacy_lua) =="
Pop-Location
Push-Location engine
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

Write-Host "== engine build --no-default-features (no mlua) =="
cargo build --no-default-features --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== wasm32 lynx-core =="
Push-Location lynx-core
rustup target add wasm32-unknown-unknown 2>$null
cargo build --target wasm32-unknown-unknown --quiet
$w = $LASTEXITCODE
Pop-Location
if ($w -ne 0) { exit $w }

Write-Host "== M4 regression =="
& "$PSScriptRoot/run-m4-regression.ps1"
exit $LASTEXITCODE
