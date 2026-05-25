# Локальная сборка фронтов + бандл для S3 / VPS.
#   .\deploy\ecosystem\scripts\build-sites-local.ps1
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$BundleRoot = Join-Path $Root "releases\sites-bundle"

function Stage-Dir($src, $name) {
  $dest = Join-Path $BundleRoot $name
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Path (Join-Path $src "*") -Destination $dest -Recurse -Force
  Write-Host "  staged -> releases\sites-bundle\$name"
}

if (Test-Path $BundleRoot) { Remove-Item -Recurse -Force $BundleRoot }
New-Item -ItemType Directory -Force -Path $BundleRoot | Out-Null

function Build-WaypointWeb($mode, $favicon, $bundleName) {
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
  Stage-Dir (Join-Path $dir "dist") $bundleName
  Write-Host "OK Waypoint web ($mode)"
}

Write-Host "==> Waypoint Club"
Build-WaypointWeb "club" "/favicon-club.svg" "waypoint-club"

Write-Host "==> Waypoint Metric"
Build-WaypointWeb "metric" "/favicon-metric.svg" "waypoint-metric"

Write-Host "==> Lynx Hub"
$lynxHub = Join-Path $Root "Lynx\hub"
Push-Location $lynxHub
@"
VITE_LYNX_AUTH_URL=/auth
"@ | Set-Content -Encoding utf8 .env.production.local
npm run build
Pop-Location
Stage-Dir (Join-Path $lynxHub "dist") "lynx-hub"
Write-Host "OK Lynx Hub"

Write-Host "==> Roza web (/roza/)"
$rozaWeb = Join-Path $Root "roza\web"
Push-Location $rozaWeb
@"
VITE_BASE=/roza/
VITE_ROZA_API_URL=/roza/api
VITE_AUTH_URL=/auth
"@ | Set-Content -Encoding utf8 .env.production.local
npm run build
Pop-Location
Stage-Dir (Join-Path $rozaWeb "dist") "roza"
Write-Host "OK Roza web"

Write-Host "==> Lynx Cloud (build only; on VPS: npm start :3001)"
$lynxCloud = Join-Path $Root "Lynx\cloud"
Push-Location $lynxCloud
@"
NEXT_PUBLIC_LYNX_AUTH_URL=/auth
NEXT_PUBLIC_LYNX_API_BASE=/lynx
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
NEXT_PUBLIC_LYNX_CABINET_URL=/cabinet
"@ | Set-Content -Encoding utf8 .env.production.local
npm run build
Pop-Location
Write-Host "OK Lynx Cloud (not in S3 bundle; deploy via git on server)"

$manifest = @{
  built_at = (Get-Date).ToUniversalTime().ToString("o")
  git_head = ""
  sites    = @{
    "waypoint-club"   = "/srv/waypointclub/web"
    "waypoint-metric" = "/srv/waypointmetric/dist"
    "lynx-hub"        = "/srv/lynx-hub/dist"
    "roza"            = "/srv/roza/web/roza"
  }
}
try {
  $manifest.git_head = (git -C $Root rev-parse --short HEAD 2>$null)
} catch { }
$manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $BundleRoot "manifest.json") -Encoding utf8

Write-Host ""
Write-Host "Bundle: $BundleRoot"
Write-Host "Next: .\deploy\ecosystem\scripts\upload-sites-s3.ps1"
