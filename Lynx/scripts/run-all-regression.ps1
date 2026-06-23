# Q1: consolidated regression (Lynx Core M1–M6 chain + waves 0–11).
param(
  [ValidateSet("quick", "full")]
  [string]$Tier = "quick"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Invoke-Step($label, $script) {
  Write-Host ""
  Write-Host "== $label =="
  & $script
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Tier -eq "full") {
  Invoke-Step "Wave 0" "$PSScriptRoot/run-wave0-regression.ps1"
  Invoke-Step "Wave 1" "$PSScriptRoot/run-wave1-regression.ps1"
  Invoke-Step "Wave 2" "$PSScriptRoot/run-wave2-regression.ps1"
  Invoke-Step "Wave 3" "$PSScriptRoot/run-wave3-regression.ps1"
  Invoke-Step "Wave 4" "$PSScriptRoot/run-wave4-regression.ps1"
  Invoke-Step "Wave 5" "$PSScriptRoot/run-wave5-regression.ps1"
  Invoke-Step "Wave 6" "$PSScriptRoot/run-wave6-regression.ps1"
  Invoke-Step "Wave 7" "$PSScriptRoot/run-wave7-regression.ps1"
  Invoke-Step "Wave 8" "$PSScriptRoot/run-wave8-regression.ps1"
}

Invoke-Step "Wave 11 (includes 9–10, M5–M6, M4→M1)" "$PSScriptRoot/run-wave11-regression.ps1"

if (Test-Path "$PSScriptRoot/run-m14-regression.ps1") {
  Invoke-Step "Wave 14a (3D physics)" "$PSScriptRoot/run-m14-regression.ps1"
} elseif (Test-Path "$PSScriptRoot/run-q3-regression.ps1") {
  Invoke-Step "Q3 (Windows Core 3D viewport)" "$PSScriptRoot/run-q3-regression.ps1"
} elseif (Test-Path "$PSScriptRoot/run-m13-regression.ps1") {
  Invoke-Step "Wave 13 (skin + terrain)" "$PSScriptRoot/run-m13-regression.ps1"
} elseif (Test-Path "$PSScriptRoot/run-m12c-regression.ps1") {
  Invoke-Step "Wave 12c (shadow PCF)" "$PSScriptRoot/run-m12c-regression.ps1"
} elseif (Test-Path "$PSScriptRoot/run-m12-regression.ps1") {
  Invoke-Step "Wave 12a (textures contract)" "$PSScriptRoot/run-m12-regression.ps1"
}

Write-Host ""
Write-Host "run-all-regression ($Tier): OK"
