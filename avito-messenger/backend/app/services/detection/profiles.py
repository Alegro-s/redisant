import json
from pathlib import Path

_CACHE: dict | None = None

def _candidate_paths() -> list[Path]:
    base = Path(__file__).resolve()
    return [
        base.parents[3] / "data" / "profiles.json",
        base.parents[2] / "data" / "profiles.json",
        Path("/app/data/profiles.json"),
        Path("data/profiles.json"),
    ]

def profiles_path() -> Path | None:
    for path in _candidate_paths():
        if path.is_file():
            return path
    return None

def load_profiles() -> dict:
    global _CACHE
    if _CACHE is not None:
        return _CACHE
    path = profiles_path()
    if not path:
        _CACHE = {}
        return _CACHE
    _CACHE = json.loads(path.read_text(encoding="utf-8"))
    return _CACHE
