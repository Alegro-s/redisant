# Заготовка xcframework для iOS (волна 4). Требует Xcode + rust targets.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EngineRoot = Split-Path -Parent $ScriptDir
$OutDir = Join-Path $EngineRoot "target/ios-xcframework"

Write-Host "[ios] Adding Rust targets (if missing)..."
& rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim

Write-Host "[ios] Release build device (aarch64-apple-ios)..."
Set-Location $EngineRoot
& cargo build --release --target aarch64-apple-ios

Write-Host "[ios] Release build simulator (aarch64-apple-ios-sim)..."
& cargo build --release --target aarch64-apple-ios-sim

$DeviceLib = Join-Path $EngineRoot "target/aarch64-apple-ios/release/libengine.a"
$SimLib = Join-Path $EngineRoot "target/aarch64-apple-ios-sim/release/libengine.a"

if (-not (Test-Path $DeviceLib)) {
  Write-Error "Missing $DeviceLib — проверьте toolchain Xcode."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (Get-Command xcodebuild -ErrorAction SilentlyContinue) {
  if (Test-Path $SimLib) {
    Write-Host "[ios] xcodebuild -create-xcframework..."
    & xcodebuild -create-xcframework `
      -library $DeviceLib -headers (Join-Path $EngineRoot "include") `
      -library $SimLib -headers (Join-Path $EngineRoot "include") `
      -output (Join-Path $OutDir "engine.xcframework")
    Write-Host "[ios] OK: $(Join-Path $OutDir 'engine.xcframework')"
  } else {
    Write-Warning "Simulator lib missing; only device .a at $DeviceLib"
  }
} else {
  Write-Warning "xcodebuild not found (Windows?). Артефакты .a в target/*/release/"
  Write-Host "  Device: $DeviceLib"
}

Write-Host "[ios] См. Lynx/docs/PLATFORM_QA.md (чеклист TestFlight)"
