from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from roza.config import Settings


def bundled_icon_path() -> Path | None:
    p = Path(__file__).resolve().parent / "assets" / "roza.ico"
    return p if p.is_file() else None


def _user_desktop() -> Path:
    home = Path.home()
    for rel in ("Desktop", "OneDrive/Desktop", "OneDrive/Рабочий стол"):
        p = home / rel
        if p.is_dir():
            return p
    return home / "Desktop"


def _ps_single(s: str) -> str:
    return s.replace("'", "''")


def create_windows_lnk(
    lnk_path: Path,
    target_path: Path,
    arguments: str,
    working_dir: Path,
    icon_path: Path | None,
    description: str,
) -> None:
    """Ярлык Windows (.lnk) через PowerShell (без pywin32)."""
    lnk_path = lnk_path.resolve()
    target_path = target_path.resolve()
    working_dir = working_dir.resolve()
    if icon_path is not None and icon_path.is_file():
        icon_loc = f"{_ps_single(str(icon_path.resolve()))},0"
    else:
        icon_loc = f"{_ps_single(str(target_path))},0"

    lines = [
        "$ErrorActionPreference = 'Stop'",
        "$ws = New-Object -ComObject WScript.Shell",
        f"$s = $ws.CreateShortcut('{_ps_single(str(lnk_path))}')",
        f"$s.TargetPath = '{_ps_single(str(target_path))}'",
        f"$s.Arguments = '{_ps_single(arguments)}'",
        f"$s.WorkingDirectory = '{_ps_single(str(working_dir))}'",
        f"$s.IconLocation = '{icon_loc}'",
        f"$s.Description = '{_ps_single(description)}'",
        "$s.Save()",
    ]
    text = "\r\n".join(lines) + "\r\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".ps1",
        delete=False,
        encoding="utf-8-sig",
    ) as f:
        f.write(text)
        ps1 = Path(f.name)
    try:
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(ps1),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    finally:
        ps1.unlink(missing_ok=True)


def _pythonw_exe(python_exe: Path) -> Path:
    """На Windows рядом с python.exe лежит pythonw.exe — без консоли."""
    p = python_exe.resolve()
    w = p.parent / "pythonw.exe"
    return w if w.is_file() else p


def _desktop_cli_args(config_path: Path | None) -> str:
    if config_path is not None:
        cfg = str(config_path.resolve())
        return f'-m roza -c "{cfg}" desktop'
    return "-m roza desktop"


def write_launch_bat(
    bat_path: Path,
    *,
    work_dir: Path,
    python_exe: Path,
    config_path: Path | None,
) -> None:
    """Запуск с консолью (если ошибка — pause). Для тихого старта используйте ярлык на pythonw."""
    work_dir = work_dir.resolve()
    py = python_exe.resolve()
    if config_path is not None:
        cfg = str(config_path.resolve())
        cmd = f'"{py}" -m roza -c "{cfg}" desktop'
    else:
        cmd = f'"{py}" -m roza desktop'
    lines = [
        "@echo off",
        "chcp 65001 >nul",
        f'cd /d "{work_dir}"',
        cmd,
        "if errorlevel 1 pause",
    ]
    bat_path.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")


def write_companion_launch_bat(bat_path: Path, *, work_dir: Path) -> None:
    """Двойной щелчок — только Avalonia Roza Companion (без python -m roza desktop)."""
    work_dir = work_dir.resolve()
    root = str(work_dir).rstrip("\\/")
    exe = f"{root}\\companion\\RozaCompanion\\bin\\Release\\net8.0\\RozaCompanion.exe"
    exed = f"{root}\\companion\\RozaCompanion\\bin\\Debug\\net8.0\\RozaCompanion.exe"
    csproj = f"{root}\\companion\\RozaCompanion\\RozaCompanion.csproj"
    lines = [
        "@echo off",
        "chcp 65001 >nul",
        f'cd /d "{work_dir}"',
        f'if exist "{exe}" start "" "{exe}" & exit /b 0',
        f'if exist "{exed}" start "" "{exed}" & exit /b 0',
        "where dotnet >nul 2>&1",
        "if errorlevel 1 (",
        '  echo Установите .NET SDK: https://dotnet.microsoft.com/download',
        "  pause",
        "  exit /b 1",
        ")",
        f'dotnet build "{csproj}" -c Release',
        f'if exist "{exe}" start "" "{exe}" & exit /b 0',
        f'if exist "{exed}" start "" "{exed}" & exit /b 0',
        f'dotnet run --project "{csproj}" -c Release',
        "if errorlevel 1 pause",
    ]
    bat_path.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")


def _vbs_escape(s: str) -> str:
    return s.replace('"', '""')


