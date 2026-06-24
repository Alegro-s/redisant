# Полный деплой Lynx Hub + downloads с Windows PC.
#
# Примеры:
#   & "d:\PO\Lynx\scripts\deploy-lynx-full-from-pc.ps1" -ServerHost root@72.56.244.26
#   & "d:\PO\Lynx\scripts\deploy-lynx-full-from-pc.ps1" -ServerHost root@72.56.244.26 -SkipLauncher -SkipEngine
#   & "d:\PO\Lynx\scripts\deploy-lynx-full-from-pc.ps1" -ServerHost root@72.56.244.26 -PublishEngine
param(
    [Parameter(Mandatory = $true)][string]$ServerHost,
    [string]$RemotePoRoot = '/opt/waypoint/redik',
    [switch]$SkipLauncher,
    [switch]$SkipEngine,
    [switch]$SkipEngineWeb,
    [switch]$SkipHub,
    [switch]$SkipGitPush,
    [switch]$PublishEngine,
    [string]$EngineVersion = '0.15.0',
    [ValidateSet('stable', 'beta')]
    [string]$EngineChannel = 'stable',
    [ValidateSet('windows', 'android', 'both', 'none')]
    [string]$BuildTarget = 'both'
)

$ErrorActionPreference = 'Stop'
$LynxRoot = Split-Path -Parent $PSScriptRoot
$PoRoot = Split-Path -Parent $LynxRoot
$HubDir = Join-Path $LynxRoot 'hub'

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

if (-not $SkipEngineWeb) {
    Write-Step 'Flutter Web engine-web'
    & (Join-Path $LynxRoot 'scripts\build-lynx-engine-web.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $SkipHub) {
    Write-Step 'Сборка Lynx Hub (npm)'
    Push-Location $HubDir
    try {
        if (-not (Test-Path 'node_modules')) { npm ci }
        npm run build
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally {
        Pop-Location
    }
}

$pushArgs = @{
    ServerHost     = $ServerHost
    RemotePoRoot   = $RemotePoRoot
    SkipGitPush    = $true
    SkipHub        = $true
}
if ($SkipLauncher) {
    $pushArgs.BuildTarget = 'none'
    $pushArgs.SkipBuild = $true
    $pushArgs.SkipMsi = $true
} else {
    $pushArgs.BuildTarget = $BuildTarget
}
if ($SkipEngine) {
    $pushArgs.PublishEngine = $false
} elseif ($PublishEngine) {
    $pushArgs.PublishEngine = $true
    $pushArgs.EngineVersion = $EngineVersion
    $pushArgs.EngineChannel = $EngineChannel
}

if (-not $SkipGitPush) {
    Write-Step 'Git commit + push (hub/deploy only)'
    Push-Location $PoRoot
    try {
        $paths = @(
            'Lynx/client/lib/app/router_engine.dart',
            'Lynx/client/lib/features/engine/screens/engine_install_hub_screen.dart',
            'Lynx/hub/src/pages/AccountPage.tsx',
            'Lynx/hub/public/engine-web',
            'Lynx/hub/public/dist/downloads',
            'deploy/ecosystem/scripts/server-deploy-lynx-hub.sh',
            'deploy/ecosystem/scripts/write-hub-env-production.sh',
            'deploy/ecosystem/scripts/server-02-clone-github-redik.sh',
            'Lynx/scripts/deploy-lynx-full-from-pc.ps1',
            '.gitignore'
        )
        foreach ($p in $paths) {
            if (Test-Path (Join-Path $PoRoot $p)) {
                git add $p
            }
        }
        $staged = git diff --cached --name-only
        if ($staged) {
            git commit -m "fix(hub): web engine gate, downloads deploy script, preserve /downloads on rsync"
            git push origin HEAD
        } else {
            Write-Host '  Нет staged hub/deploy изменений для коммита.'
        }
    } catch {
        Write-Warning "  Git push: $_"
    } finally {
        Pop-Location
    }
}

Write-Step "Выкладка downloads + Hub static на $ServerHost"
& (Join-Path $LynxRoot 'scripts\push-lynx-update-to-server.ps1') @pushArgs -RemoteOnly
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipHub) {
    Write-Step 'Hub dist (engine-web + vite)'
    scp -r (Join-Path $HubDir 'dist\*') "${ServerHost}:/srv/lynx-hub/dist/"
}

Write-Step 'VPS: server-deploy-lynx-hub.sh'
ssh $ServerHost "sudo bash $RemotePoRoot/deploy/ecosystem/scripts/server-deploy-lynx-hub.sh"

Write-Host ''
Write-Host 'Готово:' -ForegroundColor Green
Write-Host '  https://lynx-hub.ru/'
Write-Host '  https://lynx-hub.ru/engine-web/'
Write-Host '  https://lynx-hub.ru/download'
Write-Host '  https://lynx-hub.ru/downloads/'
