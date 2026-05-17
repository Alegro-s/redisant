"""Запуск нативного клиента «Розен» (Avalonia RozaCompanion), без pywebview / roza desktop."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def _find_companion_csproj() -> Path | None:
    """Ищет companion/RozaCompanion/RozaCompanion.csproj от каталога пакета и от cwd."""
    pkg = Path(__file__).resolve().parent
    for anchor in (pkg, *pkg.parents):
        p = anchor / "companion" / "RozaCompanion" / "RozaCompanion.csproj"
        if p.is_file():
            return p.resolve()
    cwd = Path.cwd().resolve()
    for anchor in (cwd, *cwd.parents):
        p = anchor / "companion" / "RozaCompanion" / "RozaCompanion.csproj"
        if p.is_file():
            return p.resolve()
    return None


def _built_exe(csproj: Path) -> Path | None:
    base = csproj.parent
    for cfg in ("Release", "Debug"):
        exe = base / "bin" / cfg / "net8.0" / "RozaCompanion.exe"
        if exe.is_file():
            return exe.resolve()
    return None


def run_companion() -> int:
    csproj = _find_companion_csproj()
    if csproj is None:
        print(
            "Не найден companion/RozaCompanion/RozaCompanion.csproj.\n"
            "Запускайте из корня клона репозитория Roza (где лежит папка companion).",
            file=sys.stderr,
        )
        return 1

    work = csproj.parent
    exe = _built_exe(csproj)
    if exe is not None:
        print(f"Розен: {exe}", flush=True)
        subprocess.Popen(
            [str(exe)],
            cwd=str(work),
            close_fds=os.name != "nt",
        )
        return 0

    print("Сборка Розен (dotnet build -c Release)…", flush=True)
    r = subprocess.run(
        ["dotnet", "build", str(csproj), "-c", "Release"],
        cwd=str(work),
    )
    if r.returncode != 0:
        print("Сборка не удалась. Нужен .NET SDK: https://dotnet.microsoft.com/download", file=sys.stderr)
        return r.returncode

    exe = _built_exe(csproj)
    if exe is not None:
        print(f"Розен: {exe}", flush=True)
        subprocess.Popen(
            [str(exe)],
            cwd=str(work),
            close_fds=os.name != "nt",
        )
        return 0

    print("Запуск через dotnet run…", flush=True)
    return subprocess.run(
        ["dotnet", "run", "--project", str(csproj), "-c", "Release"],
        cwd=str(work),
    ).returncode
