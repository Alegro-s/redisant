from __future__ import annotations

import base64
import hashlib
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ENC_VERSION = 1


def _derive_key(seed: str, purpose: str) -> bytes:
    return hashlib.sha256(f"yalgsi-{purpose}:v1:{seed}".encode("utf-8")).digest()


def analysis_key_from_settings(seed: str) -> bytes:
    return _derive_key(seed, "analysis")


def admin_view_key_from_settings(seed: str) -> bytes:
    return _derive_key(seed, "admin-view")


def resolve_message_plaintext(message) -> str | None:
    """Plain text for AI analysis: body or admin_seal for E2E messages."""
    meta = message.metadata_ if isinstance(getattr(message, "metadata_", None), dict) else {}
    if meta.get("enc_v1"):
        admin_seal = meta.get("admin_seal")
        if not admin_seal:
            return None
        from app.config import get_settings

        seed = (get_settings().msg_admin_view_key or "").strip()
        if not seed:
            return None
        try:
            return open_text(str(admin_seal), admin_view_key_from_settings(seed)).strip() or None
        except (ValueError, OSError):
            return None
    body = (getattr(message, "body", None) or "").strip()
    return body or None


def session_analysis_seal_key(auth_token: str) -> bytes:
    token = (auth_token or "").strip()
    return hashlib.sha256(f"{token}:yalgsi-analysis-seal:v1".encode("utf-8")).digest()


def seal_bytes(plaintext: bytes, key: bytes) -> str:
    nonce = os.urandom(12)
    ct = AESGCM(key).encrypt(nonce, plaintext, None)
    return base64.urlsafe_b64encode(nonce + ct).decode("ascii")


def open_bytes(blob: str, key: bytes) -> bytes:
    raw = base64.urlsafe_b64decode(blob.encode("ascii"))
    if len(raw) < 13:
        raise ValueError("invalid seal")
    nonce, ct = raw[:12], raw[12:]
    return AESGCM(key).decrypt(nonce, ct, None)


def seal_text(text: str, key: bytes) -> str:
    return seal_bytes(text.encode("utf-8"), key)


def open_text(blob: str, key: bytes) -> str:
    return open_bytes(blob, key).decode("utf-8")
