# CI: сборка всех site-mode фронтендов Waypoint/web
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$Web = Join-Path $RepoRoot "Waypoint\web"
Set-Location $Web
npm ci
foreach ($mode in @("club", "metric")) {
    Write-Host "== build $mode =="
    Set-Content -Path ".env.production.local" -Value "VITE_PUBLIC_SITE_MODE=$mode"
    npm run build
}
Write-Host "OK: club, metric, desktop dist builds"
