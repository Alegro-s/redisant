# Lynx Launcher (Windows) + bundled engine.dll for offline test.
# Run: powershell -ExecutionPolicy Bypass -File deploy/ecosystem/scripts/pack-lynx-launcher-offline.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$EngineDir = Join-Path $RepoRoot "Lynx\engine"
$ClientDir = Join-Path $RepoRoot "Lynx\client"
$OutDir = Join-Path $RepoRoot "releases\lynx-launcher-offline"
$DistEngine = Join-Path $RepoRoot "Lynx\dist\engine"

New-Item -ItemType Directory -Force -Path $OutDir, $DistEngine | Out-Null

Write-Host "==> Rust engine (release)"
Set-Location $EngineDir
cargo build --release
$Dll = Join-Path $EngineDir "target\release\engine.dll"
if (-not (Test-Path $Dll)) { throw "engine.dll not found: $Dll" }
Copy-Item $Dll (Join-Path $DistEngine "engine.dll") -Force

Write-Host "==> Flutter Lynx Launcher"
Set-Location $ClientDir
flutter pub get
if (Test-Path "build\windows") { Remove-Item -Recurse -Force "build\windows" }
flutter build windows --release

$ReleaseDir = Join-Path $ClientDir "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleaseDir)) { throw "Flutter release dir missing: $ReleaseDir" }

$Exe = Get-ChildItem $ReleaseDir -Filter "*.exe" | Where-Object { $_.Name -notmatch "uninstall" } | Select-Object -First 1
if (-not $Exe) { throw "No launcher exe in $ReleaseDir" }

Copy-Item $Exe.FullName (Join-Path $OutDir $Exe.Name) -Force
Copy-Item (Join-Path $DistEngine "engine.dll") (Join-Path $OutDir "engine.dll") -Force
Get-ChildItem $ReleaseDir -Filter "*.dll" | ForEach-Object {
    if ($_.Name -ne "engine.dll") {
        Copy-Item $_.FullName (Join-Path $OutDir $_.Name) -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path (Join-Path $ReleaseDir "data")) {
    Copy-Item (Join-Path $ReleaseDir "data") (Join-Path $OutDir "data") -Recurse -Force
}

Write-Host "Done:"
Write-Host "  $(Join-Path $OutDir $Exe.Name)"
Write-Host "  $(Join-Path $OutDir 'engine.dll')"
