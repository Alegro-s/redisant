# Lynx: JDK 17 + Android SDK + NDK в %LOCALAPPDATA%\Lynx (без Android Studio).
param([string]$ClientRoot = '')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$LynxRoot = Join-Path $env:LOCALAPPDATA 'Lynx'
$SdkRoot = Join-Path $LynxRoot 'android-sdk'
$JdkRoot = Join-Path $LynxRoot 'jdk-17'
$Cache = Join-Path $LynxRoot 'cache'
New-Item -ItemType Directory -Force -Path $Cache, $SdkRoot | Out-Null

function Test-ZipReadable([string]$Path) {
  if (-not (Test-Path $Path)) { return $false }
  try {
    $z = [System.IO.Compression.ZipFile]::OpenRead($Path)
    $z.Dispose()
    return $true
  } catch {
    return $false
  }
}

function Get-Download([string]$Url, [string]$Dest) {
  if (Test-ZipReadable $Dest) { return }
  if (Test-Path $Dest) {
    Remove-Item $Dest -Force -ErrorAction SilentlyContinue
  }
  $part = "$Dest.part"
  if (Test-Path $part) {
    Remove-Item $part -Force -ErrorAction SilentlyContinue
  }
  Write-Host "[lynx-android] download $Url"
  Invoke-WebRequest -Uri $Url -OutFile $part -UseBasicParsing
  if (Test-Path $Dest) { Remove-Item $Dest -Force }
  Move-Item -Force $part $Dest
}

function Expand-ZipSafe([string]$Zip, [string]$Dest) {
  $workZip = Join-Path $Cache ("work-" + [guid]::NewGuid().ToString('N') + ".zip")
  Copy-Item -LiteralPath $Zip -Destination $workZip -Force
  try {
    if (Test-Path $Dest) { Remove-Item $Dest -Recurse -Force }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($workZip, $Dest)
  } finally {
    Remove-Item $workZip -Force -ErrorAction SilentlyContinue
  }
}

function Enter-LynxToolchainLock([scriptblock]$Body) {
  $lock = Join-Path $Cache 'toolchain-setup.lock'
  $deadline = (Get-Date).AddMinutes(60)
  while (Test-Path $lock) {
    if ((Get-Date) -gt $deadline) {
      throw 'Другая установка Android toolchain не завершилась за 60 минут. Закройте параллельные сборки Lynx и повторите.'
    }
    $item = Get-Item $lock -ErrorAction SilentlyContinue
    if ($item -and ((Get-Date) - $item.LastWriteTime).TotalHours -gt 3) {
      Remove-Item $lock -Force -ErrorAction SilentlyContinue
      break
    }
    Write-Host '[lynx-android] ожидание завершения другой установки…'
    Start-Sleep -Seconds 4
  }
  New-Item -ItemType File -Path $lock -Force | Out-Null
  try {
    & $Body
  } finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
  }
}

Enter-LynxToolchainLock {
  # JDK 17 (Microsoft build)
  if (-not (Test-Path (Join-Path $JdkRoot 'bin\java.exe'))) {
    $jdkZip = Join-Path $Cache 'microsoft-jdk-17.zip'
    Get-Download 'https://aka.ms/download-jdk/microsoft-jdk-17.0.13-windows-x64.zip' $jdkZip
    $tmp = Join-Path $Cache 'jdk-extract'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-ZipSafe $jdkZip $tmp
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (Test-Path $JdkRoot) { Remove-Item $JdkRoot -Recurse -Force }
    Move-Item $inner.FullName $JdkRoot
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }

  $env:JAVA_HOME = $JdkRoot
  $env:ANDROID_HOME = $SdkRoot
  $env:ANDROID_SDK_ROOT = $SdkRoot

  # cmdline-tools
  $cmdLatest = Join-Path $SdkRoot 'cmdline-tools\latest'
  if (-not (Test-Path (Join-Path $cmdLatest 'bin\sdkmanager.bat'))) {
    $ctZip = Join-Path $Cache 'cmdline-tools-win.zip'
    Get-Download 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' $ctZip
    $ctTmp = Join-Path $Cache 'cmdline-tools-tmp'
    if (Test-Path $ctTmp) { Remove-Item $ctTmp -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $SdkRoot 'cmdline-tools') -Force | Out-Null
    Expand-ZipSafe $ctZip $ctTmp
    if (Test-Path $cmdLatest) { Remove-Item $cmdLatest -Recurse -Force }
    Move-Item (Join-Path $ctTmp 'cmdline-tools') $cmdLatest
    Remove-Item $ctTmp -Recurse -Force -ErrorAction SilentlyContinue
  }

  $sdkmanager = Join-Path $cmdLatest 'bin\sdkmanager.bat'
  Write-Host '[lynx-android] sdkmanager packages…'
  $pkgs = @(
    'platform-tools',
    'platforms;android-34',
    'build-tools;34.0.0',
    'ndk;26.1.10909125'
  )
  & $sdkmanager --sdk_root=$SdkRoot $pkgs | ForEach-Object { Write-Host $_ }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $ndkDir = Join-Path $SdkRoot 'ndk'
  $ndk = Get-ChildItem $ndkDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
  if ($ndk) { $env:ANDROID_NDK_HOME = $ndk.FullName }

  if ($ClientRoot -and (Test-Path $ClientRoot)) {
    $lp = Join-Path $ClientRoot 'android\local.properties'
    $sdkEsc = $SdkRoot -replace '\\', '\\'
    $lines = @()
    if (Test-Path $lp) { $lines = Get-Content $lp -Encoding UTF8 }
    $lines = $lines | Where-Object { $_ -notmatch '^\s*sdk\.dir\s*=' }
    $lines += "sdk.dir=$sdkEsc"
    Set-Content -Path $lp -Value ($lines -join "`n") -Encoding UTF8
    Write-Host '[lynx-android] local.properties updated'
  }

  Write-Host "[lynx-android] OK JAVA_HOME=$JdkRoot"
  Write-Host "[lynx-android] OK ANDROID_SDK_ROOT=$SdkRoot"
  if ($env:ANDROID_NDK_HOME) { Write-Host "[lynx-android] OK ANDROID_NDK_HOME=$($env:ANDROID_NDK_HOME)" }
}
