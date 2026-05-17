Param(
  [ValidateSet("windows", "android", "both")]
  [string]$Target = "both",
  [switch]$ZipSources
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$clientDir = Join-Path $repoRoot "client"
$outDir = Join-Path $repoRoot "dist\lynx-launcher"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Set-Location $clientDir
Write-Host "[lynx-build] flutter pub get"
flutter pub get

if ($Target -eq "windows" -or $Target -eq "both") {
  Write-Host "[lynx-build] flutter build windows --release"
  flutter build windows --release
  $winSrc = Join-Path $clientDir "build\windows\x64\runner\Release"
  $winDst = Join-Path $outDir "windows-release"
  if (Test-Path $winSrc) {
    Copy-Item -Path $winSrc -Destination $winDst -Recurse -Force
    Write-Host "[lynx-build] Windows: $winDst"
  }
}

if ($Target -eq "android" -or $Target -eq "both") {
  Write-Host "[lynx-build] flutter build apk --release"
  flutter build apk --release
  $apk = Join-Path $clientDir "build\app\outputs\flutter-apk\app-release.apk"
  if (Test-Path $apk) {
    Copy-Item -Path $apk -Destination (Join-Path $outDir "app-release.apk") -Force
    Write-Host "[lynx-build] APK: $outDir\app-release.apk"
  }
}

if ($ZipSources) {
  $zipPath = Join-Path $outDir "lynx-launcher-sources.zip"
  $temp = Join-Path $env:TEMP "lynx-src-$(Get-Random)"
  New-Item -ItemType Directory -Force -Path $temp | Out-Null
  try {
    $dirs = @("lib", "android", "windows", "assets", "test")
    foreach ($d in $dirs) {
      $p = Join-Path $clientDir $d
      if (Test-Path $p) { Copy-Item -Path $p -Destination (Join-Path $temp $d) -Recurse -Force }
    }
    foreach ($f in @("pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "README.md")) {
      $p = Join-Path $clientDir $f
      if (Test-Path $p) { Copy-Item -Path $p -Destination (Join-Path $temp $f) -Force }
    }
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
    Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "[lynx-build] Sources zip: $zipPath"
  }
  finally {
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
  }
}

Write-Host "[lynx-build] Done. Артефакты в: $outDir"
Write-Host "  Загрузите файлы на CDN/GitHub Releases и пропишите URL в nexus-hab/.env (VITE_LYNX_LAUNCHER_EXE_URL и т.д.)."
