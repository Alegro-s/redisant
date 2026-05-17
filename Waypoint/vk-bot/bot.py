"""
NEXUS — бот ВК для привязки уведомлений и «живого» меню.

Интерактив в ВК бывает так:
1) Клавиатура под полем ввода (reply) — кнопки как текст; бот видит label как сообщение.
2) Inline + callback — кнопки под сообщением; приходит событие message_event (нужно ответить sendMessageEventAnswer).

«Меню» в настройках группы (Сообщество → Сообщения) — отдельная статическая штука, не заменяет клавиатуру бота.

Переменные окружения см. config.example.env
"""
from __future__ import annotations

import json
import os
import random
import re
import sys
import time
from typing import Any, Optional

import requests

VK_TOKEN = os.environ.get("VK_GROUP_TOKEN", "").strip()
NEXUS = os.environ.get("NEXUS_SERVER", "http://127.0.0.1:8080").rstrip("/")
SECRET = os.environ.get("VK_BOT_SECRET", "").strip()
GROUP_ID = int(os.environ.get("VK_GROUP_ID", "0") or 0)
NEXUS_PUBLIC_URL = os.environ.get("NEXUS_PUBLIC_URL", "https://vk.com").strip()


def vk_api(method: str, **params: Any) -> Any:
    params["access_token"] = VK_TOKEN
    params["v"] = "5.199"
    r = requests.post(f"https://api.vk.com/method/{method}", data=params, timeout=20)
    r.raise_for_status()
    j = r.json()
    if "error" in j:
        raise RuntimeError(str(j["error"]))
    return j["response"]


def _rand_id() -> int:
    return random.randint(1, 2_147_000_000)


def keyboard_reply_main() -> str:
    """Постоянная клавиатура (нижняя панель)."""
    kb = {
        "one_time": False,
        "inline": False,
        "buttons": [
            [
                {
                    "action": {"type": "text", "label": "Привязать код", "payload": ""},
                    "color": "primary",
                }
            ],
            [
                {
                    "action": {"type": "text", "label": "Помощь", "payload": ""},
                    "color": "secondary",
                }
            ],
            [
                {
                    "action": {
                        "type": "open_link",
                        "link": NEXUS_PUBLIC_URL,
                        "label": "Открыть сайт",
                    }
                }
            ],
        ],
    }
    return json.dumps(kb, ensure_ascii=False)


def keyboard_inline_bind_hint() -> str:
    """Inline-кнопки под одним сообщением (callback)."""
    kb = {
        "inline": True,
        "buttons": [
            [
                {
                    "action": {
                        "type": "callback",
                        "label": "Где взять код?",
                        "payload": json.dumps({"cmd": "help_bind"}),
                    },
                    "color": "secondary",
                },
                {
                    "action": {
                        "type": "callback",
                        "label": "Пример команды",
                        "payload": json.dumps({"cmd": "example"}),
                    },
                    "color": "primary",
                },
            ]
        ],
    }
    return json.dumps(kb, ensure_ascii=False)


BIND_RE = re.compile(r"привязать\s+(NX[a-f0-9]{8,40})", re.I)
HELP_WORDS = frozenset(
    {"помощь", "help", "start", "начать", "меню", "привязать код"}
)


def send(peer_id: int, text: str, keyboard: Optional[str] = None) -> None:
    kw: dict[str, Any] = {
        "peer_id": peer_id,
        "message": text,
        "random_id": _rand_id(),
    }
    if keyboard:
        kw["keyboard"] = keyboard
    vk_api("messages.send", **kw)


def send_event_answer(
    event_id: str,
    user_id: int,
    peer_id: int,
    *,
    snackbar: Optional[str] = None,
) -> None:
    """Ответ на нажатие callback (обязателен, иначе у пользователя «крутилка»)."""
    payload: dict[str, Any] = {"type": "show_snackbar", "text": snackbar or "Готово"}
    vk_api(
        "messages.sendMessageEventAnswer",
        event_id=event_id,
        user_id=user_id,
        peer_id=peer_id,
        response=json.dumps(payload, ensure_ascii=False),
    )


def do_bind(peer_id: int, code: str) -> str:
    try:
        br = requests.post(
            f"{NEXUS}/integrations/vk/bind",
            json={"secret": SECRET, "code": code, "peer_id": peer_id},
            timeout=15,
        )
        if br.ok:
            return (
                "Аккаунт привязан. Уведомления об ошибках в логах (ingest) будут приходить сюда.\n"
                "Ключ метрик: в приложении NEXUS → Профиль."
            )
        return f"Ошибка привязки: HTTP {br.status_code}\n{br.text[:400]}"
    except Exception as e:
        return f"Сеть / сервер: {e}"


