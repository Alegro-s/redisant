from __future__ import annotations

import os
import socket
import threading
import time
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from roza.config import Settings


def _pick_loopback_port() -> int:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", 0))
    port = int(s.getsockname()[1])
    s.close()
    return port


def _wait_port_open(port: int, timeout: float = 12.0) -> None:
    deadline = time.time() + timeout
    last: str | None = None
    while time.time() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.25):
                return
        except OSError as e:
            last = str(e)
            time.sleep(0.04)
    msg = f"Порт {port} не открылся вовремя."
    if last:
        msg += f" ({last})"
    raise RuntimeError(msg)


def run_desktop_window(settings: Settings) -> None:
    """Полный Roza на десктопе: локальный FastAPI + то же SPA, что и у `roza web` (чат, студия, настройки, API)."""
    try:
        import webview
    except ImportError as e:
        raise RuntimeError(
            'Для окна на рабочем столе: pip install pywebview  или  pip install -e ".[desktop]"\n'
            "На Windows обычно нужен WebView2 Runtime."
        ) from e

    import uvicorn

    # Фронт/плагины могут проверять режим «встроенного» приложения.
    os.environ.setdefault("ROZA_DESKTOP", "1")

    from roza.web.app import create_app

    port = _pick_loopback_port()
    url = f"http://127.0.0.1:{port}/"

    config = uvicorn.Config(
        create_app(),
        host="127.0.0.1",
        port=port,
        log_level="error",
        access_log=False,
        timeout_keep_alive=30,
    )
    server = uvicorn.Server(config)

    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()
    _wait_port_open(port)

    title = settings.desktop_title or settings.assistant_name
    fl = settings.desktop_frameless
    w = max(380, settings.desktop_width)
    h = max(520, settings.desktop_height)
    base = url.rstrip("/")

    print(
        "Roza — полный десктоп: чат, Студия (датасеты/обучение), настройки, аналитика и те же REST API, что у `roza web`.",
        flush=True,
    )
    print(f"Локальный UI: {base}/  (закройте окно — процесс завершится)", flush=True)

    def _win(t: str, u: str, width: int, height: int, x: int | None = None) -> None:
        kw: dict = {
            "title": t,
            "url": u,
            "width": width,
            "height": height,
            "resizable": True,
        }
        if settings.desktop_maximized:
            kw["maximized"] = True
        if fl:
            kw["frameless"] = True
            kw["easy_drag"] = True
        if x is not None:
            kw["x"] = x
            kw["y"] = 48
        try:
            webview.create_window(**kw)
        except TypeError:
            kw.pop("x", None)
            kw.pop("y", None)
            kw.pop("frameless", None)
            kw.pop("easy_drag", None)
            kw.pop("maximized", None)
            webview.create_window(
                kw["title"],
                kw["url"],
                width=kw["width"],
                height=kw["height"],
                resizable=True,
            )

    if settings.desktop_dual_window:
        _win(f"{title} — диалог", f"{base}/", w, h)
        _win(
            f"{title} — студия",
            f"{base}/studio",
            max(520, min(900, w + 120)),
            h,
            x=72,
        )
    else:
        _win(title, url, w, h)
    webview.start()
