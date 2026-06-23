# Release APK: данные из Supabase, вход локально (как браузер + локальный API).
# Для сборки через backend API: flutter build apk --release --dart-define=INTEGRATION_BASE_URL=http://...
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

Write-Host "[tspu-po] Release APK → Supabase direct (default)" -ForegroundColor Cyan
Write-Host "  Supabase: https://znltxknyweldbtqkrfih.supabase.co" -ForegroundColor DarkGray
Write-Host "  Login: student@university.ru / password123" -ForegroundColor DarkGray

flutter build apk --release
Write-Host "[tspu-po] APK: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
