# Волна 1 — плагины: регрессия поверх волны 0.
$ErrorActionPreference = "Stop"
$lynxRoot = Split-Path -Parent $PSScriptRoot

Write-Host "[wave1] Wave 0 regression (base)..."
& (Join-Path $lynxRoot "scripts\run-wave0-regression.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[wave1] Generate 3D demo variant..."
python (Join-Path $lynxRoot "scripts\generate_wave0_demo_assets.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[wave1] flutter test (plugins)..."
Push-Location (Join-Path $lynxRoot "client")
flutter test test/wave1_plugins_test.dart test/lynx_plugin_manifest_test.dart
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { exit $code }

Write-Host "[wave1] OK. Open: $lynxRoot\projects\platformer-demo-3d"
Write-Host "  Menu: Plugins Lynx -> enable lynx.3d"
