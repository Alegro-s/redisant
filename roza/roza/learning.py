from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from roza.config import Settings
from roza.runtime_prefs import effective_learning_enabled


def _model_label(settings: Settings) -> str:
    if settings.llm_backend == "ollama":
        return settings.ollama_model
    if settings.llm_backend == "openai_compatible":
        return settings.openai_model
    p = settings.llama_cpp_model_path
    return p.name if p else "llama_cpp"


def log_turn(
    settings: Settings,
    user_text: str,
    assistant_text: str,
    *,
    source: str,
    system_content: str | None = None,
) -> None:
    """Добавляет строку в JSONL для последующего SFT / анализа (не онлайн-обучение весов)."""
    if not effective_learning_enabled(settings):
        return
    path: Path = settings.learning_log_path
    path.parent.mkdir(parents=True, exist_ok=True)

    messages: list[dict[str, str]] = []
    if system_content:
        messages.append({"role": "system", "content": system_content})
    messages.append({"role": "user", "content": user_text})
    messages.append({"role": "assistant", "content": assistant_text})

    row = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "source": source,
        "llm_backend": settings.llm_backend,
        "base_model": _model_label(settings),
        "messages": messages,
    }
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")
