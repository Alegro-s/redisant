from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import get_settings

logger = logging.getLogger(__name__)

def smtp_configured() -> bool:
    s = get_settings()
    return bool(s.smtp_host and s.smtp_user and s.smtp_password)

def send_email(to: str, subject: str, body_text: str, body_html: str | None = None) -> bool:
    settings = get_settings()
    if not smtp_configured():
        logger.warning("SMTP not configured; email to %s not sent: %s", to, subject)
        return False
    from_addr = settings.smtp_from or settings.smtp_user
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to
    msg.attach(MIMEText(body_text, "plain", "utf-8"))
    if body_html:
        msg.attach(MIMEText(body_html, "html", "utf-8"))
    try:
        if settings.smtp_use_ssl:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=20) as server:
                server.login(settings.smtp_user, settings.smtp_password)
                server.sendmail(from_addr, [to], msg.as_string())
        else:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as server:
                server.starttls()
                server.login(settings.smtp_user, settings.smtp_password)
                server.sendmail(from_addr, [to], msg.as_string())
        return True
    except smtplib.SMTPException as exc:
        logger.exception("SMTP send failed: %s", exc)
        return False

def send_verification_code(to: str, code: str, *, purpose: str = "подтверждение email") -> bool:
    app = get_settings().app_display_name
    subject = f"{app}: код {purpose}"
    text = f"Ваш код: {code}\n\nКод действует 15 минут.\nЕсли вы не запрашивали письмо — проигнорируйте его."
    html = (
        f"<p>Код для <b>{purpose}</b> в {app}:</p>"
        f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px'>{code}</p>"
        f"<p style='color:#666'>Действует 15 минут.</p>"
    )
    return send_email(to, subject, text, html)
