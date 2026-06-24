from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
import re
import secrets
import time
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, File, Header, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db.models import Alert, Message, MessageChannel, MessageFeatures, User, UserMlProfile, UserRole
from app.db.session import get_db
from app.schemas.message import MessageIngest
from app.services.chat_auth import issue_chat_token, verify_chat_token
from app.services.chat_state import presence_online, read_at_for, set_read as persist_read_state, touch_presence
from app.services.ingest_pipeline import process_incoming_message
from app.services.messages import ingest_message
from app.services.password_auth import hash_password, validate_password_strength, verify_password
from app.services.push_notify import debug_device_tokens, register_device_token, unregister_device_token
from app.services.voice_analyze import analyze_voice_file, enroll_voice_remote, voice_analyze_configured
from app.services.voice_crypto import encoding_header, unpack_voice
from app.services.media_storage import save_video_upload, save_voice_upload
from app.services.voice_stt import VoiceSttError, transcribe_voice_file
from app.services.channel_keys import channel_key_b64, logical_channel_id
from app.services.message_crypto import (
    ENC_VERSION,
    admin_view_key_from_settings,
    open_text,
    seal_text,
    session_analysis_seal_key,
)

router = APIRouter(prefix="/chat", tags=["chat"])

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,32}$")
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_LEGACY_PASSWORD = "Admin123!"
_TYPING_TTL_SEC = 8
_typing_state: dict[tuple[str, str], float] = {}
_read_state: dict[tuple[str, str], dict] = {}
_presence_state: dict[str, float] = {}
_PRESENCE_TTL_SEC = 35
_DISPLAY_TZ = ZoneInfo("Europe/Moscow")
_MEDIA_DIR = Path(__file__).resolve().parents[3] / "media" / "voice"
_MEDIA_DIR.mkdir(parents=True, exist_ok=True)

def _voice_analysis_dict(path: Path, user: User) -> dict | None:
    if not voice_analyze_configured():
        return None
    enrolled = user.voice_embedding if isinstance(user.voice_embedding, list) else None
    result = analyze_voice_file(path, username=user.username, enrolled=enrolled)
    if not result:
        return None
    return {
        "spoof_score": result.spoof_score,
        "speaker_match": result.speaker_match,
        "voice_risk": result.voice_risk,
        "l6_hit": result.l6_hit,
        "detail": result.detail,
    }

class ChatLoginIn(BaseModel):
    username: str = Field(..., min_length=1, max_length=64)
    password: str = Field(..., min_length=1, max_length=128)
    totp_code: str | None = Field(None, min_length=6, max_length=8)

class ChatRegisterIn(BaseModel):
    username: str = Field(..., min_length=3, max_length=32)
    email: str = Field(..., min_length=5, max_length=255)
    password: str = Field(..., min_length=8, max_length=128)
    display_name: str = Field("", max_length=128)

class ChatUserOut(BaseModel):
    username: str
    display_name: str
    role: str
    blocked: bool
    mattermost_linked: bool
    email_verified: bool = False

class ChatLoginOut(BaseModel):
    ok: bool
    user: ChatUserOut | None = None
    token: str | None = None
    token_exp: int | None = None
    ttl_sec: int | None = None
    totp_required: bool = False

class ChatMessageOut(BaseModel):
    id: UUID
    created_at: datetime
    channel: str
    sender: str
    body: str
    kind: str = "text"
    voice_url: str | None = None
    voice_duration_sec: int | None = None
    video_url: str | None = None
    video_duration_sec: int | None = None
    channel_name: str = "general"
    parent_message_id: UUID | None = None
    thread_replies: int = 0
    risk: int
    alert: bool
    encrypted: bool = False

class ChannelKeyOut(BaseModel):
    channel_id: str
    key: str
    enc_version: int = ENC_VERSION

class VoiceUploadOut(BaseModel):
    ok: bool
    voice_url: str
    size: int
    transcript: str | None = None
    stt_ok: bool = False
    encrypted: bool = False

class VideoUploadOut(BaseModel):
    ok: bool
    video_url: str
    size: int

class ChatSendIn(BaseModel):
    username: str
    body: str = Field("", max_length=8000)
    channel: MessageChannel = MessageChannel.mattermost
    channel_name: str = "general"
    kind: str = "text"
    dialog_with: str | None = None
    parent_message_id: UUID | None = None
    voice_duration_sec: int | None = None
    voice_url: str | None = None
    video_duration_sec: int | None = None
    video_url: str | None = None
    impersonates_username: str | None = None
    body_enc: str | None = Field(None, max_length=12000)
    analysis_seal: str | None = Field(None, max_length=12000)
    enc_version: int | None = None

class SecurityEventOut(BaseModel):
    id: UUID
    created_at: datetime
    level: str
    title: str
    text: str

class ChannelOut(BaseModel):
    id: str
    title: str
    unread: int
    last_at: datetime | None
    last_preview: str | None = None
    kind: str = "channel"
    peer_username: str | None = None
    peer_online: bool = False

class TypingIn(BaseModel):
    channel_name: str = "general"
    is_typing: bool = True

class TypingOut(BaseModel):
    users: list[str]

class ReadIn(BaseModel):
    channel_name: str = "general"
    peer_username: str | None = None
    last_message_id: UUID

class PresenceIn(BaseModel):
    is_online: bool = True

class ReadStateOut(BaseModel):
    username: str
    last_message_id: UUID
    at: datetime

