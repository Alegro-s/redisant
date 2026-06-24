from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from app.db.models import Alert, AlertSeverity, Message, MessageChannel, User, UserRole
from app.db.session import SessionLocal
from app.schemas.message import MessageIngest
from app.services.ingest_pipeline import process_incoming_message
from app.services.messages import ingest_message

MIN_MESSAGES = 12

def _user(db, username: str) -> User | None:
    return db.query(User).filter(User.username == username).first()

def _send(
    db,
    *,
    username: str,
    body: str,
    channel_name: str = "general",
    dialog_with: str | None = None,
    impersonates: str | None = None,
) -> Message:
    meta: dict = {
        "client": "caht_flutter",
        "sent_at": datetime.now(UTC).isoformat(),
        "channel_name": channel_name,
        "kind": "text",
        "encrypted": True,
        "transport": "tls",
    }
    if dialog_with:
        meta["dialog_with"] = dialog_with
    payload = MessageIngest(
        username=username,
        channel=MessageChannel.mattermost,
        body=body,
        metadata=meta,
        impersonates_username=impersonates,
    )
    msg = ingest_message(db, payload)
    process_incoming_message(db, msg)
    return msg

def _alert(db, *, title: str, text: str, severity: AlertSeverity, hours_ago: float = 1) -> None:
    db.add(
        Alert(
            id=uuid.uuid4(),
            created_at=datetime.now(UTC) - timedelta(hours=hours_ago),
            severity=severity,
            title_ru=title,
            explanation_ru=text,
            delivered=False,
            related_message_ids=[],
        )
    )

def seed(force: bool = False) -> None:
    db = SessionLocal()
    try:
        count = db.query(Message).count()
        if count >= MIN_MESSAGES and not force:
            print(f"[seed_caht] skip: already {count} messages (use force=True)")
            return

        required = ["superadmin", "user2", "ceo", "scammer1", "scammer2"]
        for name in required:
            if not _user(db, name):
                print(f"[seed_caht] missing user {name} — run seed_users first")
                return

        now = datetime.now(UTC)

        _send(db, username="user2", body="Коллеги, доброе утро. Статус по задачам?", channel_name="general")
        _send(db, username="ceo", body="Всё по плану, отчёт к 18:00.", channel_name="general")
        _send(db, username="user2", body="Принято, жду.", channel_name="general")

        _send(db, username="user2", body="Алексей, есть минутка обсудить бюджет?", dialog_with="ceo")
        _send(db, username="ceo", body="Да, напиши цифры в личку.", dialog_with="user2")

        _send(db, username="scammer1", body="Срочно переведите аванс на счёт до 17:00.", dialog_with="user2", impersonates="ceo")
        _send(db, username="user2", body="Откуда это сообщение? Проверю с руководством.", dialog_with="scammer1")

        _send(db, username="scammer2", body="Ваш доступ к корпоративной почте заблокирован. Перейдите по ссылке.", dialog_with="ceo")
        _send(db, username="ceo", body="Подозрительно. Не открываю.", dialog_with="scammer2")

        grp = f"grp_otdel_{uuid.uuid4().hex[:6]}"
        _send(
            db,
            username="user2",
            body="Создана группа «Отдел продаж».",
            channel_name=grp,
        )
        _send(db, username="ceo", body="Добавьте сводку за неделю.", channel_name=grp)
        _send(db, username="user2", body="Скину через час.", channel_name=grp)

        if db.query(Alert).count() < 3:
            _alert(
                db,
                title="Подозрительный контакт",
                text="Пользователь scammer1 имитирует ceo. Рекомендуется не переводить средства.",
                severity=AlertSeverity.high,
                hours_ago=2,
            )
            _alert(
                db,
                title="Фишинговая ссылка",
                text="scammer2 отправил сообщение с признаками фишинга пользователю ceo.",
                severity=AlertSeverity.critical,
                hours_ago=1,
            )
            _alert(
                db,
                title="Повышенный риск L3–L5",
                text="Зафиксированы срабатывания метаданных и намерения в диалоге user2 ↔ scammer1.",
                severity=AlertSeverity.medium,
                hours_ago=0.5,
            )

        db.commit()
        total = db.query(Message).count()
        alerts = db.query(Alert).count()
        print(f"[seed_caht] OK: messages={total}, alerts={alerts}, ts={now.isoformat()}")
    finally:
        db.close()

if __name__ == "__main__":
    seed(force=False)
