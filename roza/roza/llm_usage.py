"""Снимок usage последнего нестримингового вызова модели (для HTTP/WS API)."""
from __future__ import annotations

from typing import Any

_last_snapshot: dict[str, Any] | None = None


def clear_last_llm_usage() -> None:
    global _last_snapshot
    _last_snapshot = None


def take_last_llm_usage() -> dict[str, Any] | None:
    """Вернуть последний снимок и обнулить (один раз на ответ пользователю)."""
    global _last_snapshot
    u = _last_snapshot
    _last_snapshot = None
    return u


def merge_last_llm_usage(update: dict[str, Any]) -> None:
    """Полностью заменить снимок (при нескольких вызовах побеждает последний)."""
    global _last_snapshot
    _last_snapshot = dict(update)
