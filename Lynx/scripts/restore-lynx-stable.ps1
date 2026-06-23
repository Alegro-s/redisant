# Restore Lynx from backup-lynx-stable.ps1 archive (overwrites matching paths).
param(
    [Parameter(Mandatory = $true)][string]$BackupZip,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $BackupZip)) {
    Write-Error "Backup not found: $BackupZip"
}

$temp = Join-Path ([IO.Path]::GetTempPath()) "lynx_restore_$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    Expand-Archive -Path $BackupZip -DestinationPath $temp -Force
    $manifestPath = Join-Path $temp 'backup_manifest.json'
    if (Test-Path $manifestPath) {
        $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Host "Restoring backup label=$($m.label) git=$($m.gitHash) from $($m.createdAt)"
    }

    Get-ChildItem $temp -Recurse -File | Where-Object { $_.Name -ne 'backup_manifest.json' } | ForEach-Object {
        $rel = $_.FullName.Substring($temp.Length).TrimStart('\', '/')
        $target = Join-Path $Root $rel
        if ($WhatIf) {
            Write-Host "[whatif] $target"
            return
        }
        $dir = Split-Path $target -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item $_.FullName $target -Force
        Write-Host "  restored $rel"
    }
} finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}

Write-Host ''
Write-Host "OK: restored from $BackupZip"
