import json
from datetime import datetime
from pathlib import Path

from .schemas import ScheduleItem

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"
_OVERRIDE_FILE = _DATA_DIR / "schedule_override.json"

def _ensure_dir() -> None:
    _DATA_DIR.mkdir(parents=True, exist_ok=True)

def load_override() -> list[ScheduleItem] | None:
    if not _OVERRIDE_FILE.is_file():
        return None
    try:
        raw = json.loads(_OVERRIDE_FILE.read_text(encoding="utf-8"))
        return [ScheduleItem.model_validate(item) for item in raw]
    except (json.JSONDecodeError, ValueError):
        return None

def save_override(items: list[ScheduleItem]) -> None:
    _ensure_dir()
    payload = [item.model_dump(mode="json") for item in items]
    _OVERRIDE_FILE.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

def items_to_jsonable(items: list[ScheduleItem]) -> list[dict]:
    return [item.model_dump(mode="json") for item in items]
