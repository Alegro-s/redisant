Param(
    [string]$LocalDir = "",
    [string]$Bucket = "bc39a46d-ee3d-4707-9e3f-9529afb602da",
    [string]$Endpoint = "https://s3.twcstorage.ru",
    [string]$Prefix = "lynx/",
    [string]$SecretsFile = "",
    [switch]$AlsoWaypointDesktop,
    [switch]$DesktopOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$wpDir = Join-Path $RepoRoot "releases\waypoint-desktop"
$wpPrefix = "project's/waypointdesktop/"

if ($DesktopOnly) {
    $AlsoWaypointDesktop = $true
}
if (-not $LocalDir) {
    $LocalDir = Join-Path $RepoRoot "releases\lynx-public"
}
$skipLynx = $DesktopOnly -or -not (Test-Path $LocalDir)
if ($skipLynx -and -not $AlsoWaypointDesktop) {
    throw "Missing folder: $LocalDir. Run build-lynx-releases.ps1 or use -DesktopOnly after pack-waypoint-desktop.ps1"
}
if ($skipLynx -and $AlsoWaypointDesktop -and -not (Test-Path $wpDir)) {
    throw "Missing $wpDir. Run pack-waypoint-desktop.ps1 first"
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
    throw "Missing S3 keys in $SecretsFile (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Install AWS CLI: winget install Amazon.AWSCLI"
    throw "aws not found in PATH"
}

$env:AWS_DEFAULT_REGION = "ru-1"
$s3dest = "s3://${Bucket}/${Prefix}"

if (-not $skipLynx) {
    Write-Host "[s3] Upload $LocalDir -> $s3dest"
    aws s3 sync $LocalDir $s3dest --endpoint-url $Endpoint
} else {
    Write-Host "[s3] Skip Lynx (no $LocalDir)"
}

if ($AlsoWaypointDesktop) {
    if (Test-Path $wpDir) {
        $wpDest = "s3://${Bucket}/${wpPrefix}"
        Write-Host "[s3] Waypoint Desktop -> $wpDest"
        aws s3 sync $wpDir $wpDest --endpoint-url $Endpoint
        Write-Host "  MSI: $Endpoint/${Bucket}/${wpPrefix}WaypointDesktop-setup.msi"
    } else {
        Write-Host "[s3] Skip waypoint-desktop (run pack-waypoint-desktop.ps1 first)"
    }
}

Write-Host ""
Write-Host "Public URLs (if bucket is public):"
if (-not $skipLynx) {
    Get-ChildItem $LocalDir -File | ForEach-Object {
        $key = "$Prefix$($_.Name)"
        Write-Host "  $Endpoint/${Bucket}/${key}"
    }
}
if ($AlsoWaypointDesktop -and (Test-Path $wpDir)) {
    Get-ChildItem $wpDir -File | ForEach-Object {
        Write-Host "  $Endpoint/${Bucket}/${wpPrefix}$($_.Name)"
    }
}
Write-Host ""
Write-Host "Server: copy s3.secrets to /opt/waypoint/s3.secrets, then bash /root/deploy-all.sh"
