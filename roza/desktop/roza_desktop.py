#!/usr/bin/env python3
"""
Roza AI для Windows — простой клиент (Python + CustomTkinter).
Настройки: %USERPROFILE%\\.roza\\desktop.json
"""
from __future__ import annotations

import json
import os
import sys
import threading
import tkinter as tk
from pathlib import Path

import customtkinter as ctk
import requests

CONFIG_PATH = Path(os.environ.get("USERPROFILE", Path.home())) / ".roza" / "desktop.json"
DEFAULT_AUTH = os.environ.get("ROZA_AUTH_URL", "https://waypointclub.ru/auth").rstrip("/")
DEFAULT_API = os.environ.get("ROZA_API_URL", "https://waypointclub.ru/roza/api").rstrip("/")


def load_config() -> dict:
    if CONFIG_PATH.is_file():
        try:
            return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    return {"auth_url": DEFAULT_AUTH, "api_url": DEFAULT_API, "token": "", "login": ""}


def save_config(cfg: dict) -> None:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")


class RozaApp(ctk.CTk):
    def __init__(self) -> None:
        super().__init__()
        ctk.set_appearance_mode("light")
        ctk.set_default_color_theme("blue")
        self.title("Roza AI")
        self.geometry("920x640")
        self.minsize(720, 520)

        self.cfg = load_config()
        self.session_id = "desktop"
        self._build_ui()

        if self.cfg.get("token"):
            self._show_chat()
        else:
            self._show_login()

    def _build_ui(self) -> None:
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(0, weight=1)
        self.container = ctk.CTkFrame(self, fg_color="transparent")
        self.container.grid(row=0, column=0, sticky="nsew", padx=16, pady=16)
        self.container.grid_columnconfigure(0, weight=1)
        self.container.grid_rowconfigure(0, weight=1)

    def _clear(self) -> None:
        for w in self.container.winfo_children():
            w.destroy()

    def _show_login(self) -> None:
        self._clear()
        frame = ctk.CTkFrame(self.container)
        frame.grid(row=0, column=0, sticky="nsew")
        frame.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(frame, text="Roza AI", font=ctk.CTkFont(size=28, weight="bold")).grid(
            row=0, column=0, pady=(24, 8)
        )
        ctk.CTkLabel(frame, text="Вход через Waypoint (realm: roza)", text_color="gray").grid(row=1, column=0)

        self.login_var = tk.StringVar(value=self.cfg.get("login", ""))
        self.pass_var = tk.StringVar()
        self.auth_url_var = tk.StringVar(value=self.cfg.get("auth_url", DEFAULT_AUTH))
        self.api_url_var = tk.StringVar(value=self.cfg.get("api_url", DEFAULT_API))

        ctk.CTkEntry(frame, placeholder_text="Email", textvariable=self.login_var, width=360).grid(
            row=2, column=0, pady=8
        )
        ctk.CTkEntry(frame, placeholder_text="Пароль", textvariable=self.pass_var, show="*", width=360).grid(
            row=3, column=0, pady=8
        )
        ctk.CTkEntry(frame, placeholder_text="Auth URL", textvariable=self.auth_url_var, width=360).grid(
            row=4, column=0, pady=4
        )
        ctk.CTkEntry(frame, placeholder_text="API URL", textvariable=self.api_url_var, width=360).grid(
            row=5, column=0, pady=4
        )

        self.login_status = ctk.CTkLabel(frame, text="", text_color="#c0392b")
        self.login_status.grid(row=6, column=0, pady=4)

        ctk.CTkButton(frame, text="Войти", width=200, command=self._do_login).grid(row=7, column=0, pady=12)

    def _do_login(self) -> None:
        self.login_status.configure(text="Вход…", text_color="gray")
        auth = self.auth_url_var.get().strip().rstrip("/")
        api = self.api_url_var.get().strip().rstrip("/")

        def work() -> None:
            try:
                r = requests.post(
                    f"{auth}/login",
                    json={"login": self.login_var.get().strip(), "password": self.pass_var.get()},
                    headers={"Content-Type": "application/json", "X-Client-Realm": "roza"},
                    timeout=30,
                )
                data = r.json() if r.content else {}
                if not r.ok:
                    raise RuntimeError(data.get("error") or f"HTTP {r.status_code}")
                token = data.get("token")
                if not token:
                    raise RuntimeError("Нет токена")
                self.cfg.update(
                    {
                        "auth_url": auth,
                        "api_url": api,
                        "token": token,
                        "login": self.login_var.get().strip(),
                    }
                )
                save_config(self.cfg)
                self.after(0, self._show_chat)
            except Exception as exc:
                self.after(0, lambda: self.login_status.configure(text=str(exc), text_color="#c0392b"))

        threading.Thread(target=work, daemon=True).start()

    def _show_chat(self) -> None:
        self._clear()
        top = ctk.CTkFrame(self.container, fg_color="transparent")
        top.grid(row=0, column=0, sticky="ew")
        top.grid_columnconfigure(1, weight=1)
        ctk.CTkLabel(top, text=f"Roza AI — {self.cfg.get('login', '')}", font=ctk.CTkFont(weight="bold")).grid(
            row=0, column=0, sticky="w"
        )
        ctk.CTkButton(top, text="Выйти", width=80, command=self._logout).grid(row=0, column=2, sticky="e")

        self.chat_log = ctk.CTkTextbox(self.container, wrap="word", state="disabled")
        self.chat_log.grid(row=1, column=0, sticky="nsew", pady=(8, 8))
        self.container.grid_rowconfigure(1, weight=1)

        bottom = ctk.CTkFrame(self.container, fg_color="transparent")
        bottom.grid(row=2, column=0, sticky="ew")
        bottom.grid_columnconfigure(0, weight=1)
        self.input_var = tk.StringVar()
        entry = ctk.CTkEntry(bottom, textvariable=self.input_var, placeholder_text="Сообщение…")
        entry.grid(row=0, column=0, sticky="ew", padx=(0, 8))
        entry.bind("<Return>", lambda _e: self._send())
        ctk.CTkButton(bottom, text="Отправить", width=120, command=self._send).grid(row=0, column=1)

        self._append("system", "Добро пожаловать в Roza AI. Задайте вопрос.")

    def _append(self, role: str, text: str) -> None:
        self.chat_log.configure(state="normal")
        prefix = "Вы: " if role == "user" else "Roza: " if role == "assistant" else ""
        self.chat_log.insert("end", f"{prefix}{text}\n\n")
        self.chat_log.see("end")
        self.chat_log.configure(state="disabled")

    def _send(self) -> None:
        msg = self.input_var.get().strip()
        if not msg:
            return
        self.input_var.set("")
        self._append("user", msg)

        api = self.cfg.get("api_url", DEFAULT_API).rstrip("/")
        token = self.cfg.get("token", "")

        def work() -> None:
            try:
                r = requests.post(
                    f"{api}/api/chat",
                    json={"text": msg, "session_id": self.session_id},
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {token}",
                    },
                    timeout=120,
                )
                if r.status_code == 401:
                    self.after(0, self._logout)
                    return
                data = r.json() if r.content else {}
                if not r.ok:
                    raise RuntimeError(data.get("detail") or data.get("error") or r.text[:200])
                reply = (data.get("reply") or data.get("answer") or "").strip() or "(пустой ответ)"
                self.after(0, lambda: self._append("assistant", reply))
            except Exception as exc:
                self.after(0, lambda: self._append("system", f"Ошибка: {exc}"))

        threading.Thread(target=work, daemon=True).start()

    def _logout(self) -> None:
        self.cfg["token"] = ""
        save_config(self.cfg)
        self._show_login()


def main() -> int:
    app = RozaApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
