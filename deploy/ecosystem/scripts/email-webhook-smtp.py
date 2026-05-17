#!/usr/bin/env python3
"""Webhook OTP → SMTP (для auth-api OTP_WEBHOOK_URL)."""
from __future__ import annotations

import json
import os
import smtplib
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, HTTPServer


def send_mail(to_email: str, subject: str, body: str) -> None:
    host = os.environ["SMTP_HOST"]
    port = int(os.environ.get("SMTP_PORT", "587"))
    user = os.environ["SMTP_USER"]
    password = os.environ["SMTP_PASSWORD"]
    from_addr = os.environ.get("SMTP_FROM", user)
    use_tls = os.environ.get("SMTP_TLS", "1") not in ("0", "false", "False")

    msg = EmailMessage()
    msg["From"] = from_addr
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)

    if use_tls:
        with smtplib.SMTP(host, port, timeout=30) as smtp:
            smtp.starttls()
            smtp.login(user, password)
            smtp.send_message(msg)
    else:
        with smtplib.SMTP_SSL(host, port, timeout=30) as smtp:
            smtp.login(user, password)
            smtp.send_message(msg)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        pass

    def do_POST(self) -> None:
        secret = os.environ.get("OTP_WEBHOOK_SECRET", "")
        if secret and self.headers.get("X-Nexus-Webhook-Secret") != secret:
            self.send_response(401)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        email = (data.get("to_email") or "").strip()
        code = (data.get("code") or "").strip()
        verify_url = (data.get("verify_url") or "").strip()
        login = (data.get("login") or "").strip()

        if not email or not code:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'{"ok":false,"error":"missing email or code"}')
            return

        lines = [
            f"Здравствуйте{', ' + login if login else ''}!",
            "",
            f"Код подтверждения: {code}",
        ]
        if verify_url:
            lines += ["", f"Или перейдите по ссылке: {verify_url}"]
        lines += ["", "— Waypoint / Lynx"]

        try:
            send_mail(email, "Код подтверждения", "\n".join(lines))
        except Exception as exc:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"ok": False, "error": str(exc)}).encode())
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')


def main() -> None:
    bind = os.environ.get("BIND", "0.0.0.0:8025")
    host, port = bind.rsplit(":", 1)
    HTTPServer((host, int(port)), Handler).serve_forever()


if __name__ == "__main__":
    main()
