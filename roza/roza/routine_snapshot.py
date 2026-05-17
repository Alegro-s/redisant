"""Краткий снимок для режима агента: корень проекта и git status.

Корень: родитель ROZA_CONFIG (если задан), иначе текущий каталог процесса Roza.
Запуск: python -m roza.routine_snapshot
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def project_root() -> Path:
    cfg = os.environ.get("ROZA_CONFIG")
    if cfg:
        return Path(cfg).resolve().parent
    return Path.cwd()


def main() -> None:
    root = project_root()
    print(f"root={root}")
    try:
        import datetime

        print(datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z"))
    except Exception:
        pass
    if (root / ".git").exists():
        r = subprocess.run(
            ["git", "-C", str(root), "status", "-sb"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        out = (r.stdout or r.stderr or "").strip()
        print(out if out else "(git empty output)")
        if r.returncode != 0:
            sys.exit(r.returncode)
    else:
        print("(no .git in root, git skipped)")


if __name__ == "__main__":
    main()
