param(
    [switch]$Build,
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$Eco = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PoRoot = (Resolve-Path (Join-Path $Eco "..\..")).Path
$EnvFile = if (Test-Path (Join-Path $Eco "smtp.env.local")) {
    "smtp.env.local"
} elseif (Test-Path (Join-Path $Eco "smtp.env")) {
    "smtp.env"
} else {
    Copy-Item (Join-Path $Eco "smtp.env.example") (Join-Path $Eco "smtp.env.local")
    "smtp.env.local"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop required"
}

Set-Location $Eco
Write-Host "[local-docker] env: $EnvFile"

docker network inspect waypoint_net 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    docker network create waypoint_net | Out-Null
}

function Test-ContainerUp([string]$Name) {
    return [bool](docker ps -q -f "name=^${Name}$")
}

Write-Host "[local-docker] APIs auth + waypoint + lynx"
if (-not (Test-ContainerUp "waypoint-db")) {
    $authArgs = @("-f", "docker-compose.auth.yml", "--env-file", $EnvFile, "up", "-d")
    if ($Build) { $authArgs += "--build" }
    docker compose @authArgs
} else {
    Write-Host "[local-docker] waypoint-db already up"
}

$apiRecreate = $false
if ((docker ps -aq -f "name=waypoint-apis-waypoint-api-1") -or -not (Test-ContainerUp "waypoint-waypoint-api")) {
    $apiRecreate = $true
}
$apiArgs = @("-f", "docker-compose.apis.yml", "--env-file", $EnvFile, "up", "-d")
if ($Build) { $apiArgs += "--build" }
if ($apiRecreate) { $apiArgs += "--force-recreate" }
docker compose @apiArgs

Write-Host "[local-docker] Roza API"
$rozaArgs = @("-f", "docker-compose.roza.yml", "up", "-d")
if ($Build) { $rozaArgs += "--build" }
docker compose @rozaArgs

Write-Host "[local-docker] All frontends"
if ($Build) {
    docker compose -f docker-compose.local-sites.yml build
}
docker compose -f docker-compose.local-sites.yml up -d

Write-Host "[local-docker] TSPU API"
$tspu = Join-Path $PoRoot "tsput_profile"
if (Test-Path (Join-Path $tspu "docker-compose.yml")) {
    Push-Location $tspu
    $tspuArgs = @("-f", "docker-compose.yml", "up", "-d")
    if (Test-Path "docker-compose.bind-local-api.yml") {
        $tspuArgs = @("-f", "docker-compose.yml", "-f", "docker-compose.bind-local-api.yml", "up", "-d")
    }
    if ($Build) { $tspuArgs += "--build" }
    docker compose @tspuArgs
    Pop-Location
} else {
    Write-Host "[local-docker] WARN tsput_profile not found"
}

Write-Host ""
Write-Host "========== All local sites =========="
Write-Host "  Waypoint Club:     http://127.0.0.1:3000/"
Write-Host "  Waypoint Metric:   http://127.0.0.1:3002/"
Write-Host "  Waypoint Desktop:  http://127.0.0.1:3002/desktop"
Write-Host "  Lynx Hub:          http://127.0.0.1:5175/"
Write-Host "  Lynx Cloud:        http://127.0.0.1:3001/"
Write-Host "  Roza via Club:     http://127.0.0.1:3000/roza/"
Write-Host "  Roza direct:       http://127.0.0.1:5180/roza/"
Write-Host "  TSPU page:         http://127.0.0.1:3000/tspu"
Write-Host "  Auth API:          http://127.0.0.1:8090/health"
Write-Host "  Waypoint API:      http://127.0.0.1:8080/health"
Write-Host "  Lynx API:          http://127.0.0.1:8082/health"
Write-Host "  Roza API:          http://127.0.0.1:8765/api/health"
Write-Host "  TSPU API:          http://127.0.0.1:8081/health"
Write-Host "===================================="
Write-Host ""

if (-not $NoBrowser) {
    Start-Sleep -Seconds 2
    @(
        "http://127.0.0.1:3000/",
        "http://127.0.0.1:3002/",
        "http://127.0.0.1:3003/",
        "http://127.0.0.1:5175/",
        "http://127.0.0.1:3001/",
        "http://127.0.0.1:3000/roza/",
        "http://127.0.0.1:3000/tspu"
    ) | ForEach-Object { Start-Process $_ }
}
