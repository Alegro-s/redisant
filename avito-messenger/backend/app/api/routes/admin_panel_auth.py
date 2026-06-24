from __future__ import annotations

import json
import time

from fastapi import APIRouter, Depends, Header, Query, Request
from fastapi.responses import HTMLResponse, Response
from pydantic import BaseModel, Field

from app.services.admin_panel_auth import (
    _qr_challenges,
    login_password,
    qr_confirm,
    qr_poll,
    qr_start,
    verify_admin_key_header,
    webauthn_login,
    webauthn_register,
    webauthn_status,
)
from app.services.qr_svg import qr_svg_markup

router = APIRouter(prefix="/api/admin/auth", tags=["admin-auth"])

def _require_key(x_admin_key: str | None = Header(default=None, alias="X-Admin-Key")) -> None:
    verify_admin_key_header(x_admin_key)

class PasswordLoginIn(BaseModel):
    username: str = Field(..., min_length=1, max_length=64)
    password: str = Field(..., min_length=1, max_length=128)

class WebAuthnRegisterIn(BaseModel):
    credential_id: str = Field(..., min_length=8)
    public_key: str = Field(..., min_length=8)
    label: str = "admin"

class WebAuthnLoginIn(BaseModel):
    credential_id: str = Field(..., min_length=8)

@router.post("/login", dependencies=[Depends(_require_key)])
def auth_login(body: PasswordLoginIn) -> dict:
    return login_password(body.username, body.password)

@router.get("/webauthn/status", dependencies=[Depends(_require_key)])
def auth_webauthn_status() -> dict:
    return webauthn_status()

@router.post("/webauthn/register", dependencies=[Depends(_require_key)])
def auth_webauthn_register(body: WebAuthnRegisterIn) -> dict:
    return webauthn_register(body.credential_id, body.public_key, body.label)

@router.post("/webauthn/login", dependencies=[Depends(_require_key)])
def auth_webauthn_login(body: WebAuthnLoginIn) -> dict:
    return webauthn_login(body.credential_id)

@router.post("/qr/start", dependencies=[Depends(_require_key)])
def auth_qr_start(request: Request) -> dict:
    base = str(request.base_url).rstrip("/")
    return qr_start(public_base=base)

@router.get("/qr/svg/{challenge}")
def auth_qr_svg(challenge: str) -> Response:
    entry = _qr_challenges.get(challenge)
    if not entry or entry.get("exp", 0) < time.time():
        return Response(status_code=404, content="QR expired")
    url = entry.get("confirm_url") or ""
    try:
        svg = qr_svg_markup(url)
    except RuntimeError:
        return Response(status_code=503, content="QR generator unavailable")
    return Response(content=svg, media_type="image/svg+xml")

@router.get("/qr/poll/{challenge}", dependencies=[Depends(_require_key)])
def auth_qr_poll(challenge: str) -> dict:
    return qr_poll(challenge)

@router.post("/qr/confirm")
def auth_qr_confirm(challenge: str = Query(..., min_length=8)) -> dict:
    return qr_confirm(challenge)

@router.get("/qr/confirm-page", response_class=HTMLResponse)
def auth_qr_confirm_page(challenge: str = Query(..., min_length=8)) -> str:
    entry = _qr_challenges.get(challenge)
    expired = entry is not None and entry["exp"] < time.time()
    missing = entry is None
    if missing or expired:
        title = "Ссылка недействительна"
        msg = "QR-код истёк. Вернитесь на компьютер и обновите QR."
        color = "#d93025"
        show_btn = False
    else:
        title = "Подтверждение входа"
        msg = "Подтвердите вход отпечатком или Face ID на этом устройстве."
        color = "#141414"
        show_btn = True
    btn_block = ""
    if show_btn:
        btn_block = f"""
        <button type="button" id="btn-confirm" class="btn">Подтвердить отпечатком</button>
        <p class="sub" id="status"></p>
        <script>
        const challenge = {json.dumps(challenge)};
        async function biometricGate() {{
          if (!window.PublicKeyCredential) return true;
          const ok = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable?.();
          if (!ok) return true;
          const ch = crypto.getRandomValues(new Uint8Array(32));
          try {{
            await navigator.credentials.create({{
              publicKey: {{
                challenge: ch,
                rp: {{ name: "Neural Trust" }},
                user: {{ id: ch.slice(0, 16), name: "admin", displayName: "Admin" }},
                pubKeyCredParams: [{{ alg: -7, type: "public-key" }}],
                authenticatorSelection: {{ authenticatorAttachment: "platform", userVerification: "required" }},
                timeout: 60000,
              }},
            }});
            return true;
          }} catch (e) {{
            return false;
          }}
        }}
        document.getElementById("btn-confirm").onclick = async () => {{
          const st = document.getElementById("status");
          const btn = document.getElementById("btn-confirm");
          btn.disabled = true;
          st.textContent = "Ожидание отпечатка…";
          const bio = await biometricGate();
          if (!bio) {{
            st.textContent = "Отменено или биометрия недоступна";
            btn.disabled = false;
            return;
          }}
          st.textContent = "Подтверждение…";
          try {{
            const r = await fetch("/api/admin/auth/qr/confirm?challenge=" + encodeURIComponent(challenge), {{ method: "POST" }});
            if (!r.ok) throw new Error("Ошибка");
            document.querySelector(".card").innerHTML = "<h1 style=\\"color:#1e8e3e\\">Готово</h1><p>Вход подтверждён. Вернитесь на компьютер.</p>";
          }} catch (e) {{
            st.textContent = "Не удалось подтвердить. Обновите QR на компьютере.";
            btn.disabled = false;
          }}
        }};
        </script>"""
    return f"""<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>{title}</title>
<style>
body{{font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#141414;color:#f4f4f0}}
.card{{background:#fff;color:#141414;padding:32px 28px;border-radius:24px;box-shadow:0 16px 48px rgba(0,0,0,.4);max-width:360px;text-align:center}}
h1{{color:{color};font-size:20px;margin:0 0 12px}}
p{{margin:0 0 16px;line-height:1.5;color:#6b6b66;font-size:14px}}
.btn{{width:100%;height:48px;border:none;border-radius:999px;background:#d4ff58;color:#141414;font-size:15px;font-weight:600;cursor:pointer}}
.btn:disabled{{opacity:.6;cursor:wait}}
.sub{{font-size:13px;margin-top:12px;color:#6b6b66}}
</style></head><body><div class="card"><h1>{title}</h1><p>{msg}</p>{btn_block}</div></body></html>"""
