# Push entire D:\PO to https://github.com/Alegro-s/redik
param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$RepoRoot = "d:\PO"
)

$ErrorActionPreference = "Stop"
if (-not $Token) {
    Write-Host "Set GITHUB_TOKEN or pass -Token ghp_xxx"
    exit 1
}

Set-Location $RepoRoot
if (-not (Test-Path ".git")) {
    git init -b main
} else {
    git branch -M main 2>$null
}
if (-not (Test-Path ".gitignore")) {
    Write-Host "Missing .gitignore in $RepoRoot — create it first (see deploy/ecosystem)."
    exit 1
}
# Clean broken index after failed `git add`
git reset -q 2>$null
if (Test-Path ".git\index.lock") { Remove-Item -Force ".git\index.lock" }
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    git commit -m "Waypoint ecosystem monorepo"
}
$remote = "https://${Token}@github.com/Alegro-s/redik.git"
git remote remove origin 2>$null
git remote add origin $remote
git push -u origin main --force
Write-Host "Pushed to https://github.com/Alegro-s/redik"
