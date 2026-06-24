# Сборка Lynx и выкладка на VPS.
# Использование (PowerShell):
#   & "d:\PO\Lynx\scripts\push-lynx-update-to-server.ps1"
#   & "d:\PO\Lynx\scripts\push-lynx-update-to-server.ps1" -ServerHost root@72.56.244.26
param(
    [string]$ServerHost = '',
    [string]$ServerUser = 'root',
    [string]$RemotePoRoot = '/opt/waypoint/redik',
    [ValidateSet('windows', 'android', 'both', 'none')]
    [string]$BuildTarget = 'both',
    [switch]$SkipBuild,
    [switch]$SkipHub,
    [switch]$SkipMsi,
    [switch]$SkipGitPush,
    [switch]$RemoteOnly,
    [switch]$SkipVpsDeploy,
    [switch]$PublishEngine,
    [string]$EngineVersion = '0.15.0',
    [ValidateSet('stable', 'beta')]
    [string]$EngineChannel = 'stable',
    [switch]$EngineFullPack,
    [switch]$EngineSkipFlutter
)

$ErrorActionPreference = 'Stop'
$LynxRoot = Split-Path -Parent $PSScriptRoot
$PoRoot = Split-Path -Parent $LynxRoot
$HubDir = Join-Path $LynxRoot 'hub'
$DistLauncher = Join-Path $LynxRoot 'dist\lynx-launcher'
$DistInstaller = Join-Path $LynxRoot 'dist\lynx-installer'

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

if (-not $RemoteOnly) {
    if (-not $SkipBuild -and $BuildTarget -ne 'none') {
        Write-Step "Сборка Launcher (EXE/APK)"
        & (Join-Path $PoRoot 'deploy\ecosystem\scripts\build-lynx-releases.ps1') -Target $BuildTarget
    }

    if (-not $SkipMsi) {
        Write-Step "MSI Launcher + Engine + Arcade"
        & powershell -ExecutionPolicy Bypass -File (Join-Path $LynxRoot 'scripts\build-lynx-launcher-msi.ps1')
        $msi = Join-Path $DistInstaller 'Lynx-Launcher.msi'
        if (Test-Path $msi) {
            New-Item -ItemType Directory -Force -Path $DistLauncher | Out-Null
            Copy-Item $msi (Join-Path $DistLauncher 'Lynx-Launcher.msi') -Force
        }
    }

    if (-not $SkipHub) {
        Write-Step "Сборка Lynx Hub"
        Push-Location $HubDir
        try {
            if (-not (Test-Path 'node_modules')) { npm ci }
            npm run build
        } finally {
            Pop-Location
        }
        if (Test-Path (Join-Path $LynxRoot 'scripts\build-lynx-engine-web.ps1')) {
            Write-Step "Flutter Web engine-web"
            & (Join-Path $LynxRoot 'scripts\build-lynx-engine-web.ps1')
        }
    }

    if ($PublishEngine) {
        Write-Step "Lynx Engine $EngineVersion (локальная сборка + manifest)"
        $engineArgs = @{
            Version = $EngineVersion
            Channel = $EngineChannel
        }
        if ($EngineFullPack) { $engineArgs.FullPack = $true }
        if ($EngineSkipFlutter) { $engineArgs.SkipFlutter = $true }
        & (Join-Path $LynxRoot 'scripts\publish-lynx-engine-to-server.ps1') @engineArgs
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    if (-not $SkipGitPush) {
        Write-Step "Git commit/push"
        Push-Location $PoRoot
        try {
            $status = git status --porcelain 2>$null
            if ($status) {
                git add -A
                git commit -m "fix(lynx): launcher projects, arcade local play, messenger rate limit, hub admin API"
                git push origin HEAD
            } else {
                Write-Host "  Нет локальных изменений."
            }
        } catch {
            Write-Warning "  Git push: $_"
        } finally {
            Pop-Location
        }
    }
}

if (-not $ServerHost) {
    Write-Host ""
    Write-Host "Локальная сборка готова." -ForegroundColor Green
    Write-Host "  MSI:  $DistInstaller\Lynx-Launcher.msi"
    Write-Host "  Hub:  $HubDir\dist"
    Write-Host ""
    Write-Host 'Деплой на сервер:'
    Write-Host '  & "d:\PO\Lynx\scripts\push-lynx-update-to-server.ps1" -ServerHost root@72.56.244.26'
    exit 0
}

Write-Step "Выкладка на $ServerHost"
ssh $ServerHost "mkdir -p /srv/lynx-hub/dist/downloads"

if ($PublishEngine) {
    Write-Step "Lynx Engine $EngineVersion -> CDN на сервере"
    & (Join-Path $LynxRoot 'scripts\publish-lynx-engine-to-server.ps1') `
        -Version $EngineVersion `
        -Channel $EngineChannel `
        -SkipBuild `
        -ServerHost $ServerHost
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$files = @()
if (Test-Path $DistLauncher) {
    $files += Get-ChildItem $DistLauncher -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.exe', '.apk', '.zip', '.msi' }
}
$releasesDir = Join-Path $PoRoot 'releases\lynx-public'
if (Test-Path $releasesDir) {
    $files += Get-ChildItem $releasesDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.exe', '.apk', '.zip' }
}
foreach ($f in $files) {
    scp $f.FullName "${ServerHost}:/srv/lynx-hub/dist/downloads/$($f.Name)"
    Write-Host "  -> downloads/$($f.Name)"
}

$engineManifest = Join-Path $HubDir 'public\dist\downloads\engine-manifest.json'
if (Test-Path $engineManifest) {
    scp $engineManifest "${ServerHost}:/srv/lynx-hub/dist/downloads/engine-manifest.json"
    Write-Host "  -> downloads/engine-manifest.json"
}
$engineDir = Join-Path $HubDir 'public\dist\downloads\engine'
if (Test-Path $engineDir) {
    ssh $ServerHost "mkdir -p /srv/lynx-hub/dist/downloads/engine"
    Get-ChildItem $engineDir -Filter '*.lynxengine' -File -ErrorAction SilentlyContinue | ForEach-Object {
        scp $_.FullName "${ServerHost}:/srv/lynx-hub/dist/downloads/engine/$($_.Name)"
        Write-Host "  -> downloads/engine/$($_.Name)"
    }
}

if ((Test-Path (Join-Path $HubDir 'dist')) -and -not $SkipHub) {
    scp -r (Join-Path $HubDir 'dist\*') "${ServerHost}:/srv/lynx-hub/dist/"
    Write-Host "  -> hub dist"
}

Write-Step "Деплой на VPS (git pull + docker + sites)"
if (-not $SkipVpsDeploy) {
    ssh $ServerHost "bash $RemotePoRoot/deploy/ecosystem/scripts/deploy-lynx-from-git.sh"
} else {
    Write-Host "  SkipVpsDeploy — вызовите server-deploy-lynx-hub.sh отдельно"
}

Write-Host ""
Write-Host "Готово:" -ForegroundColor Green
Write-Host "  https://lynx-hub.ru/admin"
Write-Host "  https://lynx-hub.ru/lynx/v1/arcade/catalog"
Write-Host "  https://lynx-hub.ru/downloads/"
