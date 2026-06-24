# Build Flutter Web Lynx Engine for Hub (/engine-web/).
param(
    [string]$ClientDir = '',
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if ($ClientDir -eq '') { $ClientDir = Join-Path $Root 'client' }
if ($OutDir -eq '') { $OutDir = Join-Path $Root 'hub\public\engine-web' }

Write-Host "==> Flutter web engine -> $OutDir" -ForegroundColor Cyan
Push-Location $ClientDir
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    flutter build web -t lib/main_engine.dart --release --base-href /engine-web/ --no-wasm-dry-run
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

$build = Join-Path $ClientDir 'build\web'
if (-not (Test-Path $build)) {
    Write-Error "Missing build output: $build"
}

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
robocopy $build $OutDir /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
if ($LASTEXITCODE -ge 8) { exit $LASTEXITCODE }

Write-Host "Done: $OutDir" -ForegroundColor Green