class PendingNotificationOut(BaseModel):
    id: str
    kind: str
    title: str
    text: str
    created_at: datetime

class DeviceTokenIn(BaseModel):
    token: str = Field(..., min_length=8, max_length=512)

class GroupCreateIn(BaseModel):
    title: str = Field(..., min_length=1, max_length=64)
    member_usernames: list[str] = Field(default_factory=list, max_length=32)

class GroupCreateOut(BaseModel):
    ok: bool
    id: str
    title: str
    channel_name: str

class GroupInfoOut(BaseModel):
    ok: bool
    channel_name: str
    title: str
    creator: str | None = None
    members: list[str] = Field(default_factory=list)

def _group_catalog(rows: list[Message], db: Session) -> dict[str, dict]:
    catalog: dict[str, dict] = {}
    for m in rows:
        meta = _meta(m)
        channel_name = meta.get("channel_name")
        title = meta.get("group_title")
        if not channel_name or not title:
            continue
        key = str(channel_name)
        if key in catalog:
            continue
        members = meta.get("group_members")
        catalog[key] = {
            "title": str(title),
            "members": [str(x) for x in members] if isinstance(members, list) else [],
            "creator": _sender_username(db, m),
        }
    return catalog

def _user_in_group(channel_name: str, group_meta: dict[str, dict], username: str) -> bool:
    if not channel_name.startswith("grp_"):
        return True
    info = group_meta.get(channel_name)
    if not info:
        return False
    members = info.get("members") or []
    creator = info.get("creator")
    return username == creator or username in members

def _resolve_user(db: Session, username: str) -> User:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    return user

def _verify_user_password(user: User, password: str) -> bool:
    if user.password_hash:
        return verify_password(password, user.password_hash)
    if user.role == UserRole.super_admin and password == _LEGACY_PASSWORD:
        return True
    return False

def _default_user_settings() -> dict:
    return {
        "theme": "system",
        "font_scale": 1.0,
        "privacy": {
            "show_email": False,
            "show_username": True,
            "show_display_name": True,
            "show_last_seen": True,
        },
        "ai_shield_linked": True,
    }

def _user_out(user: User) -> ChatUserOut:
    return ChatUserOut(
        username=user.username,
        display_name=user.display_name,
        role=user.role.value,
        blocked=user.is_blocked,
        mattermost_linked=bool(user.mattermost_user_id),
        email_verified=bool(user.email_verified),
    )

