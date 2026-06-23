# ТГПУ профиль — локальный стенд (release Web)
# App: http://127.0.0.1:8091  |  API: http://127.0.0.1:8080  |  Admin: http://127.0.0.1:8093
param(
  [int]$ApiPort = 8080,
  [int]$WebPort = 8091,
  [int]$AdminPort = 8093,
  [switch]$SkipApi,
  [switch]$SkipWeb,
  [switch]$SkipAdmin
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Backend = Join-Path $Root "backend"
$WebBuild = Join-Path $Root "build\web"
$BaseUrl = "http://127.0.0.1:$ApiPort"

function Stop-Port($port) {
  Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object { if ($_ -gt 0) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }
}

if (-not $SkipApi) {
  Write-Host "[tspu-po] API $BaseUrl ..."
  Stop-Port $ApiPort
  Start-Sleep -Seconds 1
  $apiLog = Join-Path $env:TEMP "tsput-po-api-$ApiPort.log"
  Start-Process -FilePath "python" -WorkingDirectory $Backend -WindowStyle Hidden -ArgumentList @(
    "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "$ApiPort"
  ) -RedirectStandardOutput $apiLog -RedirectStandardError $apiLog
  Start-Sleep -Seconds 3
  try {
    $h = Invoke-RestMethod "$BaseUrl/health" -TimeoutSec 8
    Write-Host "[tspu-po] API OK"
  } catch {
    Write-Warning "[tspu-po] API not ready. Log: $apiLog"
  }
}

if (-not $SkipWeb) {
  Set-Location $Root
  Stop-Port $WebPort
  Start-Sleep -Seconds 1
  Write-Host "[tspu-po] build web release..."
  flutter build web --release --dart-define=INTEGRATION_BASE_URL=$BaseUrl
  Write-Host "[tspu-po] App http://127.0.0.1:$WebPort"
  Start-Process python -WindowStyle Hidden -ArgumentList "-m","http.server","$WebPort","--bind","127.0.0.1" -WorkingDirectory (Join-Path $Root "build\web")
}

if (-not $SkipAdmin) {
  Stop-Port $AdminPort
  $adminDir = Join-Path $Root "admin-web"
  Write-Host "[tspu-po] Admin http://127.0.0.1:$AdminPort"
  Start-Process python -WindowStyle Hidden -ArgumentList "-m","http.server","$AdminPort","--bind","127.0.0.1" -WorkingDirectory $adminDir
}
