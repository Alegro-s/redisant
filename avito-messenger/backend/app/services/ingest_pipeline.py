import logging

from sqlalchemy.orm import Session

from app.db.models import Message
from app.services.analysis import analyze_message
from app.services.channel_linker import try_link_message

logger = logging.getLogger(__name__)

def process_incoming_message(db: Session, message: Message, *, analysis_plaintext: str | None = None) -> None:
    try:
        analyze_message(db, message, plaintext=analysis_plaintext)
    except Exception:
        logger.exception("analysis failed for message %s", message.id)
        db.rollback()
        fresh = db.get(Message, message.id)
        if fresh:
            fresh.analysis_status = "error"
            db.commit()
    else:
        db.refresh(message)
    try_link_message(db, message)