def _client_key(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"

def _issue_login(db: Session, user: User) -> ChatLoginOut:
    if user.is_blocked:
        raise HTTPException(status_code=403, detail=f"Пользователь заблокирован: {user.block_reason or 'без причины'}")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Пользователь деактивирован")
    ttl_sec = 60 * 60 * 12
    token, exp = issue_chat_token(user.username, role=user.role.value, ttl_sec=ttl_sec)
    return ChatLoginOut(
        ok=True,
        user=_user_out(user),
        token=token,
        token_exp=exp,
        ttl_sec=ttl_sec,
    )

def _channel_name(m: Message) -> str:
    meta = m.metadata_ or {}
    if isinstance(meta, dict):
        return str(meta.get("channel_name") or "general")
    return "general"

def _meta(m: Message) -> dict:
    if isinstance(m.metadata_, dict):
        return m.metadata_
    return {}

def _dialog_peer(m: Message) -> str | None:
    return _meta(m).get("dialog_with")

def _kind(m: Message) -> str:
    return str(_meta(m).get("kind") or "text")

def _voice_url(m: Message) -> str | None:
    v = _meta(m).get("voice_url")
    return str(v) if v else None

def _voice_duration(m: Message) -> int | None:
    v = _meta(m).get("voice_duration_sec")
    return int(v) if isinstance(v, int) else None

def _video_url(m: Message) -> str | None:
    v = _meta(m).get("video_url")
    return str(v) if v else None

def _video_duration(m: Message) -> int | None:
    v = _meta(m).get("video_duration_sec")
    return int(v) if isinstance(v, int) else None

def _voice_placeholder(seconds: int | None) -> str:
    sec = max(1, int(seconds or 1))
    return f"[голосовое {sec} с]"

def _video_placeholder(seconds: int | None) -> str:
    sec = max(1, int(seconds or 1))
    return f"[видеокружок {sec} с]"

def _parent_id(m: Message) -> UUID | None:
    p = _meta(m).get("parent_message_id")
    if not p:
        return None
    try:
        return UUID(str(p))
    except ValueError:
        return None

def _presence_online(db: Session, username: str) -> bool:
    try:
        if presence_online(db, username):
            return True
    except Exception:
        pass
    ts = _presence_state.get(username)
    return bool(ts and ts + _PRESENCE_TTL_SEC >= time.time())

def _touch_presence(db: Session, username: str, *, online: bool = True) -> None:
    _presence_state[username] = time.time()
    try:
        touch_presence(db, username, online=online)
    except Exception:
        pass

def _display_name(db: Session, username: str) -> str:
    u = db.query(User).filter(User.username == username).first()
    return (u.display_name or username) if u else username

def _can_see_analyst(user: User) -> bool:
    return user.role == UserRole.super_admin

def _sender_username(db: Session, m: Message) -> str | None:
    if not m.sender_id:
        return None
    s = db.get(User, m.sender_id)
    return s.username if s else None

def _channel_key_for_user(db: Session, m: Message, viewer: str) -> str | None:
    peer = _dialog_peer(m)
    if peer:
        sender = _sender_username(db, m)
        if not sender:
            return None
        if sender == viewer:
            return f"dm:{peer}"
        if peer == viewer:
            return f"dm:{sender}"
        return None
    return f"ch:{_channel_name(m)}"

def _user_in_message(db: Session, m: Message, username: str) -> bool:
    peer = _dialog_peer(m)
    if peer:
        sender = _sender_username(db, m)
        if not sender:
            return False
        return sender == username or peer == username
    return True

def _read_at_for_key(db: Session, key: str, username: str) -> datetime | None:
    try:
        at = read_at_for(db, username, key)
        if at:
            return at
    except Exception:
        pass
    data = _read_state.get((key, username)) or {}
    at = data.get("at")
    return at if isinstance(at, datetime) else None

def _count_unread(db: Session, key: str, viewer: str, rows: list[Message]) -> int:
    read_at = _read_at_for_key(db, key, viewer)
    if read_at is not None and read_at.tzinfo is None:
        read_at = read_at.replace(tzinfo=UTC)
    unread = 0
    for m in rows:
        msg_key = _channel_key_for_user(db, m, viewer)
        if msg_key != key:
            continue
        sender = _sender_username(db, m)
        if sender == viewer:
            continue
        created = m.created_at
        if created is not None and created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        if read_at is not None and created is not None and created <= read_at:
            continue
        unread += 1
    return unread

def _secure_admin_unread(db: Session, username: str) -> int:
    read_key = ("dm:secure_admin", username)
    read_at = (_read_state.get(read_key) or {}).get("at")
    q = db.query(Alert)
    if isinstance(read_at, datetime):
        q = q.filter(Alert.created_at > read_at)
    return q.count()

def _message_is_encrypted(m: Message) -> bool:
    return bool(_meta(m).get("enc_v1"))


def _decode_encrypted_send(
    payload: ChatSendIn,
    auth_token: str,
) -> tuple[str, str, bool]:
    """Returns (stored_body, analysis_plaintext, is_encrypted)."""
    if payload.enc_version == ENC_VERSION and payload.body_enc and payload.analysis_seal:
        token = auth_token.strip()
        if not token:
            raise HTTPException(status_code=401, detail="Нужен Bearer token для E2E")
        try:
            seal_key = session_analysis_seal_key(token)
            plaintext = open_text(payload.analysis_seal.strip(), seal_key)
        except Exception as exc:
            raise HTTPException(status_code=400, detail="Некорректный analysis_seal") from exc
        stored = payload.body_enc.strip()
        if not stored:
            raise HTTPException(status_code=400, detail="Пустой body_enc")
        return stored, plaintext, True
    if payload.kind == "text" and not payload.body.strip():
        raise HTTPException(status_code=400, detail="Пустой текст")
    plain = payload.body.strip()
    return plain, plain, False


def _message_preview(m: Message) -> str:
    kind = _meta(m).get("kind") or "text"
    if _message_is_encrypted(m):
        return "🔒 Сообщение"
    body = (m.body or "").strip()
    if kind == "voice":
        if body and not body.startswith("["):
            short = body if len(body) <= 48 else f"{body[:48]}…"
            return f"🎤 {short}"
        return "🎤 Голосовое"
    if kind == "video_note":
        return "🎬 Видеокружок"
    if len(body) > 48:
        return f"{body[:48]}…"
    return body

def _auth_user(
    db: Session = Depends(get_db),
    authorization: str | None = Header(None),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Нужен Bearer token")
    token = authorization.split(" ", 1)[1].strip()
    payload = verify_chat_token(token)
    return _resolve_user(db, payload["u"])

@router.get("/device/debug")
def device_debug(user: User = Depends(_auth_user)) -> dict:
    if user.role not in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(status_code=403, detail="Недостаточно прав")
    return {"users": debug_device_tokens(), "total_users": len(debug_device_tokens())}

@router.post("/register", response_model=ChatLoginOut)
def register(payload: ChatRegisterIn, request: Request, db: Session = Depends(get_db)) -> ChatLoginOut:
    from app.config import get_settings
    from app.services.auth_audit import log_auth_event
    from app.services.rate_limit import check_rate_limit

    settings = get_settings()
    if not check_rate_limit(
        f"register:{_client_key(request)}",
        limit=settings.auth_rate_limit_register,
        window_sec=settings.auth_rate_limit_window_sec,
    ):
        raise HTTPException(status_code=429, detail="Слишком много попыток регистрации. Подождите минуту.")
    username = payload.username.strip().lower()
    email = payload.email.strip().lower()
    if not _USERNAME_RE.match(username):
        raise HTTPException(status_code=400, detail="Логин: 3–32 символа, латиница, цифры, _")
    if not _EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Некорректный email")
    pwd_err = validate_password_strength(payload.password)
    if pwd_err:
        raise HTTPException(status_code=400, detail=pwd_err)
    if db.query(User).filter(User.username == username).first():
        raise HTTPException(status_code=409, detail="Логин уже занят")
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=409, detail="Email уже зарегистрирован")
    display_name = (payload.display_name or username).strip()[:128] or username
    user = User(
        username=username,
        display_name=display_name,
        email=email,
        email_verified=False,
        password_hash=hash_password(payload.password),
        role=UserRole.user,
        user_settings=_default_user_settings(),
    )
    db.add(user)
    db.flush()
    db.add(
        UserMlProfile(
            user_id=user.id,
            analysis_status="pending",
            needs_reanalysis=True,
        )
    )
    db.commit()
    db.refresh(user)
    log_auth_event(db, action="register", actor_username=username, details=f"email={email}")
    db.commit()
    try:
        from app.services.push_notify import notify_admins_new_user

        notify_admins_new_user(username, display_name, email)
    except Exception:
        pass
    return _issue_login(db, user)

@router.post("/login", response_model=ChatLoginOut)
def login(payload: ChatLoginIn, request: Request, db: Session = Depends(get_db)) -> ChatLoginOut:
    from app.config import get_settings
    from app.services.auth_audit import log_auth_event
    from app.services.rate_limit import check_rate_limit
    from app.services.totp_service import verify_code as verify_totp
    from app.services.user_prefs import totp_enabled

    settings = get_settings()
    client = _client_key(request)
    if not check_rate_limit(
        f"login:{client}",
        limit=settings.auth_rate_limit_login,
        window_sec=settings.auth_rate_limit_window_sec,
    ):
        raise HTTPException(status_code=429, detail="Слишком много попыток входа. Подождите минуту.")

    user = db.query(User).filter(User.username == payload.username.strip().lower()).first()
    if not user or not _verify_user_password(user, payload.password):
        log_auth_event(
            db,
            action="login_failed",
            actor_username=payload.username.strip().lower(),
            details=f"ip={client}",
        )
        db.commit()
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")
    if totp_enabled(user):
        raw = user.user_settings or {}
        secret = raw.get("totp_secret")
        if not payload.totp_code:
            return ChatLoginOut(ok=False, totp_required=True)
        if not secret or not verify_totp(str(secret), payload.totp_code):
            log_auth_event(db, action="login_2fa_failed", actor_username=user.username, details=f"ip={client}")
            db.commit()
            raise HTTPException(status_code=401, detail="Неверный код 2FA")
    log_auth_event(db, action="login_ok", actor_username=user.username, details=f"ip={client}")
    db.commit()
    return _issue_login(db, user)

@router.get("/users/search", response_model=list[ChatUserOut])
def search_users(
    q: str = Query("", min_length=0, max_length=64),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[ChatUserOut]:
    needle = q.strip().lower()
    if len(needle) < 2:
        return []
    rows = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            User.username != user.username,
            User.role != UserRole.scammer,
        )
        .order_by(User.display_name.asc())
        .limit(30)
        .all()
    )
    out: list[ChatUserOut] = []
    for u in rows:
        hay = f"{u.username} {u.display_name or ''}".lower()
        if needle not in hay:
            continue
        out.append(_user_out(u))
    return out[:20]

