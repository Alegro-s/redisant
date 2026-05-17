
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not $env:JWT_SECRET -or $env:JWT_SECRET.Length -lt 32) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 48
    $rng.GetBytes($bytes)
    $env:JWT_SECRET = [Convert]::ToBase64String($bytes)
    Write-Host "[NEXUS] JWT_SECRET was missing or short - generated for this session only."
    Write-Host "        To keep it: set env var JWT_SECRET (32+ chars) before running this script."
}

if (-not $env:CORS_ALLOWED_ORIGINS) {
    $env:CORS_ALLOWED_ORIGINS = "http://127.0.0.1:8080,http://127.0.0.1:5173,http://localhost:8080,http://localhost:5173,http://localhost:3000,http://127.0.0.1:3000"
}

if (-not $env:ADMIN_OPEN_REGISTRATION) {
    $env:ADMIN_OPEN_REGISTRATION = "1"
}

Write-Host "[NEXUS] Directory: $RepoRoot"
Write-Host "[NEXUS] docker compose up -d --build ..."
docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
    Write-Host "[NEXUS] docker compose failed (exit $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "[NEXUS] Done."
Write-Host "  API:    http://127.0.0.1:8080"
Write-Host "  Health: http://127.0.0.1:8080/health"
Write-Host "  Logs:   docker compose logs -f api"
Write-Host "  Stop:   docker compose down"
Write-Host ""
Write-Host "[NEXUS] In Flutter Profile set server URL: http://127.0.0.1:8080"
