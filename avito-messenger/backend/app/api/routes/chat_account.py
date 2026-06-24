from __future__ import annotations

import re
import secrets
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import User
from app.db.session import get_db
from app.services.mail_service import send_verification_code, smtp_configured
from app.services.password_auth import hash_password, verify_password
from app.services.totp_service import generate_secret, provisioning_uri, verify_code
from app.services.user_prefs import get_settings as user_settings, save_settings, set_internal, totp_enabled
from app.api.routes.chat import _auth_user, _presence_online

router = APIRouter(prefix="/chat", tags=["chat-account"])

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,32}$")
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_CODE_TTL = timedelta(minutes=15)

class ProfileOut(BaseModel):
    username: str
    display_name: str
    email: str | None
    email_verified: bool
    role: str
    settings: dict

class ProfilePatchIn(BaseModel):
    display_name: str | None = Field(None, min_length=1, max_length=128)
    username: str | None = Field(None, min_length=3, max_length=32)
    password: str | None = Field(None, min_length=1, max_length=128)

class EmailChangeIn(BaseModel):
    new_email: str = Field(..., min_length=5, max_length=255)
    password: str = Field(..., min_length=1, max_length=128)

class VerifyCodeIn(BaseModel):
    code: str = Field(..., min_length=4, max_length=8)

class SettingsPatchIn(BaseModel):
    theme: str | None = None
    font_scale: float | None = Field(None, ge=0.85, le=1.5)

class PrivacyPatchIn(BaseModel):
    show_email: bool | None = None
    show_username: bool | None = None
    show_display_name: bool | None = None
    show_last_seen: bool | None = None

class TotpEnableIn(BaseModel):
    code: str = Field(..., min_length=6, max_length=8)

class TotpDisableIn(BaseModel):
    password: str
    code: str = Field(..., min_length=6, max_length=8)

class PublicProfileOut(BaseModel):
    username: str
    display_name: str | None = None
    email: str | None = None
    online: bool | None = None

def _profile_out(user: User) -> ProfileOut:
    settings = user_settings(user)
    safe = {k: v for k, v in settings.items() if k not in ("totp_secret", "totp_pending_secret", "email_verify_code")}
    return ProfileOut(
        username=user.username,
        display_name=user.display_name,
        email=user.email,
        email_verified=bool(user.email_verified),
        role=user.role.value,
        settings=safe,
    )

def _gen_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"

def _store_email_code(user: User, code: str, *, pending_email: str | None = None) -> None:
    expires = (datetime.now(UTC) + _CODE_TTL).isoformat()
    payload = {
        "email_verify_code": code,
        "email_verify_expires": expires,
    }
    if pending_email:
        payload["pending_email"] = pending_email.lower()
    set_internal(user, **payload)

def _check_email_code(user: User, code: str) -> bool:
    raw = user.user_settings or {}
    expected = str(raw.get("email_verify_code") or "")
    expires_s = raw.get("email_verify_expires")
    if not expected or not expires_s:
        return False
    try:
        expires = datetime.fromisoformat(str(expires_s))
        if expires < datetime.now(UTC):
            return False
    except ValueError:
        return False
    return secrets.compare_digest(expected, code.strip())

@router.get("/me", response_model=ProfileOut)
def get_me(user: User = Depends(_auth_user)) -> ProfileOut:
    return _profile_out(user)

@router.patch("/me", response_model=ProfileOut)
def patch_me(payload: ProfilePatchIn, user: User = Depends(_auth_user), db: Session = Depends(get_db)) -> ProfileOut:
    if payload.display_name is not None:
        user.display_name = payload.display_name.strip()[:128]
    if payload.username is not None:
        if not payload.password:
            raise HTTPException(status_code=400, detail="Для смены логина укажите пароль")
        if not verify_password(payload.password, user.password_hash):
            raise HTTPException(status_code=401, detail="Неверный пароль")
        new_name = payload.username.strip().lower()
        if not _USERNAME_RE.match(new_name):
            raise HTTPException(status_code=400, detail="Логин: 3–32 символа, латиница, цифры, _")
        if new_name != user.username and db.query(User).filter(User.username == new_name).first():
            raise HTTPException(status_code=409, detail="Логин уже занят")
        user.username = new_name
    db.add(user)
    db.commit()
    db.refresh(user)
    return _profile_out(user)

@router.post("/me/email/send-verification")
def send_email_verification(user: User = Depends(_auth_user), db: Session = Depends(get_db)) -> dict:
    if not user.email:
        raise HTTPException(status_code=400, detail="Email не указан")
    if user.email_verified:
        return {"ok": True, "already_verified": True}
    code = _gen_code()
    _store_email_code(user, code)
    db.add(user)
    db.commit()
    sent = send_verification_code(user.email, code, purpose="подтверждение email")
    out: dict = {"ok": sent, "smtp_configured": smtp_configured()}
    if not sent and get_settings().debug:
        out["dev_code"] = code
    if not sent and not get_settings().debug:
        raise HTTPException(status_code=503, detail="Почтовый сервер не настроен (SMTP)")
    return out

