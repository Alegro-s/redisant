# Запуск локального API + Postgres (стенд до боевого сервера вуза).
# Запускать из корня репозитория:  .\scripts\start-local-api.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host 'Starting Docker stack (api on host :8080, db internal)...' -ForegroundColor Cyan
docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build

Write-Host ''
Write-Host 'Health: http://127.0.0.1:8080/health' -ForegroundColor Green
Write-Host 'Demo login (see docker-compose API_DEMO_*): student@university.ru / password123' -ForegroundColor Green
Write-Host 'Flutter on a physical phone: flutter run --dart-define=INTEGRATION_BASE_URL=http://<PC_LAN_IP>:8080' -ForegroundColor Yellow