@router.get("/contacts", response_model=list[ChatUserOut])
def contacts(
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[ChatUserOut]:
    _touch_presence(db, user.username)
    q = db.query(User).filter(User.is_active.is_(True), User.username != user.username)
    if user.role == UserRole.user:
        q = q.filter(User.role != UserRole.scammer)
    rows = q.order_by(User.display_name.asc(), User.username.asc()).all()
    out: list[ChatUserOut] = []
    for u in rows:
        if u.username in ("secure_admin",):
            continue
        out.append(_user_out(u))
    return out

@router.post("/groups", response_model=GroupCreateOut)
def create_group(
    payload: GroupCreateIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> GroupCreateOut:
    _touch_presence(db, user.username)
    slug = "".join(ch if ch.isalnum() else "_" for ch in payload.title.strip().lower())[:32] or "group"
    channel_name = f"grp_{slug}_{secrets.token_hex(3)}"
    members = sorted({m.strip() for m in payload.member_usernames if m.strip()} - {user.username})
    welcome = f"Группа «{payload.title.strip()}» создана. Участники: {user.username}"
    if members:
        welcome += f", {', '.join(members)}"
    ingest_message(
        db,
        MessageIngest(
            username=user.username,
            channel=MessageChannel.mattermost,
            body=welcome,
            metadata={
                "client": "caht_flutter",
                "sent_at": datetime.now(UTC).isoformat(),
                "channel_name": channel_name,
                "kind": "system",
                "group_title": payload.title.strip(),
                "group_members": members,
            },
        ),
    )
    return GroupCreateOut(
        ok=True,
        id=f"ch:{channel_name}",
        title=payload.title.strip(),
        channel_name=channel_name,
    )

@router.get("/groups/{channel_name}", response_model=GroupInfoOut)
def group_info(
    channel_name: str,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> GroupInfoOut:
    _touch_presence(db, user.username)
    if not channel_name.startswith("grp_"):
        raise HTTPException(status_code=404, detail="Группа не найдена")
    rows = db.query(Message).order_by(Message.created_at.asc()).limit(5000).all()
    info = _group_catalog(rows, db).get(channel_name)
    if not info:
        raise HTTPException(status_code=404, detail="Группа не найдена")
    members = list(info.get("members") or [])
    if user.username not in members and info.get("creator") != user.username:
        members = [user.username, *members]
    return GroupInfoOut(
        ok=True,
        channel_name=channel_name,
        title=str(info.get("title") or channel_name),
        creator=info.get("creator"),
        members=members,
    )

@router.get("/channels", response_model=list[ChannelOut])
def channels(
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[ChannelOut]:
    _touch_presence(db, user.username)
    rows = db.query(Message).order_by(Message.created_at.desc()).limit(1000).all()
    group_meta = _group_catalog(list(reversed(rows)), db)
    grouped: dict[str, dict] = {}
    for m in rows:
        ch_name = _channel_name(m)
        if not _user_in_group(ch_name, group_meta, user.username):
            continue
        key = _channel_key_for_user(db, m, user.username)
        if key is None:
            continue
        g = grouped.setdefault(key, {"unread": 0, "last_at": m.created_at, "last_preview": _message_preview(m)})
        if m.created_at >= g["last_at"]:
            g["last_at"] = m.created_at
            g["last_preview"] = _message_preview(m)
    for key in grouped:
        grouped[key]["unread"] = _count_unread(db, key, user.username, rows)
    if not grouped:
        pass
    out: list[ChannelOut] = []
    if _can_see_analyst(user):
        last_alert = db.query(Alert).order_by(Alert.created_at.desc()).first()
        out.append(
            ChannelOut(
                id="dm:secure_admin",
                title="Информационный аналитик",
                unread=_secure_admin_unread(db, user.username),
                last_at=last_alert.created_at if last_alert else None,
                last_preview=(last_alert.title_ru if last_alert else None),
                kind="analyst",
                peer_username="secure_admin",
                peer_online=True,
            )
        )
    for cid, data in sorted(grouped.items()):
        if cid == "dm:secure_admin":
            continue
        if cid.startswith("dm:"):
            peer = cid[3:]
            out.append(
                ChannelOut(
                    id=cid,
                    title=_display_name(db, peer),
                    unread=data["unread"],
                    last_at=data["last_at"],
                    last_preview=data.get("last_preview"),
                    kind="dm",
                    peer_username=peer,
                    peer_online=_presence_online(db, peer),
                )
            )
        else:
            ch = cid[3:]
            ginfo = group_meta.get(ch)
            if ch.startswith("grp_") and not _user_in_group(ch, group_meta, user.username):
                continue
            if ginfo:
                title = str(ginfo.get("title") or ch)
            elif ch.startswith("grp_"):
                title = ch.replace("grp_", "Группа ", 1).rsplit("_", 1)[0].replace("_", " ")
            else:
                title = ch
            out.append(
                ChannelOut(
                    id=cid,
                    title=title,
                    unread=data["unread"],
                    last_at=data["last_at"],
                    last_preview=data.get("last_preview"),
                    kind="group" if ch.startswith("grp_") else "channel",
                )
            )
    return out

@router.get("/messages", response_model=list[ChatMessageOut])
def list_messages(
    channel_name: str = Query("general"),
    dialog_with: str | None = Query(None),
    parent_message_id: UUID | None = Query(None),
    limit: int = Query(100, ge=1, le=300),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[ChatMessageOut]:
    _touch_presence(db, user.username)
    if channel_name.startswith("grp_"):
        rows_for_meta = db.query(Message).order_by(Message.created_at.asc()).limit(5000).all()
        group_meta = _group_catalog(rows_for_meta, db)
        if not _user_in_group(channel_name, group_meta, user.username):
            raise HTTPException(status_code=403, detail="Нет доступа к группе")
    if dialog_with == "secure_admin":
        if not _can_see_analyst(user):
            raise HTTPException(status_code=403, detail="Недостаточно прав")
        alerts = db.query(Alert).order_by(Alert.created_at.asc()).limit(limit).all()
        if not alerts:
            return [
                ChatMessageOut(
                    id=UUID("00000000-0000-0000-0000-000000000002"),
                    created_at=datetime.now(UTC),
                    channel="mattermost",
                    sender="secure_admin",
                    body=(
                        "Контроль безопасности активен.\n"
                        "Здесь появятся алерты по рискам L1–L6, подозрительным диалогам и инцидентам."
                    ),
                    kind="system",
                    channel_name="security",
                    parent_message_id=None,
                    thread_replies=0,
                    risk=0,
                    alert=False,
                )
            ]
        out: list[ChatMessageOut] = []
        for a in alerts:
            out.append(
                ChatMessageOut(
                    id=a.id,
                    created_at=a.created_at,
                    channel="mattermost",
                    sender="secure_admin",
                    body=f"{a.title_ru}\n{a.explanation_ru}",
                    kind="system",
                    channel_name="security",
                    parent_message_id=None,
                    thread_replies=0,
                    risk=95 if a.severity.value in ("high", "critical") else 60,
                    alert=True,
                )
            )
        return out

    now = time.time()
    for key in list(_typing_state.keys()):
        if _typing_state[key] + _TYPING_TTL_SEC < now:
            _typing_state.pop(key, None)
    rows = db.query(Message).order_by(Message.created_at.desc()).limit(limit).all()
    out: list[ChatMessageOut] = []
    for m in reversed(rows):
        if dialog_with:
            peer = _dialog_peer(m)
            sender_uname = None
            if m.sender_id:
                su = db.get(User, m.sender_id)
                sender_uname = su.username if su else None
            is_out = sender_uname == user.username and peer == dialog_with
            is_in = sender_uname == dialog_with and peer == user.username
            if not (is_out or is_in):
                continue
        else:
            if _channel_name(m) != channel_name:
                continue
        parent_id = _parent_id(m)
        if parent_message_id and parent_id != parent_message_id:
            continue
        if not parent_message_id and parent_id is not None:
            continue
        sender = "unknown"
        if m.sender_id:
            s = db.get(User, m.sender_id)
            if s:
                sender = s.username
                if m.impersonated_user_id:
                    imp = db.get(User, m.impersonated_user_id)
                    if imp:
                        sender = f"{s.username} (как {imp.display_name})"
            else:
                sender = "unknown"
        else:
            meta_u = _meta(m).get("username")
            if meta_u:
                sender = str(meta_u)
        feat = db.query(MessageFeatures).filter(MessageFeatures.message_id == m.id).first()
        risk = int((feat.risk_score or 0) * 100) if feat and feat.risk_score is not None else 0
        reply_count = 0
        if parent_message_id is None:
            reply_count = sum(1 for r in rows if _parent_id(r) == m.id)
        out.append(
            ChatMessageOut(
                id=m.id,
                created_at=m.created_at,
                channel=m.channel.value,
                sender=sender,
                body=m.body,
                kind=_kind(m),
                voice_url=_voice_url(m),
                voice_duration_sec=_voice_duration(m),
                video_url=_video_url(m),
                video_duration_sec=_video_duration(m),
                channel_name=_channel_name(m),
                parent_message_id=parent_id,
                thread_replies=reply_count,
                risk=risk,
                alert=risk >= 42,
                encrypted=_message_is_encrypted(m),
            )
        )
    return out

@router.get("/e2e/channel-key", response_model=ChannelKeyOut)
def get_e2e_channel_key(
    channel_name: str = Query("general"),
    dialog_with: str | None = Query(None),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> ChannelKeyOut:
    if channel_name.startswith("grp_"):
        rows = db.query(Message).order_by(Message.created_at.desc()).limit(500).all()
        group_meta = _group_catalog(rows, db)
        if not _user_in_group(channel_name, group_meta, user.username):
            raise HTTPException(status_code=403, detail="Нет доступа к группе")
    ch_id = logical_channel_id(channel_name=channel_name, dialog_with=dialog_with, username=user.username)
    return ChannelKeyOut(channel_id=ch_id, key=channel_key_b64(db, ch_id))

@router.post("/send", response_model=ChatMessageOut)
def send_message(
    payload: ChatSendIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
    authorization: str | None = Header(None),
) -> ChatMessageOut:
    _touch_presence(db, user.username)
    if payload.dialog_with == "secure_admin":
        return ChatMessageOut(
            id=UUID("00000000-0000-0000-0000-000000000001"),
            created_at=datetime.now(UTC),
            channel="mattermost",
            sender="secure_admin",
            body="Принято. Контроль безопасности активен, новые инциденты буду присылать сюда.",
            kind="system",
            channel_name="security",
            parent_message_id=None,
            thread_replies=0,
            risk=0,
            alert=False,
        )

    if user.username != payload.username:
        raise HTTPException(status_code=403, detail="Можно отправлять только от своего имени")
    if user.is_blocked:
        raise HTTPException(status_code=403, detail=f"Пользователь заблокирован: {user.block_reason or 'без причины'}")
    if payload.kind not in ("text", "voice", "video_note"):
        raise HTTPException(status_code=400, detail="kind должен быть text|voice|video_note")

    auth_token = ""
    if authorization and authorization.lower().startswith("bearer "):
        auth_token = authorization.split(" ", 1)[1].strip()

    is_encrypted = False
    analysis_plaintext: str | None = None
    body = payload.body.strip()

    if payload.kind == "text":
        stored, analysis_plaintext, is_encrypted = _decode_encrypted_send(payload, auth_token)
        body = stored
    elif not body:
        pass

    stt_ok = False
    voice_meta: dict | None = None
    if payload.kind == "voice":
        if not payload.voice_url:
            raise HTTPException(status_code=400, detail="voice_url обязателен для голосового")
        fpath: Path | None = None
        if payload.voice_url:
            rel = payload.voice_url.split("/")[-1]
            candidate = _MEDIA_DIR / rel
            if candidate.is_file():
                fpath = candidate
        if (not body or body.startswith("[")) and fpath:
            try:
                transcript, stt_ok = transcribe_voice_file(fpath)
                body = transcript
            except VoiceSttError:
                stt_ok = False
        if not body or body.startswith("["):
            body = _voice_placeholder(payload.voice_duration_sec)
        if fpath:
            voice_meta = _voice_analysis_dict(fpath, user)
    elif payload.kind == "video_note":
        if not payload.video_url:
            raise HTTPException(status_code=400, detail="video_url обязателен для видеокружка")
        if not body or body.startswith("["):
            body = _video_placeholder(payload.video_duration_sec)
    meta: dict = {
        "client": "caht_flutter",
        "sent_at": datetime.now(UTC).isoformat(),
        "channel_name": payload.channel_name,
        "kind": payload.kind,
        "dialog_with": payload.dialog_with,
        "parent_message_id": str(payload.parent_message_id) if payload.parent_message_id else None,
        "voice_duration_sec": payload.voice_duration_sec,
        "voice_url": payload.voice_url,
        "video_duration_sec": payload.video_duration_sec,
        "video_url": payload.video_url,
        "voice_stt_ok": stt_ok,
        "voice_analysis": voice_meta,
        "encrypted": is_encrypted,
        "enc_v1": is_encrypted,
        "transport": "tls",
    }
    if is_encrypted and analysis_plaintext is not None:
        from app.config import get_settings

        view_seed = (get_settings().msg_admin_view_key or "").strip()
        if view_seed:
            meta["admin_seal"] = seal_text(analysis_plaintext, admin_view_key_from_settings(view_seed))
    msg = ingest_message(
        db,
        MessageIngest(
            username=payload.username,
            channel=payload.channel,
            body=body,
            metadata=meta,
            impersonates_username=payload.impersonates_username,
        ),
    )
    process_incoming_message(
        db,
        msg,
        analysis_plaintext=analysis_plaintext if is_encrypted else None,
    )
    feat = db.query(MessageFeatures).filter(MessageFeatures.message_id == msg.id).first()
    risk = int((feat.risk_score or 0) * 100) if feat and feat.risk_score is not None else 0
    return ChatMessageOut(
        id=msg.id,
        created_at=msg.created_at,
        channel=msg.channel.value,
        sender=user.username,
        body=msg.body,
        kind=payload.kind,
        voice_url=payload.voice_url,
        voice_duration_sec=payload.voice_duration_sec,
        video_url=payload.video_url,
        video_duration_sec=payload.video_duration_sec,
        channel_name=payload.channel_name,
        parent_message_id=payload.parent_message_id,
        risk=risk,
        alert=risk >= 42,
        encrypted=is_encrypted,
    )

@router.post("/typing")
def set_typing(
    payload: TypingIn,
    user: User = Depends(_auth_user),
) -> dict:
    key = (payload.channel_name, user.username)
    if payload.is_typing:
        _typing_state[key] = time.time()
    else:
        _typing_state.pop(key, None)
    return {"ok": True}

@router.get("/typing", response_model=TypingOut)
def get_typing(
    channel_name: str = Query("general"),
    user: User = Depends(_auth_user),
) -> TypingOut:
    _touch_presence(db, user.username)
    now = time.time()
    users: list[str] = []
    for (ch, uname), ts in list(_typing_state.items()):
        if ts + _TYPING_TTL_SEC < now:
            _typing_state.pop((ch, uname), None)
            continue
        if ch == channel_name and uname != user.username:
            users.append(uname)
    return TypingOut(users=sorted(set(users)))

@router.post("/presence")
def set_presence(
    payload: PresenceIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    if payload.is_online:
        _touch_presence(db, user.username)
    else:
        _presence_state.pop(user.username, None)
        try:
            touch_presence(db, user.username, online=False)
        except Exception:
            pass
    return {"ok": True}

@router.get("/presence")
def get_presence(
    usernames: str = Query("", description="comma-separated usernames"),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    _touch_presence(db, user.username)
    names = [x.strip() for x in usernames.split(",") if x.strip()]
    return {"online": {name: _presence_online(db, name) for name in names}}

@router.post("/read")
def set_read(
    payload: ReadIn,
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> dict:
    key = payload.channel_name
    if payload.peer_username:
        key = f"dm:{payload.peer_username}"
    elif payload.channel_name and payload.channel_name != "dm" and not payload.channel_name.startswith("ch:"):
        key = f"ch:{payload.channel_name}"
    _read_state[(key, user.username)] = {
        "last_message_id": payload.last_message_id,
        "at": datetime.now(UTC),
    }
    try:
        persist_read_state(db, user.username, key, payload.last_message_id)
    except Exception:
        pass
    return {"ok": True}

@router.get("/read", response_model=list[ReadStateOut])
def get_read(
    channel_name: str = Query("general"),
    peer_username: str | None = Query(None),
    user: User = Depends(_auth_user),
) -> list[ReadStateOut]:
    key = f"dm:{peer_username}" if peer_username else channel_name
    out: list[ReadStateOut] = []
    for (ch, uname), data in _read_state.items():
        if ch != key or uname == user.username:
            continue
        out.append(
            ReadStateOut(
                username=uname,
                last_message_id=data["last_message_id"],
                at=data["at"],
            )
        )
    return sorted(out, key=lambda x: x.at, reverse=True)

@router.get("/security", response_model=list[SecurityEventOut])
def security_feed(
    limit: int = Query(50, ge=1, le=200),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[SecurityEventOut]:
    if user.role not in (UserRole.admin, UserRole.super_admin):
        return []
    alerts = db.query(Alert).order_by(Alert.created_at.desc()).limit(limit).all()
    return [
        SecurityEventOut(
            id=a.id,
            created_at=a.created_at,
            level=a.severity.value,
            title=a.title_ru,
            text=a.explanation_ru,
        )
        for a in alerts
    ]

@router.get("/notifications/pending", response_model=list[PendingNotificationOut])
def notifications_pending(
    since: int = Query(0, ge=0, description="unix seconds"),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> list[PendingNotificationOut]:
    since_dt = datetime.fromtimestamp(since, tz=UTC) if since else datetime.fromtimestamp(0, tz=UTC)
    out: list[PendingNotificationOut] = []
    notify_security = bool(getattr(user, "notify_security", True))
    notify_messages = bool(getattr(user, "notify_messages", False))

    if notify_security and user.role in (UserRole.admin, UserRole.super_admin):
        for a in (
            db.query(Alert)
            .filter(Alert.created_at >= since_dt)
            .order_by(Alert.created_at.asc())
            .limit(200)
            .all()
        ):
            out.append(
                PendingNotificationOut(
                    id=f"alert-{a.id}",
                    kind="security",
                    title=a.title_ru,
                    text=a.explanation_ru,
                    created_at=a.created_at,
                )
            )

    if notify_messages:
        feats = (
            db.query(MessageFeatures)
            .filter(MessageFeatures.analyzed_at >= since_dt, MessageFeatures.risk_score >= 0.42)
            .order_by(MessageFeatures.analyzed_at.asc())
            .limit(200)
            .all()
        )
        for f in feats:
            msg = db.get(Message, f.message_id)
            if not msg:
                continue
            if not _user_in_message(db, msg, user.username):
                continue
            sender = "unknown"
            if msg.sender_id:
                su = db.get(User, msg.sender_id)
                sender = su.username if su else "unknown"
            if sender == user.username:
                continue
            out.append(
                PendingNotificationOut(
                    id=f"risk-{msg.id}",
                    kind="risk",
                    title=f"Риск {int((f.risk_score or 0) * 100)}% • {sender}",
                    text="[зашифровано]" if _message_is_encrypted(msg) else msg.body[:180],
                    created_at=f.analyzed_at,
                )
            )
    return sorted(out, key=lambda x: x.created_at)

@router.post("/voice/upload", response_model=VoiceUploadOut)
async def upload_voice(
    file: UploadFile = File(...),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
    x_voice_encoding: str | None = Header(default=None, alias="X-Voice-Encoding"),
    x_voice_orig_suffix: str | None = Header(default=None, alias="X-Voice-Orig-Suffix"),
) -> VoiceUploadOut:
    _touch_presence(db, user.username)
    suffix = (x_voice_orig_suffix or Path(file.filename or "voice.m4a").suffix or ".m4a").lower()
    if not suffix.startswith("."):
        suffix = f".{suffix}"
    if suffix not in (".webm", ".ogg", ".m4a", ".wav", ".aac", ".mp3"):
        suffix = ".m4a"
    token_hex = secrets.token_hex(12)
    name = f"{int(time.time())}_{user.username}_{token_hex}{suffix}"
    target = _MEDIA_DIR / name
    raw = await file.read()
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Voice file too large (max 8MB)")

    encrypted = False
    data = raw
    if x_voice_encoding == encoding_header() and authorization and authorization.startswith("Bearer "):
        chat_token = authorization.split(" ", 1)[1].strip()
        data = unpack_voice(raw, chat_token, user.username)
        encrypted = True

    target.write_bytes(data)
    transcript: str | None = None
    stt_ok = False
    try:
        transcript, stt_ok = transcribe_voice_file(target)
    except VoiceSttError:
        pass
    return VoiceUploadOut(
        ok=True,
        voice_url=f"/media/voice/{name}",
        size=len(data),
        transcript=transcript,
        stt_ok=stt_ok,
        encrypted=encrypted,
    )

@router.post("/video/upload", response_model=VideoUploadOut)
async def upload_video(
    file: UploadFile = File(...),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
) -> VideoUploadOut:
    _touch_presence(db, user.username)
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Пустой файл")
    _target, url = await save_video_upload(
        file,
        username=user.username,
        suffix_hint=Path(file.filename or "video.mp4").suffix,
        data=raw,
    )
    return VideoUploadOut(ok=True, video_url=url, size=len(raw))

@router.post("/voice/enroll")
async def enroll_voice(
    file: UploadFile = File(...),
    user: User = Depends(_auth_user),
    db: Session = Depends(get_db),
    authorization: str | None = Header(default=None),
    x_voice_encoding: str | None = Header(default=None, alias="X-Voice-Encoding"),
    x_voice_orig_suffix: str | None = Header(default=None, alias="X-Voice-Orig-Suffix"),
) -> dict:
    suffix = (x_voice_orig_suffix or Path(file.filename or "voice.m4a").suffix or ".m4a").lower()
    if not suffix.startswith("."):
        suffix = f".{suffix}"
    name = f"enroll_{user.username}_{secrets.token_hex(6)}{suffix}"
    target = _MEDIA_DIR / name
    raw = await file.read()
    if len(raw) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Voice file too large (max 8MB)")
    data = raw
    if x_voice_encoding == encoding_header() and authorization and authorization.startswith("Bearer "):
        chat_token = authorization.split(" ", 1)[1].strip()
        data = unpack_voice(raw, chat_token, user.username)
    target.write_bytes(data)
    emb = enroll_voice_remote(target, user.username)
    if not emb:
        raise HTTPException(status_code=503, detail="Сервис голосовой верификации недоступен")
    prev = user.voice_embedding if isinstance(user.voice_embedding, list) else None
    if prev and len(prev) == len(emb):
        merged = [(float(a) + float(b)) / 2.0 for a, b in zip(prev, emb)]
    else:
        merged = emb
    user.voice_embedding = merged
    user.voice_enrolled_at = datetime.now(UTC)
    db.add(user)
    db.commit()
    return {"ok": True, "dim": len(merged), "enrolled_at": user.voice_enrolled_at.isoformat()}

@router.post("/device/register")
def device_register(
    payload: DeviceTokenIn,
    user: User = Depends(_auth_user),
) -> dict:
    register_device_token(user.username, payload.token)
    return {"ok": True}

@router.post("/device/unregister")
def device_unregister(
    payload: DeviceTokenIn,
    user: User = Depends(_auth_user),
) -> dict:
    unregister_device_token(user.username, payload.token)
    return {"ok": True}
