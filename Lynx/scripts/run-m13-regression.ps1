# Wave 13a/13b: skinning + terrain (CPU).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== lynx-core tests (13a skin + 13b terrain) =="
Push-Location lynx-core
foreach ($filter in @('glb_skin', 'terrain_mesh', 'parse_terrain', 'forward3d::terrain')) {
    cargo test $filter --quiet
    if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
}
cargo test forward3d:: --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== M12c regression (shader + shadow baseline) =="
& "$PSScriptRoot/run-m12c-regression.ps1"
exit $LASTEXITCODE
