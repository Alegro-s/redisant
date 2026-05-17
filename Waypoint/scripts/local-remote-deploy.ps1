
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [string]$User = "root",
    [string]$RemotePath = "/root/NEXUS"
)

$ErrorActionPreference = "Stop"
$remote = "${User}@${Server}"

$RemotePathEsc = $RemotePath -replace "'", "'\''"
$cmd = "cd '$RemotePathEsc' && test -f .env || { echo '[NEXUS] Нет .env — cp .env.example .env на сервере'; exit 1; } && git pull --ff-only && docker compose up -d --build && docker compose ps && curl -sS http://127.0.0.1:8080/health"

Write-Host "[NEXUS] SSH $remote  ->  $RemotePath"
ssh $remote $cmd
