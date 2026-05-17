# Устаревший алиас — используйте push-redik-safe.ps1 (без --force по умолчанию).
param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$RepoRoot = "D:\PO",
    [string]$Message = "Waypoint ecosystem monorepo",
    [switch]$Force
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $here "push-redik-safe.ps1") -RepoRoot $RepoRoot -Token $Token -Message $Message @(
    if ($Force) { "-Force" }
)
