# Phase IV (E24–E27) regression.
param(
    [switch]$SkipFlutter,
    [switch]$SkipWasm,
    [switch]$SkipEngine
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Client = Join-Path $Root 'client'
$Engine = Join-Path $Root 'engine'
$Core = Join-Path $Root 'lynx-core'

Write-Host '=== Phase IV regression (E24–E27) ===' -ForegroundColor Cyan

if (-not $SkipEngine) {
    Write-Host '[E24a] engine LynxScript-only (no legacy_lua)...'
    Push-Location $Engine
    cargo test --release --no-default-features
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Pop-Location

    Write-Host '[E24a] legacy_lua optional build...'
    Push-Location $Engine
    cargo build --release --features legacy_lua
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Pop-Location
}

Write-Host '[E27] lynx-core physics2d + audio tests...'
Push-Location $Core
cargo test physics2d
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
cargo test audio_mixer
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

if (-not $SkipWasm) {
    Write-Host '[E25a] WASM build...'
    & (Join-Path $PSScriptRoot 'build-wasm.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $SkipFlutter) {
    Push-Location $Client
    flutter test test/wave24_27_test.dart test/wave19_23_test.dart test/wave15_18_test.dart
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Pop-Location
}

Write-Host ''
Write-Host 'Phase IV regression OK' -ForegroundColor Green
