# Roza AI - standalone win-x64 exe for local testing.
# Run: powershell -ExecutionPolicy Bypass -File deploy/ecosystem/scripts/pack-roza-ai-offline.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$Proj = Join-Path $RepoRoot "roza\companion\RozaCompanion\RozaCompanion.csproj"
$OutDir = Join-Path $RepoRoot "releases\roza-ai-offline"

if (-not (Test-Path $Proj)) { throw "RozaCompanion not found: $Proj" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "==> dotnet publish Roza AI (win-x64, self-contained)"
dotnet publish $Proj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $OutDir

$Exe = Get-ChildItem $OutDir -Filter "*.exe" | Select-Object -First 1
if (-not $Exe) { throw "No exe in $OutDir" }

Write-Host "Done: $($Exe.FullName)"
Write-Host "Uses production auth at waypointclub.ru by default."
