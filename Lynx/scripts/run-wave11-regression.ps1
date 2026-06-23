# Wave 11 / Block D: platform parity — version gate, web export, QA chain.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Rust engine tests =="
Push-Location engine
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== Flutter wave 11 + wave 4 tests =="
Push-Location client
flutter test test/wave11_platform_test.dart test/wave4_platform_test.dart --reporter compact
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== lynx-core wasm32 (optional smoke) =="
Push-Location lynx-core
cargo build --target wasm32-unknown-unknown --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "  (skip: install wasm32-unknown-unknown for full M6 smoke)"
} else {
  Write-Host "  wasm32-unknown-unknown OK"
}
Pop-Location

Write-Host "== Wave 10 regression chain =="
& "$PSScriptRoot/run-wave10-regression.ps1"
exit $LASTEXITCODE
