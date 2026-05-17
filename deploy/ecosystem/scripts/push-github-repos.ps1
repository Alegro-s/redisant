param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubUser,
    [Parameter(Mandatory = $true)]
    [string]$Token,
    [string]$ExportDir = "",
    [switch]$Private = $true
)

$ErrorActionPreference = "Stop"
$PO_ROOT = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$OUT = if ($ExportDir) { $ExportDir } else { Join-Path $PO_ROOT "_github_export" }

if (-not (Test-Path $OUT)) {
    & (Join-Path $PSScriptRoot "prepare-github-repos.ps1")
}

$repos = @(
    "waypoint-auth",
    "waypoint-apis",
    "waypoint-club-web",
    "waypoint-metric-web",
    "lynx-hub",
    "lynx-cloud",
    "roza",
    "roza-web"
)

$headers = @{
    Authorization = "Bearer $Token"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

function Ensure-Repo {
    param([string]$Name)
    $uri = "https://api.github.com/repos/$GitHubUser/$Name"
    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -Method Get | Out-Null
        Write-Host "Repo exists: $Name"
    } catch {
        $body = @{
            name        = $Name
            private     = $Private.IsPresent
            auto_init   = $false
            description = "Waypoint ecosystem — $Name"
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json"
        Write-Host "Created: $Name"
    }
}

foreach ($name in $repos) {
    Ensure-Repo -Name $name
    $dir = Join-Path $OUT $name
    if (-not (Test-Path $dir)) { throw "Missing $dir — run prepare-github-repos.ps1" }

    Push-Location $dir
    if (-not (Test-Path ".git")) {
        git init -b main
        git add -A
        git commit -m "Initial import from PO monorepo"
    }
    $remote = "https://${Token}@github.com/${GitHubUser}/${name}.git"
    git remote remove origin 2>$null
    git remote add origin $remote
    git push -u origin main --force
    Pop-Location
    Write-Host "Pushed: $name"
}

Write-Host "All repositories pushed to https://github.com/$GitHubUser/"