def help_text() -> str:
    return (
        "Как привязать NEXUS:\n"
        "1) Войдите в приложение NEXUS → Профиль → «Код для бота ВК».\n"
        "2) Напишите сюда: привязать NXxxxxxxxx\n"
        "   или нажмите «Привязать код» и отправьте код одним сообщением.\n\n"
        "Метрики с вашего сервера: POST …/api/waypoint/ingest с заголовком X-API-Key."
    )


def handle_callback(obj: dict[str, Any]) -> None:
    ev = obj.get("event_id")
    user_id = int(obj["user_id"])
    peer_id = int(obj["peer_id"])
    raw = obj.get("payload")
    if not ev or raw is None:
        return
    try:
        pl = json.loads(raw) if isinstance(raw, str) else raw
    except json.JSONDecodeError:
        pl = {}
    cmd = pl.get("cmd") if isinstance(pl, dict) else None

    if cmd == "help_bind":
        send_event_answer(
            ev, user_id, peer_id, snackbar="Код в NEXUS → Профиль → Код для бота ВК"
        )
        send(peer_id, help_text(), keyboard=keyboard_inline_bind_hint())
    elif cmd == "example":
        send_event_answer(ev, user_id, peer_id, snackbar="Отправьте такое сообщение боту")
        send(peer_id, "Пример:\nпривязать NXa1b2c3d4", keyboard=keyboard_reply_main())
    else:
        send_event_answer(ev, user_id, peer_id, snackbar="Неизвестная команда")


def handle_incoming_message(msg: dict[str, Any]) -> None:
    peer_id = int(msg["peer_id"])
    text = (msg.get("text") or "").strip()
    if msg.get("out") == 1:
        return

    low = text.lower()

    if not text or low in HELP_WORDS or low == "привязать код":
        send(
            peer_id,
            "Привет! Это бот NEXUS для уведомлений.\n\n" + help_text(),
            keyboard=keyboard_reply_main(),
        )
        send(
            peer_id,
            "Быстрые кнопки (inline):",
            keyboard=keyboard_inline_bind_hint(),
        )
        return

    m = BIND_RE.search(text)
    if m:
        code = m.group(1)
        reply = do_bind(peer_id, code)
        send(peer_id, reply, keyboard=keyboard_reply_main())
        return

    send(
        peer_id,
        "Не понял. Напишите «Помощь» или «привязать NX…»",
        keyboard=keyboard_reply_main(),
    )


def parse_update(upd: Any) -> None:
    if isinstance(upd, dict):
        t = upd.get("type")
        if t == "message_new":
            inner = upd.get("object") or {}
            message = inner.get("message") or inner
            handle_incoming_message(message)
        elif t == "message_event":
            handle_callback(upd.get("object") or {})
        return

    if isinstance(upd, list) and len(upd) >= 6 and upd[0] == 4:
        peer_id = int(upd[3])
        text = (upd[5] or "").strip() if isinstance(upd[5], str) else ""
        handle_incoming_message({"peer_id": peer_id, "text": text, "out": 0})
        return


def main() -> None:
    if not VK_TOKEN or not SECRET or not GROUP_ID:
        print(
            "Задайте VK_GROUP_TOKEN, VK_BOT_SECRET, VK_GROUP_ID (см. config.example.env)",
            file=sys.stderr,
        )
        sys.exit(1)

    resp = vk_api("groups.getLongPollServer", group_id=GROUP_ID)
    server = resp["server"]
    if not server.startswith("http"):
        server = "https://" + server
    key, ts = resp["key"], resp["ts"]
    print(f"Long Poll: group={GROUP_ID}, server OK", flush=True)
    print("Убедитесь в группе: Управление → Настройки → Сообщения → Боты → Long Poll API включён.", flush=True)

    fail_streak = 0
    while True:
        try:
            r = requests.get(
                server,
                params={"act": "a_check", "key": key, "ts": ts, "wait": 25},
                timeout=40,
            )
            r.raise_for_status()
            data = r.json()
            failed = data.get("failed")
            if failed is not None:
                if int(failed) in (1, 2, 3):
                    resp = vk_api("groups.getLongPollServer", group_id=GROUP_ID)
                    server = resp["server"]
                    if not server.startswith("http"):
                        server = "https://" + server
                    key, ts = resp["key"], resp["ts"]
                    print("Long Poll переподключён (failed)", flush=True)
                continue

            ts = data.get("ts", ts)
            for upd in data.get("updates", []):
                try:
                    parse_update(upd)
                except Exception as e:
                    print("update error:", e, upd, flush=True)
            fail_streak = 0
        except Exception as e:
            fail_streak += 1
            print("poll error:", e, flush=True)
            time.sleep(min(30, 2 + fail_streak))


if __name__ == "__main__":
    main()