def write_hidden_vbs_launcher(
    vbs_path: Path,
    *,
    work_dir: Path,
    pythonw_exe: Path,
    config_path: Path | None,
) -> None:
    """Двойной щелчок по .vbs — без окна cmd (только Windows)."""
    root = _vbs_escape(str(work_dir.resolve()))
    pyw = _vbs_escape(str(pythonw_exe.resolve()))
    if config_path is None:
        run = 'sh.Run Chr(34) & pyw & Chr(34) & " -m roza desktop", 0, False'
    else:
        cfg = _vbs_escape(str(config_path.resolve()))
        run = (
            f'cfg = "{cfg}"\r\n'
            'sh.Run Chr(34) & pyw & Chr(34) & " -m roza -c " & Chr(34) & cfg & Chr(34) & " desktop", 0, False'
        )
    text = (
        'Set sh = CreateObject("WScript.Shell")\r\n'
        f'pyw = "{pyw}"\r\n'
        f'root = "{root}"\r\n'
        "sh.CurrentDirectory = root\r\n"
        f"{run}\r\n"
    )
    vbs_path.write_text(text, encoding="utf-8")


def install_desktop_launcher(
    settings: Settings,
    config_path: Path | None,
    *,
    output_dir: Path | None = None,
) -> tuple[Path, Path, Path | None, Path]:
    """
    Roza.bat — Python desktop; Roza-Companion.bat — только Avalonia с иконкой розы;
    Roza.lnk — pythonw desktop; Roza-quiet.vbs — то же для .vbs.
    """
    out = output_dir.resolve() if output_dir is not None else _user_desktop()
    out.mkdir(parents=True, exist_ok=True)

    work = settings.config_dir.resolve()
    exe = Path(sys.executable).resolve()
    pyw = _pythonw_exe(exe)
    bat = out / "Roza.bat"
    write_launch_bat(bat, work_dir=work, python_exe=exe, config_path=config_path)

    comp_bat = out / "Roza-Companion.bat"
    write_companion_launch_bat(comp_bat, work_dir=work)

    vbs = out / "Roza-quiet.vbs"
    write_hidden_vbs_launcher(
        vbs, work_dir=work, pythonw_exe=pyw, config_path=config_path
    )

    lnk_path: Path | None = out / "Roza.lnk"
    icon = bundled_icon_path()
    try:
        create_windows_lnk(
            lnk_path,
            target_path=pyw,
            arguments=_desktop_cli_args(config_path),
            working_dir=work,
            icon_path=icon,
            description="Roza — локальный ассистент",
        )
    except (OSError, subprocess.CalledProcessError):
        lnk_path = None

    return bat, comp_bat, lnk_path, vbs


def install_portable_shortcuts(bundle_root: Path) -> tuple[Path, Path | None]:
    """
    Переносная сборка: Run-Roza.bat (консоль), Run-Roza-quiet.vbs, Roza.lnk (pythonw, без терминала).
    """
    root = bundle_root.resolve()
    py = root / ".venv" / "Scripts" / "python.exe"
    pyw = root / ".venv" / "Scripts" / "pythonw.exe"
    if not py.is_file():
        raise FileNotFoundError(
            f"Не найден интерпретатор: {py}. Сначала: scripts\\build_portable_onedrive.ps1"
        )
    if not pyw.is_file():
        pyw = py

    bat = root / "Run-Roza.bat"
    lines = [
        "@echo off",
        "chcp 65001 >nul",
        'set "ROOT=%~dp0"',
        'cd /d "%ROOT%"',
        'if not exist "%ROOT%.venv\\Scripts\\python.exe" (',
        '  echo Нет .venv. Запустите scripts\\build_portable_onedrive.ps1',
        "  pause",
        "  exit /b 1",
        ")",
        '"%ROOT%.venv\\Scripts\\python.exe" -m roza desktop',
        "if errorlevel 1 pause",
    ]
    bat.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")

    vbs = root / "Run-Roza-quiet.vbs"
    write_hidden_vbs_launcher(
        vbs,
        work_dir=root,
        pythonw_exe=pyw,
        config_path=None,
    )

    icon_path: Path | None = root / "roza" / "assets" / "roza.ico"
    if not icon_path.is_file():
        icon_path = bundled_icon_path()

    lnk_path: Path | None = root / "Roza.lnk"
    try:
        create_windows_lnk(
            lnk_path,
            target_path=pyw,
            arguments="-m roza desktop",
            working_dir=root,
            icon_path=icon_path,
            description="Roza — локальный ассистент (portable)",
        )
    except (OSError, subprocess.CalledProcessError):
        lnk_path = None

    return bat, lnk_path
