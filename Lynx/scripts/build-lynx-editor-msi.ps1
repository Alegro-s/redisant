# DEPRECATED: bundles Editor+Player+engine — wrong product model.
# Use build-lynx-launcher-msi.ps1 (Launcher only) + publish_lynx_engine_release.ps1 (.lynxengine).
# Lynx Editor + Engine - local build and MSI installer (Windows).
param(
    [ValidateSet('editor', 'player', 'both')]
    [string]$Target = 'both',
    [string]$OutDir = '',
    [switch]$SkipEngine,
    [switch]$SkipFlutter
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Root 'dist\lynx-installer'
}

function Find-WixTool {
    $list = @()
    $w = Get-Command 'wix.exe' -ErrorAction SilentlyContinue
    if ($w) { $list += $w.Source }
    $c = Get-Command 'candle.exe' -ErrorAction SilentlyContinue
    if ($c) { $list += $c.Source }
    $list += "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin\candle.exe"
    $list += "${env:ProgramFiles}\WiX Toolset v3.14\bin\candle.exe"
    foreach ($p in $list) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

Write-Host "== Lynx build root: $Root =="

if (-not $SkipEngine) {
    Write-Host "[1/4] cargo build --release (engine + lynx-core)..."
    Push-Location (Join-Path $Root 'engine')
    cargo build --release
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Pop-Location

    Write-Host "[1b] compile HLSL shaders..."
    & (Join-Path $Root 'lynx-core\scripts\compile-shaders.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "[4/4] Packaging..."
$stage = Join-Path $OutDir 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

$engineDll = Join-Path $Root 'engine\target\release\engine.dll'
if (-not (Test-Path $engineDll)) {
    Write-Error "engine.dll not found. Run without -SkipEngine."
}

function Stage-ReleaseFolder {
    param([string]$Name)
    $src = Join-Path $Root 'client\build\windows\x64\runner\Release'
    if (-not (Test-Path $src)) {
        Write-Error "Flutter build missing: $src"
    }
    $dst = Join-Path $stage $Name
    New-Item -ItemType Directory -Path (Join-Path $dst 'bin') -Force | Out-Null
    robocopy $src $dst /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    Copy-Item $engineDll (Join-Path $dst 'bin\engine.dll') -Force
    robocopy (Join-Path $Root 'projects\platformer-demo-3d-room') (Join-Path $dst 'demo\platformer-demo-3d-room') /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
}

if (-not $SkipFlutter) {
    Push-Location (Join-Path $Root 'client')
    flutter pub get
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

    if ($Target -eq 'editor' -or $Target -eq 'both') {
        Write-Host "[2/4] flutter build windows (Editor)..."
        flutter build windows -t lib/main_editor.dart --release
        if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
        Stage-ReleaseFolder -Name 'LynxEditor'
    }
    if ($Target -eq 'player' -or $Target -eq 'both') {
        Write-Host "[3/4] flutter build windows (Player)..."
        flutter build windows -t lib/main_player.dart --release
        if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
        Stage-ReleaseFolder -Name 'LynxPlayer'
    }
    Pop-Location
}

$wxs = Join-Path $PSScriptRoot 'installer\lynx-product.wxs'
$wix = Find-WixTool
$msiOut = Join-Path $OutDir 'Lynx-Studio.msi'
$zip = Join-Path $OutDir 'Lynx-Studio.zip'

if ($null -eq $wix) {
    Write-Warning "WiX not found. Creating ZIP fallback."
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
    Write-Host "OK: $zip"
    Write-Host "Install WiX Toolset v3.14+ for MSI: https://wixtoolset.org/"
    exit 0
}

$work = Join-Path $OutDir 'wix'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$wixBin = Split-Path $wix -Parent
$candle = Join-Path $wixBin 'candle.exe'
$light = Join-Path $wixBin 'light.exe'
$heat = Join-Path $wixBin 'heat.exe'
if (-not (Test-Path $candle)) { $candle = $wix }

$harvestWxs = Join-Path $work 'harvest.wxs'
if (-not (Test-Path $heat)) {
    Write-Warning "heat.exe not found. Creating ZIP fallback."
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
    Write-Host "OK: $zip"
    exit 0
}

& $heat 'dir' $stage '-cg' 'LynxHarvest' '-dr' 'INSTALLDIR' '-gg' '-sfrag' '-srd' '-scom' '-sreg' '-platform' 'x64' '-out' $harvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $candle '-out' (Join-Path $work 'product.wixobj') '-dProductVersion=0.14.0.0' $wxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $candle '-out' (Join-Path $work 'harvest.wixobj') $harvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $light '-out' $msiOut '-b' $stage '-sice:ICE80' (Join-Path $work 'product.wixobj') (Join-Path $work 'harvest.wixobj')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host '=========================================='
Write-Host "  MSI ready: $msiOut"
Write-Host "  Stage:     $stage"
Write-Host '=========================================='
