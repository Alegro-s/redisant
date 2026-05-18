param(
    [switch]$WithTspu,
    [switch]$NoBrowser,
    [switch]$NpmOnHost,
    [switch]$Build
)

# По умолчанию — только Docker (5 сайтов + API), без лишних npm-окон.
if (-not $NpmOnHost) {
    $dockerArgs = @("-NoBrowser:$NoBrowser")
    if ($Build) { $dockerArgs += "-Build" }
    & (Join-Path $PSScriptRoot "start-local-docker.ps1") @dockerArgs
    return
}

$ErrorActionPreference = "Stop"
$PoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$Eco = Join-Path $PoRoot "deploy\ecosystem"
$ShellExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

function Test-Cmd($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }

function Start-DevWindow {
    param([string]$Dir, [string]$Title, [hashtable]$EnvExtra = @{})
    if (-not (Test-Path (Join-Path $Dir "package.json"))) {
        Write-Host "[local] skip (no package.json): $Dir"
        return
    }
    $envLines = ($EnvExtra.GetEnumerator() | ForEach-Object { "`$env:$($_.Key)='$($_.Value)';" }) -join " "
    Start-Process $ShellExe -ArgumentList @(
        "-NoExit", "-Command",
        "Set-Location '$Dir'; $envLines `$Host.UI.RawUI.WindowTitle='$Title'; " +
        "if (-not (Test-Path node_modules)) { if (Test-Path package-lock.json) { npm ci } else { npm install } }; npm run dev"
    )
}

if (-not (Test-Cmd docker)) { throw "Docker Desktop required" }
if (-not (Test-Cmd npm)) { throw "npm required" }

Set-Location $Eco
$EnvFile = "smtp.env"
if (Test-Path "smtp.env.local") {
    $EnvFile = "smtp.env.local"
    Write-Host "[local] Using smtp.env.local (safe passwords for Docker URL)"
} elseif (-not (Test-Path "smtp.env")) {
    Copy-Item "smtp.env.example" "smtp.env"
    Write-Host "[local] Created smtp.env from example"
}

Write-Host "[local] Docker: auth + apis (env: $EnvFile)..."
docker compose -f docker-compose.auth.yml --env-file $EnvFile up -d --build
Start-Sleep -Seconds 3
for ($i = 1; $i -le 40; $i++) {
    $st = docker inspect --format '{{.State.Health.Status}}' waypoint-db 2>$null
    if ($st -eq "healthy") { break }
    Start-Sleep -Seconds 2
}
docker compose -f docker-compose.apis.yml --env-file $EnvFile up -d --build
if (Test-Path "docker-compose.roza.yml") {
    docker compose -f docker-compose.roza.yml up -d --build 2>$null
}

Start-DevWindow (Join-Path $PoRoot "Waypoint\web") "Waypoint Club+Metric :3000" @{
    VITE_PUBLIC_SITE_MODE = "club"
}
Start-DevWindow (Join-Path $PoRoot "Lynx\hub") "Lynx Hub :5175"
Start-DevWindow (Join-Path $PoRoot "Lynx\cloud") "Lynx Cloud :3001"

if ($WithTspu) {
    $tspu = Join-Path $PoRoot "tsput_profile"
    if (Test-Path (Join-Path $tspu "docker-compose.yml")) {
        Push-Location $tspu
        if (Test-Path "docker-compose.bind-local-api.yml") {
            docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build
        } else {
            docker compose up -d --build
        }
        Pop-Location
    }
}

Write-Host ""
Write-Host "========== Local stack =========="
Write-Host "  Auth API:        http://127.0.0.1:8090/health"
Write-Host "  Waypoint API:    http://127.0.0.1:8080/health"
Write-Host "  Lynx API:        http://127.0.0.1:8082/health"
Write-Host "  Waypoint Club:   http://127.0.0.1:3000/"
Write-Host "  TSPU page:       http://127.0.0.1:3000/tspu"
Write-Host "  Lynx Hub:        http://127.0.0.1:5175/"
Write-Host "  Lynx Cloud:      http://127.0.0.1:3001/"
if ($WithTspu) { Write-Host "  TSPU API:        http://127.0.0.1:8081/health" }
Write-Host "================================"
Write-Host ""

if (-not $NoBrowser) {
    Start-Sleep -Seconds 4
    Start-Process "http://127.0.0.1:3000/"
    Start-Process "http://127.0.0.1:5175/"
}
