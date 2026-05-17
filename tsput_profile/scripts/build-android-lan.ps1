# Сборка APK для телефона в той же Wi‑Fi сети, что и ПК с Docker API.
# Укажи IPv4 из ipconfig (адаптер «Беспроводная сеть»), затем:
#   .\scripts\build-android-lan.ps1
# Или:
#   .\scripts\build-android-lan.ps1 -LanIp 192.168.0.112

param(
    [string] $LanIp = '192.168.0.112'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$url = "http://${LanIp}:8080".TrimEnd('/')
Write-Host "INTEGRATION_BASE_URL = $url" -ForegroundColor Cyan

flutter pub get
flutter build apk --release --dart-define=INTEGRATION_BASE_URL=$url

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
    Write-Host "`nAPK: $apk" -ForegroundColor Green
    Write-Host 'Установи на телефон (USB/adb install или скопируй файл). Docker должен слушать :8080.' -ForegroundColor Green
}
