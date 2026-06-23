# Lynx Launcher only — no engine, no player, no editor MSI.
param(
    [string]$OutDir = '',
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

Write-Host "== Lynx Launcher MSI (Launcher + Engine + Arcade demos) =="
Write-Host "Root: $Root"

if (-not $SkipFlutter) {
    Push-Location (Join-Path $Root 'client')
    flutter pub get
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Write-Host "[1/3] flutter build windows (Launcher main.dart)..."
    flutter build windows -t lib/main.dart --release
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

    $release = Join-Path $Root 'client\build\windows\x64\runner\Release'
    $launcherCache = Join-Path $OutDir 'launcher-build-cache'
    if (Test-Path $launcherCache) { Remove-Item $launcherCache -Recurse -Force }
    New-Item -ItemType Directory -Path $launcherCache -Force | Out-Null
    robocopy $release $launcherCache /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    Write-Host "  Cached launcher build"

    Write-Host "[2/3] flutter build windows (Player main_player.dart)..."
    flutter build windows -t lib/main_player.dart --release
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

    Write-Host "[3/3] flutter build windows (Engine main_engine.dart)..."
    flutter build windows -t lib/main_engine.dart --release
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
    Pop-Location
} else {
    $launcherCache = Join-Path $OutDir 'launcher-build-cache'
}

$stage = Join-Path $OutDir 'launcher-stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

if (-not (Test-Path $launcherCache)) {
    $launcherCache = Join-Path $Root 'client\build\windows\x64\runner\Release'
}
if (-not (Test-Path $launcherCache)) {
    Write-Error "Flutter launcher build missing: $launcherCache"
}
robocopy $launcherCache $stage /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null

$launcherExe = Join-Path $stage 'client.exe'
$lynxExe = Join-Path $stage 'LynxLauncher.exe'
if (Test-Path $launcherExe) {
    Move-Item -Force $launcherExe $lynxExe
    Write-Host "  Renamed client.exe -> LynxLauncher.exe"
} elseif (-not (Test-Path $lynxExe)) {
    Write-Error "Launcher executable not found in stage"
}

$playerSrc = Join-Path $Root 'client\build\windows\x64\runner\Release'
$playerDest = Join-Path $stage 'player\win'
if (Test-Path $playerSrc) {
    New-Item -ItemType Directory -Path $playerDest -Force | Out-Null
    robocopy $playerSrc $playerDest /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    $playerExe = Join-Path $playerDest 'client.exe'
    if (Test-Path $playerExe) {
        Copy-Item $playerExe (Join-Path $playerDest 'LynxPlayer.exe') -Force
    }
    Write-Host "  Player template: player/win"
}

$engineBuild = Join-Path $Root 'client\build\windows\x64\runner\Release\client.exe'
if (Test-Path $engineBuild) {
    Copy-Item $engineBuild (Join-Path $stage 'LynxEngine.exe') -Force
    Write-Host "  Bundled: LynxEngine.exe"
}

$arcadeDir = Join-Path $stage 'arcade'
New-Item -ItemType Directory -Path $arcadeDir -Force | Out-Null
foreach ($cartTpl in @('lynx-tetris', 'tetris-demo')) {
    $proj = Join-Path $Root "projects\$cartTpl"
    $outCart = Join-Path $arcadeDir "$cartTpl.lynxcart"
    if (Test-Path $proj) {
        Push-Location (Join-Path $Root 'client')
        dart run tool/pack_lynx_cart.dart $proj $outCart 2>&1 | Out-Null
        Pop-Location
        if (Test-Path $outCart) { Write-Host "  Arcade cart: $cartTpl.lynxcart" }
    }
}

$toolsDest = Join-Path $stage 'tools'
New-Item -ItemType Directory -Path $toolsDest -Force | Out-Null
$toolScript = Join-Path $Root 'scripts\ensure-lynx-android-toolchain.ps1'
if (Test-Path $toolScript) {
    Copy-Item $toolScript (Join-Path $toolsDest 'ensure-lynx-android-toolchain.ps1') -Force
    Write-Host "  Tool: ensure-lynx-android-toolchain.ps1"
}

$jniBundled = Join-Path $toolsDest 'jniLibs\arm64-v8a'
$jniSrc = Join-Path $Root 'client\android\app\src\main\jniLibs\arm64-v8a\libengine.so'
if (Test-Path $jniSrc) {
    New-Item -ItemType Directory -Path $jniBundled -Force | Out-Null
    Copy-Item $jniSrc (Join-Path $jniBundled 'libengine.so') -Force
    Write-Host "  Bundled: libengine.so"
} else {
    $apkScript = Join-Path $Root 'engine\scripts\build-apk.ps1'
    if (Test-Path $apkScript) {
        Write-Host "  [optional] Building libengine.so for APK…"
        try {
            & powershell -ExecutionPolicy Bypass -File $apkScript -Entry 'lib/main_player.dart' 2>&1 | Out-Null
            if (Test-Path $jniSrc) {
                New-Item -ItemType Directory -Path $jniBundled -Force | Out-Null
                Copy-Item $jniSrc (Join-Path $jniBundled 'libengine.so') -Force
                Write-Host "  Bundled: libengine.so (built)"
            }
        } catch {
            Write-Warning "  libengine.so not bundled (NDK/Rust optional): $_"
        }
    }
}

$templatesRoot = Join-Path $stage 'templates'
New-Item -ItemType Directory -Path $templatesRoot -Force | Out-Null
foreach ($tpl in @('platformer-demo', 'platformer-wave2', 'platformer-demo-3d-room', 'tetris-demo', 'lynx-tetris', 'tic-starter', 'empty')) {
    $srcTpl = Join-Path $Root "projects\$tpl"
    if (Test-Path $srcTpl) {
        robocopy $srcTpl (Join-Path $templatesRoot $tpl) /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
        Write-Host "  Template: $tpl"
    }
}

$wxs = Join-Path $PSScriptRoot 'installer\lynx-launcher-product.wxs'
$installerAssets = Join-Path $PSScriptRoot 'installer'
$iconSrc = Join-Path $Root 'client\windows\runner\resources\app_icon.ico'
$iconScript = Join-Path $PSScriptRoot 'generate-lynx-icon.ps1'
if (Test-Path $iconScript) {
    & powershell -ExecutionPolicy Bypass -File $iconScript | Out-Null
    Write-Host "  Icon: app_icon.ico (Lynx triangle mark)"
}
$clientSdk = Join-Path $stage 'sdk\client'
$clientSrc = Join-Path $Root 'client'
if (Test-Path $clientSrc) {
    New-Item -ItemType Directory -Path $clientSdk -Force | Out-Null
    robocopy $clientSrc $clientSdk /E /XD build .dart_tool .idea /XF *.iml /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    Write-Host "  SDK: sdk/client (APK build)"
}

$iconDest = Join-Path $installerAssets 'lynx_launcher.ico'
if (Test-Path (Join-Path $installerAssets 'lynx_launcher.png')) {
    Copy-Item (Join-Path $PSScriptRoot 'installer\lynx_launcher.png') (Join-Path $installerAssets 'lynx_launcher.ico') -Force -ErrorAction SilentlyContinue
}
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc $iconDest -Force
}

