from __future__ import annotations

import hashlib
import secrets

_PBKDF2_ITERATIONS = 310_000
_SALT_BYTES = 16

def hash_password(password: str) -> str:
    salt = secrets.token_bytes(_SALT_BYTES)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, _PBKDF2_ITERATIONS)
    return f"pbkdf2_sha256${_PBKDF2_ITERATIONS}${salt.hex()}${digest.hex()}"

def verify_password(password: str, stored: str | None) -> bool:
    if not stored:
        return False
    try:
        algo, iterations_s, salt_hex, digest_hex = stored.split("$", 3)
        if algo != "pbkdf2_sha256":
            return False
        iterations = int(iterations_s)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(digest_hex)
        actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
        return secrets.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False

def validate_password_strength(password: str) -> str | None:
    if len(password) < 8:
        return "Пароль должен быть не короче 8 символов"
    if password.isdigit() or password.isalpha():
        return "Пароль должен содержать буквы и цифры"
    if password.lower() == password:
        return "Добавьте хотя бы одну заглавную букву"
    return None
