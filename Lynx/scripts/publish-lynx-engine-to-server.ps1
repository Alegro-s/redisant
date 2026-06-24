# Build .lynxengine, generate engine-manifest.json, upload to VPS/CDN.
#
# Examples:
#   & "d:\PO\Lynx\scripts\publish-lynx-engine-to-server.ps1" -Version 0.15.0
#   & "d:\PO\Lynx\scripts\publish-lynx-engine-to-server.ps1" -Version 0.15.0 -ServerHost root@72.56.244.26
#   & "d:\PO\Lynx\scripts\publish-lynx-engine-to-server.ps1" -Version 0.15.0 -SkipBuild -ServerHost root@72.56.244.26
#   & "d:\PO\Lynx\scripts\publish-lynx-engine-to-server.ps1" -Version 0.15.0 -FullPack -SkipFlutter
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$ServerHost = '',
    [ValidateSet('windows', 'linux')]
    [string]$Platform = 'windows',
    [ValidateSet('stable', 'beta')]
    [string]$Channel = 'stable',
    [string]$CdnBaseUrl = 'https://lynx-hub.ru/dist/downloads',
    [string]$LynxCoreVersion = '1.0.0',
    [string]$Notes = '',
    [switch]$SkipBuild,
    [switch]$FullPack,
    [switch]$SkipFlutter,
    [switch]$OnlyManifest,
    [string]$AdminApiUrl = 'https://api.lynx-cloud.ru',
    [string]$AdminToken = ''
)

$ErrorActionPreference = 'Stop'
$LynxRoot = Split-Path -Parent $PSScriptRoot
$HubDownloads = Join-Path $LynxRoot 'hub\public\dist\downloads'
$EngineRemoteDir = 'engine'
$DistDir = Join-Path $LynxRoot "dist\lynx_engine_$Version"
$PackName = "lynx-engine-$Version-$Platform.lynxengine"
$PackPath = Join-Path $DistDir "$Platform.lynxengine"
$ManifestPath = Join-Path $HubDownloads 'engine-manifest.json'
$ManifestUrl = "$CdnBaseUrl/engine-manifest.json"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Get-FileSha256Hex([string]$Path) {
    $hash = Get-FileHash -Path $Path -Algorithm SHA256
    return $hash.Hash.ToLowerInvariant()
}

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path $Path)) {
        return @{ releases = @(); recommended_version = $null }
    }
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{ releases = @(); recommended_version = $null }
    }
    return ($raw | ConvertFrom-Json)
}

