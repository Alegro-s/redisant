"""Загрузка учёток из backend/local_users.json."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

_logger = logging.getLogger(__name__)

_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_FILE = _ROOT / "local_users.json"

_cache_mtime: float | None = None
_cache_rows: list[dict[str, Any]] = []


def _normalize_name(value: str) -> str:
    return " ".join(value.strip().split()).casefold()


def local_users_path() -> Path:
    return _DEFAULT_FILE


def load_local_user_entries() -> list[dict[str, Any]]:
    """Читает JSON при каждом изменении файла (по mtime)."""
    global _cache_mtime, _cache_rows
    path = _DEFAULT_FILE
    if not path.is_file():
        if _cache_rows:
            _cache_rows = []
            _cache_mtime = None
        return []

    try:
        mtime = path.stat().st_mtime
    except OSError:
        return _cache_rows

    if _cache_mtime == mtime:
        return _cache_rows

    try:
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)
    except (OSError, json.JSONDecodeError) as e:
        _logger.warning("local_users.json: не удалось прочитать: %s", e)
        return []

    if not isinstance(data, list):
        _logger.warning("local_users.json: ожидается JSON-массив")
        _cache_rows = []
        _cache_mtime = mtime
        return _cache_rows

    _cache_rows = [x for x in data if isinstance(x, dict)]
    _cache_mtime = mtime
    return _cache_rows


def match_local_user(raw_login: str, password: str) -> dict[str, Any] | None:
    """
    Возвращает блок user из записи при совпадении пароля и одного из identifiers.
    """
    ident_in = raw_login.strip()
    ident_cf = ident_in.casefold()
    ident_name = _normalize_name(ident_in)

    for row in load_local_user_entries():
        pwd = row.get("password")
        if not isinstance(pwd, str) or pwd != password:
            continue

        idents = row.get("identifiers")
        if not isinstance(idents, list):
            continue

        for alias in idents:
            if not isinstance(alias, str):
                continue
            a = alias.strip()
            if not a:
                continue
            if a == ident_in:
                return _extract_user_block(row)
            if a.casefold() == ident_cf:
                return _extract_user_block(row)
            if _normalize_name(a) == ident_name:
                return _extract_user_block(row)

    return None


def _extract_user_block(row: dict[str, Any]) -> dict[str, Any]:
    u = row.get("user")
    if isinstance(u, dict):
        return {
            "id": str(u.get("id", "local")),
            "name": str(u.get("name", "Студент")),
            "group": str(u.get("group", "")),
        }
    return {"id": "local", "name": "Студент", "group": ""}
