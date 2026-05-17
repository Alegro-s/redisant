$ErrorActionPreference = "Stop"
$Eco = Join-Path (Split-Path $PSScriptRoot -Parent) ""
Set-Location $Eco

if (-not (Test-Path "smtp.env")) {
    Copy-Item "smtp.env.example" "smtp.env"
}

docker compose -f docker-compose.apis.yml --env-file smtp.env up -d --build
Write-Host "waypoint-api http://127.0.0.1:8080"
Write-Host "lynx-api     http://127.0.0.1:8082"