function Merge-EngineManifest {
    param(
        [string]$Path,
        [string]$Version,
        [string]$Platform,
        [string]$Channel,
        [string]$ArtifactUrl,
        [string]$Sha256,
        [long]$SizeBytes,
        [string]$Notes,
        [switch]$SetRecommended
    )

    $doc = Read-JsonFile $Path
    $releases = @()
    if ($doc.releases) {
        foreach ($r in @($doc.releases)) {
            if ($r.version -ne $Version) { $releases += $r }
        }
    }

    $entry = [ordered]@{
        version   = $Version
        channel   = $Channel
        notes     = if ($Notes) { $Notes } else { "Lynx Engine $Version ($Channel)" }
        sizeBytes = $SizeBytes
        artifacts = [ordered]@{
            $Platform = [ordered]@{
                url    = $ArtifactUrl
                sha256 = $Sha256
            }
        }
    }
    $releases = @($entry) + @($releases)

    $recommended = if ($SetRecommended) { $Version } else { $doc.recommended_version }
    if (-not $recommended) { $recommended = $Version }

    $out = [ordered]@{
        releases            = $releases
        recommended_version = $recommended
        publishedAt         = (Get-Date -Format 'yyyy-MM-dd')
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    ($out | ConvertTo-Json -Depth 8) | Set-Content -Path $Path -Encoding UTF8
    return $out
}

if (-not $SkipBuild -and -not $OnlyManifest) {
    Write-Step "Build Lynx Engine $Version ($Platform)"
    if ($FullPack) {
        $packArgs = @{
            Version         = $Version
            Platform        = $Platform
            LynxCoreVersion = $LynxCoreVersion
        }
        if ($SkipFlutter) { $packArgs.SkipFlutter = $true }
        & (Join-Path $LynxRoot 'scripts\build-lynx-engine-full-pack.ps1') @packArgs
    } else {
        & (Join-Path $LynxRoot 'scripts\publish_lynx_engine_release.ps1') `
            -Version $Version `
            -Platform $Platform `
            -LynxCoreVersion $LynxCoreVersion `
            -CdnBaseUrl $CdnBaseUrl
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $OnlyManifest) {
    if (-not (Test-Path $PackPath)) {
        Write-Error "Pack not found: $PackPath (build first or drop file there)"
    }
}

$sha = ''
$size = 0L
$artifactUrl = "$CdnBaseUrl/$EngineRemoteDir/$PackName"

if (-not $OnlyManifest) {
    Write-Step "SHA256 + manifest"
    $sha = Get-FileSha256Hex $PackPath
    $size = (Get-Item $PackPath).Length

    $hubEngineDir = Join-Path $HubDownloads $EngineRemoteDir
    New-Item -ItemType Directory -Force -Path $hubEngineDir | Out-Null
    Copy-Item $PackPath (Join-Path $hubEngineDir $PackName) -Force
    Write-Host "  Local CDN mirror: hub/public/dist/downloads/$EngineRemoteDir/$PackName"
}

$noteText = if ($Notes) { $Notes } else { "Lynx Engine $Version channel $Channel" }
Merge-EngineManifest `
    -Path $ManifestPath `
    -Version $Version `
    -Platform $Platform `
    -Channel $Channel `
    -ArtifactUrl $artifactUrl `
    -Sha256 $sha `
    -SizeBytes $size `
    -Notes $noteText `
    -SetRecommended:( $Channel -eq 'stable' ) | Out-Null

Write-Host "  Manifest: $ManifestPath"
Write-Host "  Public URL: $ManifestUrl"

if (-not $ServerHost) {
    Write-Host ""
    Write-Host "Done locally." -ForegroundColor Green
    Write-Host "  Deploy: publish-lynx-engine-to-server.ps1 -Version $Version -SkipBuild -ServerHost root@YOUR_VPS"
    exit 0
}

Write-Step "Upload Engine to $ServerHost"
ssh $ServerHost "mkdir -p /srv/lynx-hub/dist/downloads/$EngineRemoteDir"
scp $ManifestPath "${ServerHost}:/srv/lynx-hub/dist/downloads/engine-manifest.json"
Write-Host "  -> downloads/engine-manifest.json"

if (-not $OnlyManifest) {
    $hubPack = Join-Path $HubDownloads "$EngineRemoteDir\$PackName"
    scp $hubPack "${ServerHost}:/srv/lynx-hub/dist/downloads/$EngineRemoteDir/$PackName"
    Write-Host "  -> downloads/$EngineRemoteDir/$PackName"
}

if ($AdminToken) {
    Write-Step "Update API policy ($AdminApiUrl)"
    $body = @{
        manifest_url        = $ManifestUrl
        recommended_version = $Version
    } | ConvertTo-Json
    try {
        Invoke-RestMethod `
            -Method Put `
            -Uri "$AdminApiUrl/admin/engine/policy" `
            -Headers @{ Authorization = "Bearer $AdminToken" } `
            -ContentType 'application/json' `
            -Body $body | Out-Null
        Write-Host "  policy.manifest_url = $ManifestUrl"
    } catch {
        Write-Warning "  Admin API policy update failed: $_"
        Write-Host "  Manual: set manifest URL in Hub Admin -> Engine versions: $ManifestUrl"
    }
} else {
    Write-Host ""
    Write-Host "Tip: set manifest URL in API admin:" -ForegroundColor Yellow
    Write-Host "  PUT $AdminApiUrl/admin/engine/policy"
    Write-Host ('  { "manifest_url": "' + $ManifestUrl + '", "recommended_version": "' + $Version + '" }')
}

Write-Host ""
Write-Host "Done:" -ForegroundColor Green
Write-Host "  CDN manifest: $ManifestUrl"
Write-Host "  API manifest: $AdminApiUrl/engine/manifest"
Write-Host "  Pack:         $artifactUrl"
