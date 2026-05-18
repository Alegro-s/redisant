Param(
    [string]$LocalDir = "",
    [string]$Bucket = "bc39a46d-ee3d-4707-9e3f-9529afb602da",
    [string]$Endpoint = "https://s3.twcstorage.ru",
    [string]$Prefix = "lynx/",
    [string]$SecretsFile = "",
    [switch]$AlsoWaypointDesktop
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

if (-not $LocalDir) {
    $LocalDir = Join-Path $RepoRoot "releases\lynx-public"
}
if (-not (Test-Path $LocalDir)) {
    throw "Нет папки: $LocalDir. Сначала: .\deploy\ecosystem\scripts\build-lynx-releases.ps1"
}

if (-not $SecretsFile) {
    $SecretsFile = Join-Path $RepoRoot "deploy\ecosystem\s3.secrets"
}
if (Test-Path $SecretsFile) {
    Get-Content $SecretsFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $k = $Matches[1].Trim()
            $v = $Matches[2].Trim().Trim('"')
            Set-Item -Path "env:$k" -Value $v
        }
    }
}

if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
    throw @"
Нет ключей S3. Создайте файл:
  $SecretsFile

Содержимое:
  AWS_ACCESS_KEY_ID=ключ_из_панели_Timeweb
  AWS_SECRET_ACCESS_KEY=секрет_из_панели_Timeweb
"@
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Установите AWS CLI: winget install Amazon.AWSCLI"
    throw "aws не найден в PATH"
}

$env:AWS_DEFAULT_REGION = "ru-1"
$s3dest = "s3://${Bucket}/${Prefix}"

Write-Host "[s3] Загрузка $LocalDir -> $s3dest"
aws s3 sync $LocalDir $s3dest --endpoint-url $Endpoint

if ($AlsoWaypointDesktop) {
    $wpDir = Join-Path $RepoRoot "releases\waypoint-desktop"
    $wpPrefix = "project's/waypointdesktop/"
    if (Test-Path $wpDir) {
        $wpDest = "s3://${Bucket}/${wpPrefix}"
        Write-Host "[s3] Waypoint Desktop -> $wpDest"
        aws s3 sync $wpDir $wpDest --endpoint-url $Endpoint
        Write-Host "  URL: $Endpoint/${Bucket}/${wpPrefix}WaypointDesktop-setup.msi"
    } else {
        Write-Host "[s3] Skip waypoint-desktop (run pack-waypoint-desktop.ps1 first)"
    }
}

Write-Host ""
Write-Host "Публичные URL (если бакет публичный):"
Get-ChildItem $LocalDir -File | ForEach-Object {
    $key = "$Prefix$($_.Name)"
    Write-Host "  $Endpoint/${Bucket}/${key}"
}
Write-Host ""
Write-Host "На сервере Hub подхватит файлы из /srv/lynx-hub/dist/downloads/ после deploy-all.sh"
