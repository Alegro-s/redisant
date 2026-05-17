$ErrorActionPreference = "Stop"
$Eco = Join-Path (Split-Path $PSScriptRoot -Parent) ""
Set-Location $Eco

if (-not (Test-Path "smtp.env")) {
    Copy-Item "smtp.env.example" "smtp.env"
    Write-Host "Created smtp.env from example"
}

docker compose -f docker-compose.auth.yml --env-file smtp.env up -d db
Write-Host "Waiting for Postgres..."
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
    $h = docker inspect --format '{{.State.Health.Status}}' waypoint-db 2>$null
    if ($h -eq "healthy") { $ok = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $ok) { throw "Postgres not healthy" }

docker compose -f docker-compose.auth.yml --env-file smtp.env up -d --build auth-api
docker compose -f docker-compose.auth.yml --env-file smtp.env logs --tail 50 auth-api
Write-Host ""
Write-Host "Next (from this folder): .\scripts\start-apis.ps1"
Write-Host "Metric UI: cd d:\PO\Waypoint\web && npm run dev:metric"
