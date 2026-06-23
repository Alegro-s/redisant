# Сборка libengine.so для Android (без APK). Волна 4 / CI.
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
  Write-Error "NDK not found. Set ANDROID_NDK_HOME or sdk.dir in client/android/local.properties."
}
$env:ANDROID_NDK_HOME = $ndk
Write-Host "[ndk] ANDROID_NDK_HOME=$ndk"

& rustup target add aarch64-linux-android
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
  & cargo install cargo-ndk --locked
}

Set-Location $EngineRoot
& cargo ndk -t arm64-v8a -P 24 -o $JniLibs build --release
Write-Host "[ndk] OK: $JniLibs/arm64-v8a/libengine.so"
