from sqlalchemy.orm import Session

from app.db.models import Alert, Message, User
from app.services.mattermost_notify import post_alert_to_mattermost
from app.services.push_notify import push_alert_to_user
from app.services.telegram_bot import notify_subscribers_alert, notify_superadmin_analyst_alert
from app.services.telegram_notify import send_alert_to_telegram

def deliver_alert(db: Session, alert: Alert, sender: User | None = None) -> None:
    sender_name = sender.display_name if sender else None
    mm_ok = post_alert_to_mattermost(db, alert, sender_name=sender_name)
    tg_ok = send_alert_to_telegram(alert, sender_name)
    tg_users = notify_subscribers_alert(db, alert, sender_name)
    analyst_tg = notify_superadmin_analyst_alert(db, alert, sender_name)
    if sender:
        push_alert_to_user(sender.username, alert)
    if mm_ok or tg_ok or tg_users > 0 or analyst_tg > 0:
        alert.delivered = True
        db.commit()

def deliver_pending_alerts(db: Session) -> int:
    pending = db.query(Alert).filter(Alert.delivered.is_(False)).order_by(Alert.created_at.asc()).limit(20).all()
    count = 0
    for alert in pending:
        sender = None
        if alert.related_message_ids:
            msg = db.get(Message, alert.related_message_ids[0])
            if msg and msg.sender_id:
                sender = db.get(User, msg.sender_id)
        sender_name = sender.display_name if sender else None
        mm_ok = post_alert_to_mattermost(db, alert, sender_name=sender_name)
        tg_ok = send_alert_to_telegram(alert, sender_name)
        tg_users = notify_subscribers_alert(db, alert, sender_name)
        analyst_tg = notify_superadmin_analyst_alert(db, alert, sender_name)
        if sender:
            push_alert_to_user(sender.username, alert)
        if mm_ok or tg_ok or tg_users > 0 or analyst_tg > 0:
            alert.delivered = True
            count += 1
    if count:
        db.commit()
    return count
