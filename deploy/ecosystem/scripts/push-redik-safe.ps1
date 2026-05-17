param(
    [string]$RepoRoot = "D:\PO",
    [string]$Message = "",
    [string]$Token = $env:GITHUB_TOKEN,
    [switch]$Force,
    [switch]$DryRun,
    [int]$MaxBytes = 100MB
)

$ErrorActionPreference = "Stop"
Set-Location $RepoRoot

function Write-Step([string]$Text) { Write-Host "[push-redik] $Text" -ForegroundColor Cyan }

if (-not (Test-Path ".git")) {
    Write-Step "git init"
    git init -b main
}

if (-not (Test-Path ".gitignore")) {
    throw "Нет .gitignore в $RepoRoot — добавьте правила (releases/, bin/, *.pdb …)."
}

if (Test-Path ".git\index.lock") { Remove-Item -Force ".git\index.lock" }

git branch -M main 2>$null | Out-Null

Write-Step "git add (по .gitignore)"
git add -A

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Step "Нет изменений для коммита."
} else {
    $tooBig = @()
    foreach ($rel in $staged) {
        $full = Join-Path $RepoRoot $rel
        if ((Test-Path $full -PathType Leaf)) {
            $len = (Get-Item $full).Length
            if ($len -ge $MaxBytes) {
                $tooBig += [PSCustomObject]@{ Path = $rel; MB = [math]::Round($len / 1MB, 2) }
            }
        }
    }
    if ($tooBig.Count -gt 0) {
        Write-Host ""
        Write-Host "ОТКАЗ: файлы >= $([int]($MaxBytes/1MB)) МБ (лимит GitHub):" -ForegroundColor Red
        $tooBig | Format-Table -AutoSize
        Write-Host "Уберите из индекса: git reset HEAD -- <path>"
        Write-Host "Добавьте путь в .gitignore. Если файл уже в старых коммитах — git filter-repo."
        exit 1
    }

    if (-not $Message) {
        $Message = "Waypoint + Lynx monorepo ($(Get-Date -Format 'yyyy-MM-dd'))"
    }

    if ($DryRun) {
        Write-Step "DryRun: коммит не создан. staged: $($staged.Count) файлов."
        exit 0
    }

    git commit -m $Message
    Write-Step "commit: $Message"
}

if (-not $Token) {
    Write-Step "Без GITHUB_TOKEN — только локальный коммит. Push: git push -u origin main"
    exit 0
}

$remote = "https://${Token}@github.com/Alegro-s/redik.git"
$hasOrigin = git remote 2>$null | Select-String -Pattern "^origin$" -Quiet
if ($hasOrigin) {
    git remote set-url origin $remote
} else {
    git remote add origin $remote
}

$pushArgs = @("push", "-u", "origin", "main")
if ($Force) {
    Write-Host "ВНИМАНИЕ: --force" -ForegroundColor Yellow
    $pushArgs += "--force"
}

if ($DryRun) {
    Write-Step "DryRun: push пропущен."
    exit 0
}

git @pushArgs
Write-Step "Готово: https://github.com/Alegro-s/redik"
