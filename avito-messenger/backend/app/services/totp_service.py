from __future__ import annotations

import pyotp

def generate_secret() -> str:
    return pyotp.random_base32()

def provisioning_uri(secret: str, *, email: str, issuer: str = "YALGSI") -> str:
    return pyotp.totp.TOTP(secret).provisioning_uri(name=email or "user", issuer_name=issuer)

def verify_code(secret: str, code: str) -> bool:
    if not secret or not code:
        return False
    clean = code.strip().replace(" ", "")
    totp = pyotp.TOTP(secret)
    return totp.verify(clean, valid_window=1)
