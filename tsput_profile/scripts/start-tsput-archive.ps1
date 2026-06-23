# ТГПУ профиль — версия из архива RAR
# Web: http://127.0.0.1:8092  |  API: http://127.0.0.1:8083
param(
  [string]$ArchiveRoot = "D:\PO\_tsput_from_rar\tsput_profile-master",
  [int]$ApiPort = 8083,
  [int]$WebPort = 8092,
  [switch]$SkipApi,
  [switch]$SkipWeb
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ArchiveRoot)) {
  Write-Error "Archive not found: $ArchiveRoot. Extract RAR to D:\PO\_tsput_from_rar\tsput_profile-master"
}
$Backend = Join-Path $ArchiveRoot "backend"
$localUsers = Join-Path $Backend "local_users.json"
if (-not (Test-Path $localUsers)) {
  @'
[
  {
    "password": "TestTspu2026!",
    "identifiers": ["99999", "test@tspu.local", "Тестовый Студент"],
    "user": { "id": "99999", "name": "Тестовый Студент", "group": "TEST-001" }
  }
]
'@ | Set-Content -Path $localUsers -Encoding UTF8
}

function Stop-Port($port) {
  Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object { if ($_ -gt 0) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }
}

if (-not $SkipApi) {
  Write-Host "[tspu-archive] API on http://127.0.0.1:$ApiPort ..."
  Stop-Port $ApiPort
  pip install -q -r (Join-Path $Backend "requirements.txt") 2>$null
  $apiLog = Join-Path $env:TEMP "tsput-archive-api-$ApiPort.log"
  Start-Process -FilePath "python" -WorkingDirectory $Backend -WindowStyle Hidden -ArgumentList @(
    "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "$ApiPort"
  ) -RedirectStandardOutput $apiLog -RedirectStandardError $apiLog
  Start-Sleep -Seconds 3
  try {
    $h = Invoke-RestMethod "http://127.0.0.1:$ApiPort/health" -TimeoutSec 5
    Write-Host "[tspu-archive] API OK: $($h | ConvertTo-Json -Compress)"
  } catch {
    Write-Warning "[tspu-archive] API not ready. Log: $apiLog"
  }
}

if (-not $SkipWeb) {
  Stop-Port $WebPort
  Set-Location $ArchiveRoot
  $baseUrl = "http://127.0.0.1:$ApiPort"
  $webBuild = Join-Path $ArchiveRoot "build\web"
  Write-Host "[tspu-archive] build web --release ..."
  flutter build web --release --dart-define=INTEGRATION_BASE_URL=$baseUrl
  Write-Host "[tspu-archive] http://127.0.0.1:$WebPort"
  Set-Location $webBuild
  python -m http.server $WebPort --bind 127.0.0.1
}
