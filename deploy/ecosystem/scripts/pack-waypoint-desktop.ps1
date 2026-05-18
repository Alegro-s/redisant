Param(
    [string]$DesktopDir = "",
    [string]$OutDir = "",
    [switch]$SkipTauri
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if (-not $OutDir) {
    $OutDir = Join-Path $RepoRoot "releases\waypoint-desktop"
}
$PublicDl = Join-Path $RepoRoot "Waypoint\web\public\downloads"

if (-not $DesktopDir) {
    $DesktopDir = Join-Path $RepoRoot "Waypoint\desktop"
}
if (-not (Test-Path $DesktopDir)) {
    throw "Waypoint Desktop not found: $DesktopDir"
}

New-Item -ItemType Directory -Force -Path $OutDir, $PublicDl | Out-Null
Set-Location $DesktopDir

if (-not (Test-Path "node_modules")) {
    if (Test-Path "package-lock.json") { npm ci } else { npm install }
}

$iconSrc = Join-Path $RepoRoot "Waypoint\web\public\favicon.svg"
$iconDir = Join-Path $DesktopDir "src-tauri\icons"
if ((Test-Path $iconSrc) -and -not (Test-Path (Join-Path $iconDir "icon.ico"))) {
    Write-Host "[waypoint-desktop] generate icons from favicon.svg..."
    New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
    npx --yes @tauri-apps/cli icon $iconSrc -o $iconDir 2>&1 | Out-Host
}

if (-not $SkipTauri) {
    Write-Host "[waypoint-desktop] npm run tauri build..."
    npm run tauri build
}

$msi = Get-ChildItem -Path "src-tauri\target\release\bundle\msi" -Filter "*.msi" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $msi) {
    $msi = Get-ChildItem -Path "src-tauri\target\release\bundle" -Recurse -Include "*.msi" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
$portable = Get-ChildItem -Path "src-tauri\target\release" -Filter "Waypoint Desktop.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $portable) {
    $portable = Get-ChildItem -Path "src-tauri\target\release\bundle\nsis" -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "uninstall" } | Select-Object -First 1
}

$setupName = "WaypointDesktop-setup.msi"
if ($msi) {
    Copy-Item $msi.FullName (Join-Path $OutDir $setupName) -Force
    Copy-Item $msi.FullName (Join-Path $PublicDl $setupName) -Force
    Write-Host "  Setup: $OutDir\$setupName"
}
if ($portable) {
    Copy-Item $portable.FullName (Join-Path $OutDir "WaypointDesktop.exe") -Force
    Write-Host "  EXE: $OutDir\WaypointDesktop.exe"
}

if (-not $msi -and -not $portable) {
    Write-Host "  WARN: no bundle artifacts (install Rust/WebView2 or run without -SkipTauri)"
}

# sync manifest size only (URL stays S3 — see desktop-releases.json)
$manifestPath = Join-Path $RepoRoot "Waypoint\web\public\desktop-releases.json"
if ((Test-Path $manifestPath) -and (Test-Path (Join-Path $PublicDl $setupName))) {
    $f = Get-Item (Join-Path $PublicDl $setupName)
    $mb = [math]::Round($f.Length / 1MB, 2)
    $json = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if (-not $json.downloads.windows.url -or $json.downloads.windows.url -match '^/downloads/') {
        $json.downloads.windows.url = "https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/project's/waypointdesktop/$setupName"
    }
    $json.downloads.windows.size_mb = $mb
    $json | ConvertTo-Json -Depth 6 | Set-Content $manifestPath -Encoding UTF8
}

Write-Host "Done: $OutDir (also copied to Waypoint/web/public/downloads/)"
Get-ChildItem $OutDir -File -ErrorAction SilentlyContinue | Format-Table Name, @{N="MB";E={[math]::Round($_.Length/1MB,2)}}
