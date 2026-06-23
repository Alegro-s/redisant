# Wave 14a: 3D physics (AABB + rigid body).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== generate wave14 demo assets =="
python (Join-Path $Root "scripts\generate_wave14_3d_assets.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== lynx-core physics3d tests =="
Push-Location lynx-core
cargo test physics3d:: --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
cargo test scene3d::tests::parse_physics --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
cargo test cull3d --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
cargo test forward3d::tests::frustum --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== engine tests =="
Push-Location engine
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== Q3 regression chain =="
& "$PSScriptRoot/run-q3-regression.ps1"
exit $LASTEXITCODE
