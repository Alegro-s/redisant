
param(
    [switch]$WithAdminPanel,
    [switch]$WithFlutterClient
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
    Write-Host "[NEXUS] Не найден docker. Установите Docker Desktop и повторите."
    exit 1
}

if (-not $env:JWT_SECRET -or $env:JWT_SECRET.Length -lt 32) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 48
    $rng.GetBytes($bytes)
    $env:JWT_SECRET = [Convert]::ToBase64String($bytes)
    Write-Host "[NEXUS] JWT_SECRET сгенерирован на эту сессию (сохраните в .env для постоянства)."
}

if (-not $env:CORS_ALLOWED_ORIGINS) {
    $env:CORS_ALLOWED_ORIGINS = "http://127.0.0.1:8080,http://127.0.0.1:5173,http://localhost:8080,http://localhost:5173,http://localhost:3000,http://127.0.0.1:3000"
}

if (-not $env:ADMIN_OPEN_REGISTRATION) {
    $env:ADMIN_OPEN_REGISTRATION = "1"
}

Write-Host "[NEXUS] Каталог: $RepoRoot"
Write-Host "[NEXUS] Запуск API + PostgreSQL (Docker)..."
docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[NEXUS] docker compose завершился с кодом $LASTEXITCODE"
    exit $LASTEXITCODE
}

Start-Sleep -Seconds 2
try {
    $h = Invoke-RestMethod -Uri "http://127.0.0.1:8080/health" -TimeoutSec 5
    Write-Host "[NEXUS] Health OK: $h"
} catch {
    Write-Host "[NEXUS] Предупреждение: /health пока не ответил — смотрите логи: docker compose logs -f api"
}

if ($WithAdminPanel) {
    if (-not (Test-Cmd "npm")) {
        Write-Host "[NEXUS] npm не найден — пропуск админки."
    } else {
        $ap = Join-Path $RepoRoot "admin-panel"
        if (-not (Test-Path (Join-Path $ap "package.json"))) {
            Write-Host "[NEXUS] admin-panel не найден."
        } else {
            Write-Host "[NEXUS] Открываю админку в новом окне (npm run dev)..."
            Start-Process $ShellExe -ArgumentList @(
                "-NoExit",
                "-Command",
                "Set-Location '$ap'; if (-not (Test-Path 'node_modules')) { if (Test-Path 'package-lock.json') { npm ci } else { npm install } }; npm run dev"
            )
        }
    }
}

if ($WithFlutterClient) {
    if (-not (Test-Cmd "flutter")) {
        Write-Host "[NEXUS] flutter не найден — пропуск клиента."
    } else {
        $cl = Join-Path $RepoRoot "client"
        Write-Host "[NEXUS] Открываю Flutter в новом окне (flutter pub get + run)..."
        Start-Process $ShellExe -ArgumentList @(
            "-NoExit",
            "-Command",
            "Set-Location '$cl'; flutter pub get; flutter run -d windows"
        )
    }
}

Write-Host ""
Write-Host "========== NEXUS локально =========="
Write-Host "  API:      http://127.0.0.1:8080"
Write-Host "  Health:   http://127.0.0.1:8080/health"
Write-Host "  Логи API: docker compose logs -f api"
Write-Host "  Стоп:     docker compose down"
Write-Host ""
Write-Host "  Flutter:  профиль → URL сервера http://127.0.0.1:8080"
Write-Host "  Админка:  обычно http://localhost:5173 (если запустили -WithAdminPanel)"
Write-Host ""
Write-Host "  VK-бот (отдельно): cd vk-bot; pip install -r requirements.txt; скопировать config.example.env → .env; python bot.py"
Write-Host "===================================="
