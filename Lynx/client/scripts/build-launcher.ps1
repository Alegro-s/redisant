Param(
  [ValidateSet("windows","android")]
  [string]$Target = "windows"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "[build] flutter pub get"
flutter pub get

if ($Target -eq "windows") {
  Write-Host "[build] flutter build windows --release"
  flutter build windows --release
  Write-Host "[build] output: build/windows/x64/runner/Release"
}
elseif ($Target -eq "android") {
  Write-Host "[build] flutter build apk --release"
  flutter build apk --release
  Write-Host "[build] output: build/app/outputs/flutter-apk/app-release.apk"
}
