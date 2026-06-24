from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import (
    admin_panel_auth,
    alerts,
    chat,
    chat_account,
    chat_shield,
    dashboard,
    health,
    inference,
    integrations,
    lm_studio,
    messages,
    ml,
    ml_users,
    notifications,
    shadow_mentor,
    telegram_bot,
    webhooks,
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    from app.db.session import SessionLocal
    from app.services.alert_delivery import deliver_pending_alerts
    from app.services.pending_analysis import drain_pending_messages_background

    db = SessionLocal()
    try:
        deliver_pending_alerts(db)
    finally:
        db.close()
    drain_pending_messages_background()
    yield

app = FastAPI(
    title="AI Shield API",
    description="Backend для Linguistic DNA & Style Verifier (хакатон)",
    version="0.2.0",
    lifespan=lifespan,
)

from app.config import get_settings

settings = get_settings()
_cors = [o.strip() for o in settings.cors_origins.split(",") if o.strip()] if settings.cors_origins else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors,
    allow_credentials=_cors != ["*"],
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "X-Admin-Key",
        "X-Admin-Session",
        "X-Telegram-Bot-Api-Secret-Token",
    ],
)

app.include_router(health.router)
app.include_router(admin_panel_auth.router)
app.include_router(messages.router)
app.include_router(webhooks.router)
app.include_router(alerts.router)
app.include_router(chat.router)
app.include_router(chat_account.router)
app.include_router(chat_shield.router)
app.include_router(dashboard.router)
app.include_router(ml.router)
app.include_router(ml_users.router)
app.include_router(integrations.router)
app.include_router(inference.router)
app.include_router(lm_studio.router)
app.include_router(shadow_mentor.router)
app.include_router(notifications.router)
app.include_router(telegram_bot.router)

def _resolve_admin_dir() -> Path | None:
    for candidate in (
        Path(__file__).resolve().parent.parent.parent / "admin-panel",
        Path("/admin-panel"),
    ):
        if candidate.is_dir():
            return candidate
    return None

_admin_dir = _resolve_admin_dir()
if _admin_dir:
    app.mount("/admin", StaticFiles(directory=str(_admin_dir), html=True), name="admin-panel")

_media_dir = Path(__file__).resolve().parent.parent / "media"
if _media_dir.is_dir():
    app.mount("/media", StaticFiles(directory=str(_media_dir)), name="media")

_legal_dir = Path(__file__).resolve().parent.parent / "static" / "legal"
if _legal_dir.is_dir():
    app.mount("/legal", StaticFiles(directory=str(_legal_dir), html=True), name="legal")

@app.get("/")
def root() -> dict:
    return {
        "service": "AI Shield API",
        "docs": "/docs",
        "health": "/health",
        "admin_panel": "/admin/",
        "privacy_policy": "/legal/privacy.html",
    }
