from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column("users", sa.Column("notify_security", sa.Boolean(), server_default="true", nullable=False))
    op.add_column("users", sa.Column("notify_messages", sa.Boolean(), server_default="false", nullable=False))
    op.add_column("users", sa.Column("telegram_link_code", sa.String(32), nullable=True))
    op.add_column("users", sa.Column("telegram_link_expires", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "alert_cooldowns",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("sender_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("channel_key", sa.String(128), nullable=False),
        sa.Column("last_alert_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("sender_id", "channel_key", name="uq_alert_cooldown_sender_channel"),
    )

def downgrade() -> None:
    op.drop_table("alert_cooldowns")
    op.drop_column("users", "telegram_link_expires")
    op.drop_column("users", "telegram_link_code")
    op.drop_column("users", "notify_messages")
    op.drop_column("users", "notify_security")
