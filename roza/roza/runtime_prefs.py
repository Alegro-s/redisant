"""Сессионные переопределения (до перезапуска сервера), не переписывают config.yaml."""

from __future__ import annotations

from roza.config import Settings

_learning_enabled_override: bool | None = None


def set_learning_enabled_override(enabled: bool | None) -> None:
    """None — снова брать значение из config.yaml."""
    global _learning_enabled_override
    _learning_enabled_override = enabled


def effective_learning_enabled(settings: Settings) -> bool:
    if _learning_enabled_override is not None:
        return _learning_enabled_override
    return settings.learning_enabled


def learning_override_is_set() -> bool:
    return _learning_enabled_override is not None
