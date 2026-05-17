from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass
class ComponentInfo:
    cid: str
    title: str
    actions: frozenset[str]


def load_components(path: Path | None) -> dict[str, dict[str, Any]]:
    if path is None or not path.is_file():
        return {}
    with path.open(encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}
    comps = raw.get("components") or {}
    if not isinstance(comps, dict):
        return {}
    return comps


def list_components(registry: dict[str, dict[str, Any]]) -> list[ComponentInfo]:
    out: list[ComponentInfo] = []
    for cid, spec in registry.items():
        if not isinstance(spec, dict):
            continue
        title = str(spec.get("title") or cid)
        actions = spec.get("actions") or {}
        if isinstance(actions, dict):
            out.append(
                ComponentInfo(
                    cid=str(cid),
                    title=title,
                    actions=frozenset(str(k) for k in actions.keys()),
                )
            )
    return sorted(out, key=lambda x: x.cid)


def run_action(
    registry: dict[str, dict[str, Any]],
    component_id: str,
    action: str,
    *,
    timeout_sec: float = 120.0,
) -> str:
    spec = registry.get(component_id)
    if spec is None:
        return f"Ошибка: компонент «{component_id}» не найден в components.yaml."
    actions = spec.get("actions") or {}
    if action not in actions:
        known = ", ".join(sorted(str(k) for k in actions.keys())) or "(нет)"
        return f"Ошибка: действие «{action}» недоступно. Доступно: {known}."
    entry = actions[action]
    if not isinstance(entry, dict):
        return "Ошибка: неверная запись действия в YAML."
    cmd = entry.get("command")
    if not isinstance(cmd, list) or not all(isinstance(x, str) for x in cmd):
        return "Ошибка: для действия нужен command: [строка, ...]."
    cwd = entry.get("cwd")
    cwd_path = None
    if cwd is not None:
        cwd_path = Path(cwd)
        if not cwd_path.is_absolute():
            return "Ошибка: cwd в компоненте должен быть абсолютным путём (безопасность)."
    try:
        proc = subprocess.run(
            cmd,
            cwd=cwd_path,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
            shell=False,
        )
    except subprocess.TimeoutExpired:
        return f"Таймаут ({timeout_sec}s) при выполнении: {' '.join(cmd)}"
    except OSError as e:
        return f"Ошибка запуска: {e}"
    parts: list[str] = []
    if proc.stdout:
        parts.append(proc.stdout.strip())
    if proc.stderr:
        parts.append("[stderr]\n" + proc.stderr.strip())
    if proc.returncode != 0:
        parts.append(f"[код выхода {proc.returncode}]")
    return "\n".join(parts) if parts else "(пустой вывод)"
