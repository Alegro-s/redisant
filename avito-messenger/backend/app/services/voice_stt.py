from __future__ import annotations

from pathlib import Path

import httpx

from app.services.secure_bundle import get_inference_endpoints

class VoiceSttError(Exception):
    pass

def transcribe_voice_file(file_path: Path) -> tuple[str, bool]:
    ep = get_inference_endpoints()
    url = (ep.stt_base or "").strip().rstrip("/")
    if not url:
        raise VoiceSttError("STT endpoint not configured")

    transcribe_url = url if url.endswith("/transcribe") else f"{url}/transcribe"
    headers: dict[str, str] = {}
    token = (ep.stt_token or "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"

    with httpx.Client(timeout=ep.stt_timeout) as client:
        with file_path.open("rb") as fh:
            res = client.post(
                transcribe_url,
                headers=headers,
                files={"file": (file_path.name, fh, "application/octet-stream")},
            )
        if res.status_code != 200:
            raise VoiceSttError(f"STT HTTP {res.status_code}")
        data = res.json()
        text = (data.get("text") or data.get("transcript") or "").strip()
        if not text:
            raise VoiceSttError("empty transcript")
        return text, True
