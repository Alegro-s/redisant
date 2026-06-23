# ChairUp — подготовка окружения Android на Windows
$ErrorActionPreference = "Stop"
$phone = Join-Path $PSScriptRoot "..\apps\phone-android"
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = "$env:LOCALAPPDATA\Android\Sdk" }
if (-not (Test-Path $sdk)) {
    Write-Error "Android SDK not found at $sdk. Install Android Studio."
}
$escaped = $sdk -replace '\\', '/'
Set-Content -Path (Join-Path $phone "local.properties") -Value "sdk.dir=$escaped`n" -Encoding utf8
Write-Host "OK local.properties -> $sdk"
$jbr = "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
if (Test-Path $jbr) {
    Write-Host "Use JDK: $jbr"
    Write-Host "`$env:JAVA_HOME = `"$jbr`""
} else {
    Write-Host "WARN: Install JDK 17-21 or Android Studio JBR"
}
Write-Host "Build: cd apps\phone-android; .\gradlew.bat :app:assembleDebug"
