# Wave 12c: shadow PCF + cascade + full M12 chain.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (Test-Path "$Root/lynx-core/scripts/compile-shaders.ps1") {
  & "$Root/lynx-core/scripts/compile-shaders.ps1"
}

Write-Host "== lynx-core tests (shadow cascades) =="
Push-Location lynx-core
cargo test forward3d:: --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== M12 regression =="
& "$PSScriptRoot/run-m12-regression.ps1"
exit $LASTEXITCODE
