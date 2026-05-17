param(
    [switch]$WithFrontends
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Test-Cmd {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

$ShellExe = if (Test-Cmd "pwsh") { "pwsh" } else { "powershell" }

if (-not (Test-Cmd "docker")) {
    Write-Host "[lynx-local] Установите Docker Desktop."
    exit 1
}

if (-not $env:JWT_SECRET -or $env:JWT_SECRET.Length -lt 32) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 48
    $rng.GetBytes($bytes)
    $env:JWT_SECRET = [Convert]::ToBase64String($bytes)
    Write-Host "[lynx-local] JWT_SECRET сгенерирован на эту сессию."
}

if (-not $env:CORS_ALLOWED_ORIGINS) {
    $env:CORS_ALLOWED_ORIGINS = "http://127.0.0.1:8080,http://localhost:8080,http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:3001,http://localhost:3001,http://127.0.0.1:5175,http://localhost:5175"
}

if (-not $env:ADMIN_OPEN_REGISTRATION) {
    $env:ADMIN_OPEN_REGISTRATION = "1"
}

Write-Host "[lynx-local] Каталог: $RepoRoot"
Write-Host "[lynx-local] docker compose up -d --build..."
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Start-Sleep -Seconds 2
try {
    Invoke-RestMethod -Uri "http://127.0.0.1:8080/health" -TimeoutSec 5 | Out-Null
    Write-Host "[lynx-local] API /health OK"
} catch {
    Write-Host "[lynx-local] /health пока не ответил — docker compose logs -f api"
}

function Start-DevWindow {
    param(
        [string]$ProjectDir,
        [string]$Title
    )
    if (-not (Test-Path (Join-Path $ProjectDir "package.json"))) {
        Write-Host "[lynx-local] Пропуск: нет package.json в $ProjectDir"
        return
    }
    Write-Host "[lynx-local] Новое окно: $Title"
    Start-Process $ShellExe -ArgumentList @(
        "-NoExit",
        "-Command",
        "Set-Location '$ProjectDir'; `$Host.UI.RawUI.WindowTitle = '$Title'; if (-not (Test-Path 'node_modules')) { if (Test-Path 'package-lock.json') { npm ci } else { npm install } }; npm run dev"
    )
}

if (-not $WithFrontends) {
    Write-Host ""
    Write-Host "========== Lynx локально (только API в Docker) =========="
    Write-Host "  API:      http://127.0.0.1:8080"
    Write-Host "  Стоп:     docker compose down"
    Write-Host ""
    Write-Host "  Фронты:   .\scripts\lynx-local.ps1 -WithFrontends"
    Write-Host "  Или вручную: admin-panel, nexus-cloud, nexus-hab — npm run dev"
    Write-Host "========================================================="
    exit 0
}

if (-not (Test-Cmd "npm")) {
    Write-Host "[lynx-local] Для -WithFrontends нужен npm."
    exit 1
}

Start-DevWindow (Join-Path $RepoRoot "admin-panel") "Lynx — WaypointMetric :5173"
Start-DevWindow (Join-Path $RepoRoot "nexus-cloud") "Lynx — Cloud Next :3001"
Start-DevWindow (Join-Path $RepoRoot "nexus-hab") "Lynx — Hub Vite :5175"

Write-Host ""
Write-Host "========== Lynx локально (API + фронты в отдельных окнах) =========="
Write-Host "  API:             http://127.0.0.1:8080"
Write-Host "  WaypointMetric:  http://127.0.0.1:5173"
Write-Host "  Lynx Cloud:      http://127.0.0.1:3001"
Write-Host "  Lynx Hub:        http://127.0.0.1:5175"
Write-Host "======================================================================"
