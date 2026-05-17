# Portable Roza build into OneDrive (or -Dest).
# Run:  powershell -ExecutionPolicy Bypass -File .\scripts\build_portable_onedrive.ps1
# Needs: Python 3.10+ in PATH. Ollama is separate on the PC.

param(
    [string]$Source = "",
    [string]$Dest = "C:\Users\igor-\OneDrive\Roza",
    [switch]$AlsoDesktopShortcut = $false
)

$ErrorActionPreference = "Stop"
$env:PIP_DEFAULT_TIMEOUT = "300"

if (-not $Source) {
    $Source = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if (-not (Test-Path (Join-Path $Source "pyproject.toml"))) {
    Write-Error "pyproject.toml not found. Set -Source to Roza repo root."
}

Write-Host "Source: $Source"
Write-Host "Dest:   $Dest"

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

robocopy $Source $Dest /E /XD .venv __pycache__ .git roza_assistant.egg-info node_modules _test_shortcut | Out-Null
if ($LASTEXITCODE -gt 8) {
    Write-Error "robocopy failed exit code $LASTEXITCODE"
}

Push-Location $Dest

try {
    if (-not (Test-Path ".venv\Scripts\python.exe")) {
        Write-Host "Creating venv..."
        python -m venv .venv
    }
    Write-Host "pip install (non-editable portable)..."
    $py = Resolve-Path ".venv\Scripts\python.exe"
    & $py -m pip install --upgrade pip setuptools wheel
    # без -e: код в site-packages, папку можно переносить вместе с .venv
    & $py -m pip install ".[desktop]"

    Write-Host "Icon..."
    & $py -m pip install pillow -q
    & $py scripts\generate_roza_icon.py

    Write-Host "Shortcuts..."
    & $py -m roza shortcut --portable-bundle .

    Copy-Item -Force (Join-Path $Source "packaging\MOBILE_ANDROID_RU.txt") `
        -Destination (Join-Path $Dest "MOBILE_ANDROID_RU.txt") -ErrorAction SilentlyContinue

    $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
    $readme = @(
        "Roza - переносная сборка",
        "========================",
        "Запуск без чёрного окна: Roza.lnk или Run-Roza-quiet.vbs",
        "С консолью (ошибки): Run-Roza.bat",
        "Нужны: Ollama на ПК, модель из config.yaml (ollama pull ...)",
        "После обновления файлов проекта: .venv\Scripts\python.exe -m pip install .[desktop]",
        "",
        "Папка: $Dest",
        "Сборка: $dt",
        "",
        "Про APK и модель на телефоне: см. MOBILE_ANDROID_RU.txt"
    ) -join [Environment]::NewLine
    Set-Content -Path (Join-Path $Dest "README_PORTABLE_RU.txt") -Value $readme -Encoding UTF8

    if ($AlsoDesktopShortcut) {
        $desk = [Environment]::GetFolderPath("Desktop")
        if ($desk -and (Test-Path (Join-Path $Dest "Roza.lnk"))) {
            Copy-Item -Force (Join-Path $Dest "Roza.lnk") (Join-Path $desk "Roza.lnk")
            Write-Host "Copied Roza.lnk to Desktop"
        }
    }

    Write-Host ""
    Write-Host "OK build folder: $Dest"
    Write-Host "Run: Run-Roza.bat or Roza.lnk"
}
finally {
    Pop-Location
}
