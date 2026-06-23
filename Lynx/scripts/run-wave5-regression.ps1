# Wave 5 — smoke: pack/import, embedded preview data, editor release tests.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "== Pack Tetris .lynxproject =="
$dist = Join-Path $Root "dist\samples"
New-Item -ItemType Directory -Path $dist -Force | Out-Null
Push-Location client
flutter pub get
if ($LASTEXITCODE -ne 0) { Pop-Location; exit $LASTEXITCODE }

Write-Host "== Flutter wave editor release tests =="
flutter test test/wave_editor_release_test.dart test/wave5_editor_test.dart --reporter compact
$w5 = $LASTEXITCODE
Pop-Location
if ($w5 -ne 0) { exit $w5 }

$tetris = Join-Path $Root "projects\tetris-demo"
$outZip = Join-Path $dist "Tetris-Demo.lynxproject"
$tmpZip = Join-Path $dist "Tetris-Demo.zip"
if (Test-Path $outZip) { Remove-Item $outZip -Force }
if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }
Compress-Archive -Path (Join-Path $tetris "*") -DestinationPath $tmpZip -Force
Rename-Item $tmpZip $outZip
Write-Host "OK: $outZip"

Write-Host "run-wave5-regression: OK"
exit 0
