"""Remove demo users, keep only superadmin."""

from sqlalchemy import delete

from app.db.models import StyleProfile, User, UserMlProfile
from app.db.session import SessionLocal

KEEP_USERNAMES = {"superadmin"}

def purge() -> None:
    db = SessionLocal()
    try:
        to_remove = db.query(User).filter(User.username.notin_(KEEP_USERNAMES)).all()
        ids = [u.id for u in to_remove]
        if not ids:
            print("[purge] nothing to remove")
            return
        db.execute(delete(StyleProfile).where(StyleProfile.user_id.in_(ids)))
        db.execute(delete(UserMlProfile).where(UserMlProfile.user_id.in_(ids)))
        for u in to_remove:
            db.delete(u)
        db.commit()
        print(f"[purge] removed {len(ids)} users, kept: {', '.join(sorted(KEEP_USERNAMES))}")
    finally:
        db.close()

if __name__ == "__main__":
    purge()
