# Экспорт монорепо PO в каталоги для отдельных GitHub-репозиториев (Windows)
$ErrorActionPreference = "Stop"
$PO_ROOT = if ($env:PO_ROOT) { $env:PO_ROOT } else { (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path }
$OUT = if ($env:OUT) { $env:OUT } else { Join-Path $PO_ROOT "_github_export" }

function Copy-Tree {
    param([string]$Src, [string]$Dst)
    $exclude = @("node_modules", "target", "dist", ".next", ".git")
    New-Item -ItemType Directory -Force -Path $Dst | Out-Null
    robocopy $Src $Dst /E /XD $exclude /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed $Src -> $Dst" }
}

if (Test-Path $OUT) { Remove-Item -Recurse -Force $OUT }
New-Item -ItemType Directory -Force -Path $OUT | Out-Null

Write-Host "PO_ROOT=$PO_ROOT"
Write-Host "OUT=$OUT"

# waypoint-auth
$auth = Join-Path $OUT "waypoint-auth"
New-Item -ItemType Directory -Force -Path (Join-Path $auth "platform") | Out-Null
Copy-Tree (Join-Path $PO_ROOT "platform\server") (Join-Path $auth "platform\server")
Copy-Item (Join-Path $PO_ROOT "deploy\ecosystem\docker-compose.auth.yml") (Join-Path $auth "docker-compose.yml")
New-Item -ItemType Directory -Force -Path (Join-Path $auth "scripts") | Out-Null
Copy-Item (Join-Path $PO_ROOT "deploy\ecosystem\scripts\email-webhook-smtp.py") (Join-Path $auth "scripts\email-webhook-smtp.py")
(Get-Content (Join-Path $auth "docker-compose.yml") -Raw) -replace '\.\./\.\./platform/server', './platform/server' | Set-Content (Join-Path $auth "docker-compose.yml")

# waypoint-apis
$apis = Join-Path $OUT "waypoint-apis"
New-Item -ItemType Directory -Force -Path (Join-Path $apis "platform") | Out-Null
Copy-Tree (Join-Path $PO_ROOT "platform\server") (Join-Path $apis "platform\server")
Copy-Item (Join-Path $PO_ROOT "deploy\ecosystem\docker-compose.apis.yml") (Join-Path $apis "docker-compose.yml")
(Get-Content (Join-Path $apis "docker-compose.yml") -Raw) -replace '\.\./\.\./platform/server', './platform/server' | Set-Content (Join-Path $apis "docker-compose.yml")

Copy-Tree (Join-Path $PO_ROOT "Waypoint\web") (Join-Path $OUT "waypoint-club-web")
"VITE_PUBLIC_SITE_MODE=club" | Set-Content (Join-Path $OUT "waypoint-club-web\.env.production") -Encoding utf8

Copy-Tree (Join-Path $PO_ROOT "Waypoint\web") (Join-Path $OUT "waypoint-metric-web")
"VITE_PUBLIC_SITE_MODE=metric" | Set-Content (Join-Path $OUT "waypoint-metric-web\.env.production") -Encoding utf8

Copy-Tree (Join-Path $PO_ROOT "Lynx\hub") (Join-Path $OUT "lynx-hub")
Copy-Tree (Join-Path $PO_ROOT "Lynx\cloud") (Join-Path $OUT "lynx-cloud")
Copy-Tree (Join-Path $PO_ROOT "roza") (Join-Path $OUT "roza")
Copy-Tree (Join-Path $PO_ROOT "roza\web") (Join-Path $OUT "roza-web")

# .gitignore шаблон
$gitignore = @"
node_modules/
dist/
.next/
target/
.env
.env.local
*.log
"@
foreach ($d in Get-ChildItem $OUT -Directory) {
    $gitignore | Set-Content (Join-Path $d.FullName ".gitignore") -Encoding utf8
}

Write-Host "Export ready: $OUT"
Write-Host "Next: push-github-repos.ps1 -GitHubUser YOUR_USER -Token ghp_xxx"
