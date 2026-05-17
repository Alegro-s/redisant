
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $root "client")

Write-Host "flutter pub get..."
flutter pub get

Write-Host "Building Windows release..."
flutter build windows --release

Write-Host "Building Web release..."
flutter build web --release

Write-Host "Done. Outputs:"
Write-Host "  Windows: client\build\windows\x64\runner\Release\"
Write-Host "  Web:     client\build\web\"
