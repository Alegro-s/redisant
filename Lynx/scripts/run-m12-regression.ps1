# Wave 12a: PBR texture contract + albedo CPU tint in forward3d.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== compile forward3d shaders (Windows) =="
if (Test-Path "$Root/lynx-core/scripts/compile-shaders.ps1") {
  & "$Root/lynx-core/scripts/compile-shaders.ps1"
}

Write-Host "== lynx-core (scene3d + forward3d + texture) =="
Push-Location lynx-core
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "== engine tests =="
Push-Location engine
cargo test --quiet
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
Pop-Location

Write-Host "M12a regression OK"
