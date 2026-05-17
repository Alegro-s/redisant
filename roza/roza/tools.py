from __future__ import annotations

import json
import re
from typing import Any

from roza.components import load_components, list_components, run_action
from roza.config import Settings
from roza.filesafe import list_dir_formatted, read_text, write_text


def tool_schema_description(settings: Settings) -> str:
    lines = [
        "Инструменты (строго JSON в одной строке после префикса ROZA_TOOL: ):",
        'Формат: ROZA_TOOL: {"tool":"component","id":"<id>","action":"<start|stop|status|...>"}',
        'Файлы проекта (путь относительный к workspace.roots, без ..):',
        '  ROZA_TOOL: {"tool":"list_dir","path":"."}  — содержимое каталога (path по умолчанию ".")',
        '  ROZA_TOOL: {"tool":"read_file","path":"src/main.py"}  — текст файла (большие обрезаются)',
        '  ROZA_TOOL: {"tool":"read_file","path":"README.md","max_chars":50000}',
        '  ROZA_TOOL: {"tool":"write_file","path":"относительный/путь","content":"..."}',
        "Чтобы разобрать проект: list_dir по корню и подпапкам, затем read_file по нужным файлам.",
        "Если инструмент не нужен — отвечай обычным текстом пользователю (без префикса ROZA_TOOL).",
        "Простой разговор, приветствия, вопросы без ПК — только связный ответ по-русски, без ROZA_TOOL.",
    ]
    reg = load_components(settings.components_file)
    if reg:
        lines.append("Зарегистрированные компоненты:")
        for c in list_components(reg):
            acts = ", ".join(sorted(c.actions)) if c.actions else "(нет действий)"
            lines.append(f"  - {c.cid}: {c.title} [{acts}]")
    else:
        lines.append("Компоненты не загружены (нет components.yaml) — tool component недоступен.")
    if settings.workspace_roots:
        roots = ", ".join(str(p) for p in settings.workspace_roots)
        lines.append(f"Разрешённые корни файлов: {roots}")
    else:
        lines.append("Корни файлов не заданы — read_file/write_file недоступны.")
    return "\n".join(lines)


_ROZA_TOOL_RE = re.compile(
    r"^\s*ROZA_TOOL:\s*(\{.*\})\s*$",
    re.DOTALL | re.MULTILINE,
)


def extract_tool_line(text: str) -> dict[str, Any] | None:
    """Ищет ROZA_TOOL: {...} в любом месте ответа (построчно, затем regex)."""
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("ROZA_TOOL:"):
            continue
        rest = line[len("ROZA_TOOL:") :].strip()
        try:
            return json.loads(rest)
        except json.JSONDecodeError:
            continue
    m = _ROZA_TOOL_RE.search(text)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            return None
    return None


def execute_tool(payload: dict[str, Any], settings: Settings) -> str:
    tool = payload.get("tool")
    if tool == "component":
        reg = load_components(settings.components_file)
        if not reg:
            return "Ошибка: components.yaml не найден или пуст."
        cid = str(payload.get("id") or "")
        action = str(payload.get("action") or "")
        return run_action(reg, cid, action)
    if tool == "read_file":
        path = str(payload.get("path") or "")
        raw_mc = payload.get("max_chars")
        try:
            max_c = int(raw_mc) if raw_mc is not None else 120_000
            max_c = max(2_000, min(max_c, 500_000))
        except (TypeError, ValueError):
            max_c = 120_000
        try:
            return read_text(path, settings.workspace_roots, max_chars=max_c)
        except Exception as e:
            return f"Ошибка read_file: {e}"
    if tool == "list_dir":
        p = payload.get("path")
        d = "." if p is None or str(p).strip() == "" else str(p).strip()
        try:
            return list_dir_formatted(d, settings.workspace_roots)
        except Exception as e:
            return f"Ошибка list_dir: {e}"
    if tool == "write_file":
        path = str(payload.get("path") or "")
        content = payload.get("content")
        if content is None:
            return "Ошибка write_file: нужен content."
        try:
            saved = write_text(path, settings.workspace_roots, str(content))
            return f"Записано: {saved}"
        except Exception as e:
            return f"Ошибка write_file: {e}"
    return f"Неизвестный или некорректный tool: {payload!r}"
