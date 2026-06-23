# Compile HLSL -> CSO for lynx-core D3D12 (requires Windows SDK dxc.exe).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Hlsl = Join-Path $Root "shaders\forward3d.hlsl"
$Out = Join-Path $Root "assets\shaders"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$dxc = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter dxc.exe -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' } |
  Sort-Object FullName -Descending |
  Select-Object -First 1 -ExpandProperty FullName

if (-not $dxc) { throw "dxc.exe not found (install Windows SDK)" }

function Compile-One($profile, $entry, $outName) {
  $outPath = Join-Path $Out $outName
  Write-Host "dxc $entry -> $outName"
  & $dxc -T $profile -E $entry -Fo $outPath $Hlsl
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Compile-One "vs_6_0" "VSMain" "forward3d_vs.cso"
Compile-One "ps_6_0" "PSMain" "forward3d_ps.cso"
Compile-One "vs_6_0" "VSShadow" "forward3d_shadow_vs.cso"
Compile-One "ps_6_0" "PSShadow" "forward3d_shadow_ps.cso"
Write-Host "OK: $Out"
