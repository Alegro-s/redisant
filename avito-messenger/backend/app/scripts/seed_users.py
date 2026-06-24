import uuid

from app.db.models import StyleProfile, User, UserMlProfile, UserRole
from app.db.session import SessionLocal
from app.services.password_auth import hash_password

SEED_USERS = [
    ("superadmin", "Супер-админ", UserRole.super_admin, "superadmin@company.local"),
]

DEFAULT_SUPERADMIN_PASSWORD = "Admin123!"

def seed() -> None:
    db = SessionLocal()
    try:
        for username, display_name, role, email in SEED_USERS:
            existing = db.query(User).filter(User.username == username).first()
            if existing:
                if not existing.password_hash:
                    existing.password_hash = hash_password(DEFAULT_SUPERADMIN_PASSWORD)
                    existing.email_verified = True
                    db.add(existing)
                continue
            user = User(
                id=uuid.uuid4(),
                username=username,
                display_name=display_name,
                email=email,
                email_verified=True,
                password_hash=hash_password(DEFAULT_SUPERADMIN_PASSWORD),
                role=role,
                user_settings={
                    "theme": "system",
                    "font_scale": 1.0,
                    "privacy": {
                        "show_email": False,
                        "show_username": True,
                        "show_display_name": True,
                        "show_last_seen": True,
                    },
                },
            )
            db.add(user)
            db.flush()
            db.add(
                StyleProfile(
                    user_id=user.id,
                    traits={"formality": 0.5},
                    reference_vector={"avg_words": 12, "politeness": 0.25, "formality": 0.5},
                    sample_count=0,
                )
            )

        db.commit()
        print(f"[seed] users ready ({len(SEED_USERS)} accounts)")
    finally:
        db.close()

if __name__ == "__main__":
    seed()
