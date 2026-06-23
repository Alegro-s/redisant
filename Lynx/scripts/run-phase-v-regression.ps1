# Phase V regression — waves 28–32 + TIC API layer
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $root 'Lynx\client\pubspec.yaml'))) {
    $root = Split-Path $PSScriptRoot -Parent
}
$client = Join-Path $root 'Lynx\client'
Push-Location $client
try {
    Write-Host '== wave28_32_test.dart ==' -ForegroundColor Cyan
    flutter test test/wave28_32_test.dart
    Write-Host '== wave19_23_test.dart (phase III) ==' -ForegroundColor Cyan
    flutter test test/wave19_23_test.dart
    Write-Host '== engine tic_api (cargo) ==' -ForegroundColor Cyan
    Push-Location (Join-Path $root 'Lynx\engine')
    cargo test tic_api --features legacy_lua 2>&1
    Pop-Location
    Write-Host 'Phase V regression OK' -ForegroundColor Green
} finally {
    Pop-Location
}
