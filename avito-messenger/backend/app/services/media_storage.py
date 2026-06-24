from __future__ import annotations

import secrets
import time
from pathlib import Path

from fastapi import HTTPException, UploadFile

VOICE_SUFFIXES = frozenset({".webm", ".ogg", ".m4a", ".wav", ".aac", ".mp3"})
VIDEO_SUFFIXES = frozenset({".mp4", ".webm", ".mov", ".m4v"})
VOICE_MAX_BYTES = 8 * 1024 * 1024
VIDEO_MAX_BYTES = 16 * 1024 * 1024
_REPO_ROOT = Path(__file__).resolve().parents[3]
VOICE_DIR = _REPO_ROOT / "media" / "voice"
VIDEO_DIR = _REPO_ROOT / "media" / "video"

def ensure_media_dirs() -> None:
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    VIDEO_DIR.mkdir(parents=True, exist_ok=True)

def _normalize_suffix(raw: str | None, *, allowed: frozenset[str], default: str) -> str:
    suffix = (raw or default).lower()
    if not suffix.startswith("."):
        suffix = f".{suffix}"
    if suffix not in allowed:
        return default
    return suffix

def media_path_from_url(url: str | None, *, kind: str) -> Path | None:
    if not url:
        return None
    name = url.rstrip("/").split("/")[-1]
    base = VOICE_DIR if kind == "voice" else VIDEO_DIR
    candidate = base / name
    return candidate if candidate.is_file() else None

async def save_voice_upload(
    file: UploadFile, *, username: str, suffix_hint: str | None, data: bytes
) -> tuple[Path, str]:
    ensure_media_dirs()
    suffix = _normalize_suffix(
        suffix_hint or Path(file.filename or "voice.m4a").suffix,
        allowed=VOICE_SUFFIXES,
        default=".m4a",
    )
    if len(data) > VOICE_MAX_BYTES:
        raise HTTPException(status_code=413, detail="Voice file too large (max 8MB)")
    token_hex = secrets.token_hex(12)
    name = f"{int(time.time())}_{username}_{token_hex}{suffix}"
    target = VOICE_DIR / name
    target.write_bytes(data)
    return target, f"/media/voice/{name}"

async def save_video_upload(
    file: UploadFile, *, username: str, suffix_hint: str | None, data: bytes
) -> tuple[Path, str]:
    ensure_media_dirs()
    suffix = _normalize_suffix(
        suffix_hint or Path(file.filename or "video.mp4").suffix,
        allowed=VIDEO_SUFFIXES,
        default=".mp4",
    )
    if len(data) > VIDEO_MAX_BYTES:
        raise HTTPException(status_code=413, detail="Video file too large (max 16MB)")
    token_hex = secrets.token_hex(12)
    name = f"{int(time.time())}_{username}_{token_hex}{suffix}"
    target = VIDEO_DIR / name
    target.write_bytes(data)
    return target, f"/media/video/{name}"
