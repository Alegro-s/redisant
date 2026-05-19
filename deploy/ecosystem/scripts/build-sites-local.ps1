# Локальная сборка фронтов как на VPS (server-02). Запуск из корня репо:
#   .\deploy\ecosystem\scripts\build-sites-local.ps1
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

function Build-WaypointWeb($mode, $favicon) {
  $dir = Join-Path $Root "Waypoint\web"
  Push-Location $dir
  @"
VITE_API_URL=/api
VITE_AUTH_URL=/auth
VITE_PUBLIC_SITE_MODE=$mode
VITE_FAVICON=$favicon
"@ | Set-Content -Encoding utf8 .env.production.local
  npm run build
  Pop-Location
  Write-Host "OK Waypoint web ($mode) -> $dir\dist"
}

Write-Host "==> Waypoint Club"
Build-WaypointWeb "club" "/favicon-club.svg"

Write-Host "==> Waypoint Metric"
Build-WaypointWeb "metric" "/favicon-metric.svg"

Write-Host "==> Lynx Cloud"
Push-Location (Join-Path $Root "Lynx\cloud")
@"
NEXT_PUBLIC_LYNX_AUTH_URL=/auth
NEXT_PUBLIC_LYNX_API_BASE=/lynx
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
NEXT_PUBLIC_LYNX_CABINET_URL=/cabinet
"@ | Set-Content -Encoding utf8 .env.production.local
npm run build
Pop-Location
Write-Host "OK Lynx Cloud"

Write-Host ""
Write-Host "Готово. На VPS: sudo bash deploy/ecosystem/scripts/server-update-site.sh"
