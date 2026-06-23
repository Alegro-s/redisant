# Snapshot Lynx sources before a release build. Restore with restore-lynx-stable.ps1
param(
    [string]$Label = 'pre-release',
    [string]$OutRoot = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutRoot)) {
    $OutRoot = Join-Path $Root 'dist\backups'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupName = "lynx-stable-$stamp-$Label"
$stage = Join-Path $OutRoot $backupName
$zipPath = "$stage.zip"
$latestLink = Join-Path $OutRoot 'LATEST_STABLE.txt'

New-Item -ItemType Directory -Path $OutRoot -Force | Out-Null
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$paths = @(
    'client\lib',
    'client\test',
    'client\pubspec.yaml',
    'client\web',
    'engine\src',
    'engine\Cargo.toml',
    'lynx-core',
    'plugins',
    'projects',
    'scripts',
    'docs',
    'server\src',
    'hub',
    'cloud'
)

foreach ($rel in $paths) {
    $src = Join-Path $Root $rel
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $stage $rel
    $parent = Split-Path $dst -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    if ((Get-Item $src).PSIsContainer) {
        robocopy $src $dst /E /XD build .dart_tool target node_modules /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    } else {
        Copy-Item $src $dst -Force
    }
}

$gitHash = ''
$gitBranch = ''
try {
    Push-Location $Root
    $gitHash = (git rev-parse HEAD 2>$null)
    $gitBranch = (git rev-parse --abbrev-ref HEAD 2>$null)
    Pop-Location
} catch { Pop-Location -ErrorAction SilentlyContinue }

$manifest = @{
    format    = 'lynx_stable_backup'
    schema    = 1
    label     = $Label
    createdAt = (Get-Date -Format o)
    gitHash   = $gitHash
    gitBranch = $gitBranch
    root      = $Root
    paths     = $paths
} | ConvertTo-Json -Depth 4

$manifest | Set-Content (Join-Path $stage 'backup_manifest.json') -Encoding UTF8

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item $stage -Recurse -Force

@"
$backupName.zip
created=$(Get-Date -Format o)
git=$gitHash
branch=$gitBranch
label=$Label
"@ | Set-Content $latestLink -Encoding UTF8

Write-Host ''
Write-Host '=========================================='
Write-Host "  Lynx stable backup: $zipPath"
Write-Host "  Latest pointer:     $latestLink"
Write-Host '  Restore: scripts\restore-lynx-stable.ps1 -BackupZip ...'
Write-Host '=========================================='
