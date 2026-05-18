Param(
    [ValidateSet("windows", "android", "both")]
    [string]$Target = "both",
    [switch]$SkipEngine,
    [switch]$ZipSources,
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$LynxRoot = Join-Path $RepoRoot "Lynx"
$ClientDir = Join-Path $LynxRoot "client"
$EngineDir = Join-Path $LynxRoot "engine"

if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot "releases\lynx-public"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Require-Cmd($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $name"
    }
}

Require-Cmd flutter

$version = "0.1.0"
$pubspec = Join-Path $ClientDir "pubspec.yaml"
if (Test-Path $pubspec) {
    if ((Get-Content $pubspec -Raw) -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
        $version = $Matches[1]
    }
}

Write-Host "[lynx-release] version: $version"
Write-Host "[lynx-release] output: $OutDir"

Set-Location $ClientDir
flutter clean 2>&1 | Out-Null
flutter pub get

if ($Target -eq "windows" -or $Target -eq "both") {
    Write-Host "[lynx-release] Windows release..."
    if (Test-Path "build\windows") { Remove-Item -Recurse -Force "build\windows" -ErrorAction SilentlyContinue }
    flutter build windows --release
    $winSrc = Join-Path $ClientDir "build\windows\x64\runner\Release"
    if (-not (Test-Path $winSrc)) {
        throw "Build folder missing: $winSrc"
    }
    $zipWin = Join-Path $OutDir "LynxLauncher-win-x64.zip"
    if (Test-Path $zipWin) { Remove-Item -Force $zipWin }
    Compress-Archive -Path (Join-Path $winSrc "*") -DestinationPath $zipWin -CompressionLevel Optimal
    Write-Host "  ZIP: $zipWin"

    $exe = Get-ChildItem $winSrc -Filter "*.exe" | Select-Object -First 1
    if ($exe) {
        Copy-Item $exe.FullName (Join-Path $OutDir "LynxLauncher.exe") -Force
        Write-Host "  EXE: $OutDir\LynxLauncher.exe ($($exe.Name))"
    }
}

if ($Target -eq "android" -or $Target -eq "both") {
    Write-Host "[lynx-release] Android APK..."
    flutter build apk --release
    $apk = Join-Path $ClientDir "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apk)) {
        throw "APK missing: $apk"
    }
    Copy-Item $apk (Join-Path $OutDir "app-release.apk") -Force
    Write-Host "  APK: $OutDir\app-release.apk"
}

if ($ZipSources) {
    & (Join-Path $LynxRoot "scripts\build-lynx-client-on-pc.ps1") -Target $Target -ZipSources
    $srcZip = Join-Path $LynxRoot "dist\lynx-launcher\lynx-launcher-sources.zip"
    if (Test-Path $srcZip) {
        Copy-Item $srcZip (Join-Path $OutDir "lynx-launcher-sources.zip") -Force
        Write-Host "  Sources: $OutDir\lynx-launcher-sources.zip"
    }
}

if (-not $SkipEngine -and (Test-Path (Join-Path $EngineDir "Cargo.toml"))) {
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        Write-Host "[lynx-release] Engine (Rust, optional)..."
        try {
            Set-Location $EngineDir
            cargo build --release 2>&1 | Out-Host
            $dll = Join-Path $EngineDir "target\release\lynx_engine.dll"
            if (Test-Path $dll) {
                Copy-Item $dll (Join-Path $OutDir "lynx_engine.dll") -Force
                Write-Host "  Engine DLL: $OutDir\lynx_engine.dll"
            }
        } catch {
            Write-Host "  Engine skipped: $($_.Exception.Message)"
        }
    }
}

$files = @(Get-ChildItem $OutDir -File | ForEach-Object { $_.Name })
$manifest = @{
    version   = $version
    built_at  = (Get-Date).ToUniversalTime().ToString("o")
    files     = $files
    hub_urls  = @{
        exe = "https://lynx-hub.ru/downloads/LynxLauncher.exe"
        zip = "https://lynx-hub.ru/downloads/LynxLauncher-win-x64.zip"
        apk = "https://lynx-hub.ru/downloads/app-release.apk"
        src = "https://lynx-hub.ru/downloads/lynx-launcher-sources.zip"
    }
    s3_prefix = "lynx/"
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutDir "manifest.json") -Encoding utf8

Write-Host ""
Write-Host "=========================================="
Write-Host " Done: $OutDir"
Get-ChildItem $OutDir -File | Format-Table Name, @{N="MB";E={[math]::Round($_.Length/1MB,2)}}
Write-Host ""
Write-Host "Next: .\deploy\ecosystem\scripts\upload-timeweb-s3.ps1"
Write-Host "=========================================="
