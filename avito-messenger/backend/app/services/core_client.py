from __future__ import annotations

import httpx

from app.services.secure_bundle import get_inference_endpoints

def core_available() -> bool:
    return bool(get_inference_endpoints().core_base)

def analyze_text_remote(text: str, metadata: dict, *, timeout: int | None = None) -> dict | None:
    ep = get_inference_endpoints()
    if not ep.core_base:
        return None
    url = f"{ep.core_base.rstrip('/')}/analyze"
    effective_timeout = timeout if timeout is not None else ep.core_timeout
    try:
        with httpx.Client(timeout=effective_timeout) as client:
            res = client.post(url, json={"text": text, "metadata": metadata})
            if res.status_code != 200:
                return None
            return res.json()
    except httpx.HTTPError:
        return None

def embed_text_remote(text: str, corpus: list[str]) -> dict | None:
    ep = get_inference_endpoints()
    if not ep.core_base:
        return None
    url = f"{ep.core_base.rstrip('/')}/embed/similarity"
    try:
        with httpx.Client(timeout=ep.core_timeout) as client:
            res = client.post(url, json={"text": text, "corpus": corpus[:200]})
            if res.status_code != 200:
                return None
            return res.json()
    except httpx.HTTPError:
        return None
