param(
  [string]$Entry = "lib/main.dart"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EngineRoot = Split-Path -Parent $ScriptDir
$RepoRoot = Split-Path -Parent $EngineRoot
$ClientRoot = Join-Path $RepoRoot "client"
$JniLibs = Join-Path $ClientRoot "android/app/src/main/jniLibs"

function Get-AndroidNdkHome {
  if ($env:ANDROID_NDK_HOME -and (Test-Path $env:ANDROID_NDK_HOME)) {
    return $env:ANDROID_NDK_HOME
  }
  $lp = Join-Path $ClientRoot "android/local.properties"
  if (-not (Test-Path $lp)) { return $null }
  foreach ($line in Get-Content $lp -Encoding UTF8) {
    if ($line -match '^\s*sdk\.dir\s*=\s*(.+)\s*$') {
      $raw = $matches[1].Trim()
      $sdk = $raw -replace '\\\\', '\'
      $ndkBase = Join-Path $sdk "ndk"
      if (-not (Test-Path $ndkBase)) { return $null }
      $pick = Get-ChildItem $ndkBase -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
      if ($pick) { return $pick.FullName }
    }
  }
  return $null
}

$ndk = Get-AndroidNdkHome
if (-not $ndk) {
  Write-Error "Не найден NDK. Установите NDK в Android Studio, задайте ANDROID_NDK_HOME или sdk.dir в client/android/local.properties."
}
$env:ANDROID_NDK_HOME = $ndk
Write-Host "[engine] ANDROID_NDK_HOME=$ndk"

Write-Host "[engine] rustup target add aarch64-linux-android"
& rustup target add aarch64-linux-android

if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
  Write-Host "[engine] cargo install cargo-ndk..."
  & cargo install cargo-ndk --locked
}

Write-Host "[engine] cargo ndk build -> jniLibs (arm64-v8a)..."
Set-Location $EngineRoot
& cargo ndk -t arm64-v8a -P 24 -o $JniLibs build --release

Write-Host "[engine] flutter build apk --release (-t $Entry)..."
Set-Location $ClientRoot
& flutter pub get
& flutter build apk -t $Entry --release

Write-Host "[engine] готово: $ClientRoot\build\app\outputs\flutter-apk\app-release.apk"