@router.post("/me/email/verify")
def verify_email(payload: VerifyCodeIn, user: User = Depends(_auth_user), db: Session = Depends(get_db)) -> dict:
    if not _check_email_code(user, payload.code):
        raise HTTPException(status_code=400, detail="Неверный или просроченный код")
    raw = user.user_settings or {}
    pending = raw.get("pending_email")
    if pending:
        if db.query(User).filter(User.email == pending, User.id != user.id).first():
            raise HTTPException(status_code=409, detail="Email уже используется")
        user.email = str(pending)
    user.email_verified = True
    set_internal(
        user,
        email_verify_code=None,
        email_verify_expires=None,
        pending_email=None,
    )
    db.add(user)
    db.commit()
    return {"ok": True, "email": user.email, "verified": True}

@router.post("/me/email/change")
def request_email_change(
    payload: EmailChangeIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный пароль")
    new_email = payload.new_email.strip().lower()
    if not _EMAIL_RE.match(new_email):
        raise HTTPException(status_code=400, detail="Некорректный email")
    if db.query(User).filter(User.email == new_email, User.id != user.id).first():
        raise HTTPException(status_code=409, detail="Email уже зарегистрирован")
    code = _gen_code()
    _store_email_code(user, code, pending_email=new_email)
    db.add(user)
    db.commit()
    sent = send_verification_code(new_email, code, purpose="смена email")
    out: dict = {"ok": sent, "pending_email": new_email}
    if not sent and get_settings().debug:
        out["dev_code"] = code
    if not sent and not get_settings().debug:
        raise HTTPException(status_code=503, detail="Почтовый сервер не настроен (SMTP)")
    return out

@router.get("/settings")
def get_settings_endpoint(user: User = Depends(_auth_user)) -> dict:
    s = user_settings(user)
    return {
        "theme": s.get("theme", "system"),
        "font_scale": s.get("font_scale", 1.0),
        "privacy": s.get("privacy", {}),
        "totp_enabled": bool(s.get("totp_enabled")),
        "email_verified": user.email_verified,
    }

@router.patch("/settings")
def patch_settings(
    payload: SettingsPatchIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    patch: dict = {}
    if payload.theme is not None and payload.theme in ("system", "light", "dark"):
        patch["theme"] = payload.theme
    if payload.font_scale is not None:
        patch["font_scale"] = round(payload.font_scale, 2)
    save_settings(user, patch)
    db.add(user)
    db.commit()
    return get_settings_endpoint(user)

@router.patch("/settings/privacy")
def patch_privacy(
    payload: PrivacyPatchIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    privacy_patch = {k: v for k, v in payload.model_dump().items() if v is not None}
    save_settings(user, {"privacy": privacy_patch})
    db.add(user)
    db.commit()
    return user_settings(user).get("privacy", {})

@router.post("/settings/totp/setup")
def totp_setup(user: User = Depends(_auth_user), db: Session = Depends(get_db)) -> dict:
    if totp_enabled(user):
        raise HTTPException(status_code=400, detail="2FA уже включена")
    secret = generate_secret()
    set_internal(user, totp_pending_secret=secret)
    db.add(user)
    db.commit()
    issuer = get_settings().app_display_name
    uri = provisioning_uri(secret, email=user.email or user.username, issuer=issuer)
    return {"ok": True, "secret": secret, "provisioning_uri": uri}

@router.post("/settings/totp/enable")
def totp_enable(
    payload: TotpEnableIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    raw = user.user_settings or {}
    secret = raw.get("totp_pending_secret") or raw.get("totp_secret")
    if not secret:
        raise HTTPException(status_code=400, detail="Сначала вызовите /settings/totp/setup")
    if not verify_code(str(secret), payload.code):
        raise HTTPException(status_code=400, detail="Неверный код из приложения")
    set_internal(
        user,
        totp_secret=str(secret),
        totp_pending_secret=None,
        totp_enabled=True,
    )
    save_settings(user, {"totp_enabled": True})
    db.add(user)
    db.commit()
    return {"ok": True, "totp_enabled": True}

@router.post("/settings/totp/disable")
def totp_disable(
    payload: TotpDisableIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный пароль")
    raw = user.user_settings or {}
    secret = raw.get("totp_secret")
    if not secret or not verify_code(str(secret), payload.code):
        raise HTTPException(status_code=400, detail="Неверный код 2FA")
    set_internal(user, totp_secret=None, totp_pending_secret=None, totp_enabled=False)
    save_settings(user, {"totp_enabled": False})
    db.add(user)
    db.commit()
    return {"ok": True, "totp_enabled": False}

@router.get("/users/{username}/profile", response_model=PublicProfileOut)
def public_profile(
    username: str,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> PublicProfileOut:
    target = db.query(User).filter(User.username == username).first()
    if not target or not target.is_active:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    privacy = user_settings(target).get("privacy", {})
    out = PublicProfileOut(username=target.username)
    if privacy.get("show_display_name", True):
        out.display_name = target.display_name
    if privacy.get("show_email", False) and target.email_verified:
        out.email = target.email
    if privacy.get("show_last_seen", True):
        out.online = _presence_online(db, target.username)
    if not privacy.get("show_username", True) and user.id != target.id:
        raise HTTPException(status_code=403, detail="Профиль скрыт")
    return out
