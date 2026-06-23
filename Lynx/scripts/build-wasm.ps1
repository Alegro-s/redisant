# E25a — build Lynx Core WASM for web Player/Editor.
param(
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Core = Join-Path $Root 'lynx-core'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Root 'client\web'
}

Write-Host '== Lynx Core WASM (wasm32-unknown-unknown) =='
try { & rustup target add wasm32-unknown-unknown 2>&1 | Out-Null } catch { }

Push-Location $Core
try {
    cargo build --release --target wasm32-unknown-unknown --no-default-features --features serde,pal_wasm
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

$src = Join-Path $Core 'target\wasm32-unknown-unknown\release\lynx_core.wasm'
if (-not (Test-Path $src)) {
    Write-Error "WASM artifact missing: $src"
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
Copy-Item $src (Join-Path $OutDir 'lynx_core.wasm') -Force
Write-Host "OK: $(Join-Path $OutDir 'lynx_core.wasm')"
