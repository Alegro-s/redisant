# E22c/E23c — pack Lynx Engine: engine.dll + LynxEngine shell + player + templates.
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Target = 'release',
    [string]$EngineDir = '',
    [string]$Platform = 'windows',
    [string]$LynxCoreVersion = '1.0.0',
    [switch]$SkipFlutter,
    [switch]$SkipEngine
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if ($EngineDir -eq '') { $EngineDir = Join-Path $Root 'engine' }
$Client = Join-Path $Root 'client'
$Dist = Join-Path $Root "dist\lynx_engine_$Version"
$Extras = Join-Path $Dist 'extras_stage'
$OutPack = Join-Path $Dist "$Platform.lynxengine"

Write-Host "=== Lynx Engine full pack $Version ($Platform) ===" -ForegroundColor Cyan

if (-not $SkipEngine) {
    Push-Location $EngineDir
    try {
        cargo build --$Target --no-default-features
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
    & (Join-Path $Root 'lynx-core\scripts\compile-shaders.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $SkipFlutter) {
    Push-Location $Client
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Host 'Building LynxEngine.exe (main_engine.dart)...'
        flutter build windows -t lib/main_engine.dart --release
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Host 'Building LynxPlayer (main_player.dart)...'
        flutter build windows -t lib/main_player.dart --release
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

if (Test-Path $Extras) { Remove-Item $Extras -Recurse -Force }
New-Item -ItemType Directory -Path $Extras -Force | Out-Null

$release = Join-Path $Client 'build\windows\x64\runner\Release'
if (-not (Test-Path $release)) {
    Write-Error "Flutter build missing: $release"
}

$shellDir = Join-Path $Extras 'shell'
New-Item -ItemType Directory -Path $shellDir -Force | Out-Null
robocopy $release $shellDir /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
$engineExe = Join-Path $shellDir 'client.exe'
if (Test-Path $engineExe) {
    Move-Item -Force $engineExe (Join-Path $shellDir 'LynxEngine.exe')
}
Write-Host '  extras/shell/LynxEngine.exe'

$playerDest = Join-Path $Extras 'player\win'
New-Item -ItemType Directory -Path $playerDest -Force | Out-Null
robocopy $release $playerDest /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
$playerExe = Join-Path $playerDest 'client.exe'
if (Test-Path $playerExe) {
    Copy-Item $playerExe (Join-Path $playerDest 'LynxPlayer.exe') -Force
}
Write-Host '  extras/player/win (E22c player template)'

$templatesRoot = Join-Path $Extras 'templates'
New-Item -ItemType Directory -Path $templatesRoot -Force | Out-Null
foreach ($tpl in @('platformer-demo', 'platformer-wave2', 'platformer-demo-3d-room', 'tetris-demo', 'lynx-tetris', 'tic-starter', 'empty')) {
    $srcTpl = Join-Path $Root "projects\$tpl"
    if (Test-Path $srcTpl) {
        robocopy $srcTpl (Join-Path $templatesRoot $tpl) /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
        Write-Host "  extras/templates/$tpl (E23c)"
    }
}

New-Item -ItemType Directory -Path $Dist -Force | Out-Null
$PackScript = Join-Path $PSScriptRoot 'pack_lynx_engine.py'
python $PackScript `
    --version $Version `
    --platform $Platform `
    --engine-dir $EngineDir `
    --lynx-core-version $LynxCoreVersion `
    --extras-dir $Extras `
    -o $OutPack

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '=========================================='
Write-Host "  Engine pack: $OutPack"
Write-Host "  Extras stage: $Extras"
Write-Host '=========================================='
