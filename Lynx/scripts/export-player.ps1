# Экспорт проекта для Lynx Player (волна 3).
param(
  [string]$Project = "projects/platformer-wave2",
  [ValidateSet("windows", "web", "android", "data", "all")]
  [string]$Preset = "all",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$projPath = (Resolve-Path (Join-Path $Root $Project)).Path

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path (Join-Path $Root "dist") (Split-Path $projPath -Leaf)
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$engineDll = Join-Path $Root "engine/target/release/engine.dll"
$engineArg = @()
if (Test-Path $engineDll) { $engineArg = @($engineDll) }

function Export-One($name) {
  Write-Host "== Export $name -> $OutDir =="
  Push-Location (Join-Path $Root "client")
  dart run bin/lynx_export.dart $projPath $OutDir $name @engineArg
  if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }
  Pop-Location
}

if ($Preset -eq "all") {
  foreach ($p in @("windows", "web", "android", "data")) {
    Export-One $p
  }
} else {
  Export-One $Preset
}

Write-Host "Done: $OutDir"