function Ensure-InstallerBitmaps {
    param([string]$Dir)
    $banner = Join-Path $Dir 'banner.bmp'
    $dialog = Join-Path $Dir 'dialog.bmp'
    if ((Test-Path $banner) -and (Test-Path $dialog)) { return }
    Add-Type -AssemblyName System.Drawing
    $bannerBmp = New-Object System.Drawing.Bitmap 493, 58
    $g = [System.Drawing.Graphics]::FromImage($bannerBmp)
    $g.Clear([System.Drawing.Color]::FromArgb(76, 29, 149))
    $g.Dispose()
    $bannerBmp.Save($banner, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bannerBmp.Dispose()

    $dlgBmp = New-Object System.Drawing.Bitmap 493, 312
    $g2 = [System.Drawing.Graphics]::FromImage($dlgBmp)
    $g2.Clear([System.Drawing.Color]::FromArgb(30, 30, 36))
    $g2.Dispose()
    $dlgBmp.Save($dialog, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $dlgBmp.Dispose()
}
Ensure-InstallerBitmaps -Dir $installerAssets

$wix = Find-WixTool
$msiOut = Join-Path $OutDir 'Lynx-Launcher.msi'
$msiVersioned = Join-Path $OutDir 'Lynx-Launcher-0.14.0.msi'
$zip = Join-Path $OutDir 'Lynx-Launcher.zip'
$productVersion = '0.14.0.0'

if ($null -eq $wix) {
    Write-Warning "WiX not found. Creating ZIP fallback."
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
    Write-Host "OK: $zip"
    exit 0
}

$work = Join-Path $OutDir 'wix-launcher'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

$wixBin = Split-Path $wix -Parent
$candle = Join-Path $wixBin 'candle.exe'
$light = Join-Path $wixBin 'light.exe'
$heat = Join-Path $wixBin 'heat.exe'

$harvestWxs = Join-Path $work 'harvest.wxs'
& $heat 'dir' $stage '-cg' 'LynxLauncherHarvest' '-dr' 'INSTALLDIR' '-gg' '-sfrag' '-srd' '-scom' '-sreg' '-platform' 'x64' '-out' $harvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $candle '-out' (Join-Path $work 'product.wixobj') "-dProductVersion=$productVersion" $wxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $candle '-out' (Join-Path $work 'harvest.wixobj') $harvestWxs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$wixUiExt = Join-Path $wixBin 'WixUIExtension.dll'
$wxlRu = Join-Path $installerAssets 'WixUI_ru-ru.wxl'
$lightArgs = @(
    '-out', $msiOut,
    '-b', $stage,
    '-b', $installerAssets,
    '-sice:ICE80',
    '-ext', $wixUiExt,
    '-loc', $wxlRu,
    '-cultures:ru-ru',
    (Join-Path $work 'product.wixobj'),
    (Join-Path $work 'harvest.wixobj')
)
& $light @lightArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item $msiOut $msiVersioned -Force

Write-Host ''
Write-Host '=========================================='
Write-Host "  Lynx Launcher MSI: $msiOut"
Write-Host "  Versioned copy:    $msiVersioned"
Write-Host "  Engine: install separately (.lynxengine)"
Write-Host '=========================================='
