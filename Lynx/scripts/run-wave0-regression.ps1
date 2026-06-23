# Волна 0 — регрессия: Rust-тесты, Flutter-тесты, генерация demo.
$ErrorActionPreference = "Stop"
$lynxRoot = Split-Path -Parent $PSScriptRoot

Write-Host "[wave0] Generate platformer-demo assets..."
python (Join-Path $lynxRoot "scripts\generate_wave0_demo_assets.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[wave0] cargo test (engine)..."
Push-Location (Join-Path $lynxRoot "engine")
cargo test
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "[wave0] flutter test (client)..."
Push-Location (Join-Path $lynxRoot "client")
flutter test test/wave0_platformer_demo_test.dart test/lynx_plugin_manifest_test.dart
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { exit $code }

Write-Host "[wave0] OK. Open demo: $lynxRoot\projects\platformer-demo"
Write-Host "  Editor: flutter run -t lib/main_editor.dart (open project folder)"
