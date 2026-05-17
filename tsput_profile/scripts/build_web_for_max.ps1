# Сборка Flutter Web для nginx + MAX (HTTPS URL задаёшь при сборке)
param(
  [string]$IntegrationBaseUrl = "http://127.0.0.1:8080"
)

Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force -Path "build\web" | Out-Null

flutter build web --release --base-href / --dart-define=INTEGRATION_BASE_URL=$IntegrationBaseUrl

Write-Host "Готово: build\web — подключи профиль web в docker compose или залей на хостинг."
