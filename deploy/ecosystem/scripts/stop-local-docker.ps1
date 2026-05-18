$ErrorActionPreference = "Stop"
$Eco = (Join-Path $PSScriptRoot "..")
Set-Location $Eco
$EnvFile = if (Test-Path "smtp.env.local") { "smtp.env.local" } else { "smtp.env" }
docker compose -f docker-compose.local-sites.yml down
docker compose -f docker-compose.auth.yml -f docker-compose.apis.yml --env-file $EnvFile down
Write-Host "Local Docker stack stopped (server configs untouched)."
