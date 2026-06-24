"""Telegram bot linking, Shadow Mentor, chat state persistence

Revision ID: 007
Revises: 006
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "007"
down_revision: Union[str, None] = "006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column("users", sa.Column("telegram_chat_id", sa.String(64), nullable=True))
    op.add_column("users", sa.Column("telegram_notify", sa.Boolean(), server_default="true", nullable=False))
    op.create_index("ix_users_telegram_chat_id", "users", ["telegram_chat_id"], unique=True)

    op.create_table(
        "chat_read_states",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("username", sa.String(64), nullable=False),
        sa.Column("channel_key", sa.String(128), nullable=False),
        sa.Column("last_message_id", UUID(as_uuid=True), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("username", "channel_key", name="uq_chat_read_user_channel"),
    )
    op.create_index("ix_chat_read_channel", "chat_read_states", ["channel_key"])

    op.create_table(
        "chat_presence",
        sa.Column("username", sa.String(64), primary_key=True),
        sa.Column("last_seen", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("is_online", sa.Boolean(), server_default="true", nullable=False),
    )

    op.create_table(
        "shadow_mentor_campaigns",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("target_user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "impersonate_user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("message_text", sa.Text(), nullable=False),
        sa.Column("status", sa.String(32), server_default="draft", nullable=False),
        sa.Column("user_response", sa.Text(), nullable=True),
        sa.Column("fell_for_it", sa.Boolean(), nullable=True),
        sa.Column("detection_score", sa.Float(), nullable=True),
        sa.Column("explanation_ru", sa.Text(), nullable=True),
        sa.Column("traits_used", JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_shadow_mentor_target", "shadow_mentor_campaigns", ["target_user_id", "created_at"])

def downgrade() -> None:
    op.drop_index("ix_shadow_mentor_target", table_name="shadow_mentor_campaigns")
    op.drop_table("shadow_mentor_campaigns")
    op.drop_table("chat_presence")
    op.drop_index("ix_chat_read_channel", table_name="chat_read_states")
    op.drop_table("chat_read_states")
    op.drop_index("ix_users_telegram_chat_id", table_name="users")
    op.drop_column("users", "telegram_notify")
    op.drop_column("users", "telegram_chat_id")
