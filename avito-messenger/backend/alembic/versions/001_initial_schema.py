"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-05-26

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

user_role = postgresql.ENUM("super_admin", "admin", "user", "scammer", name="user_role", create_type=False)
message_channel = postgresql.ENUM("mattermost", "email", name="message_channel", create_type=False)
alert_severity = postgresql.ENUM("low", "medium", "high", "critical", name="alert_severity", create_type=False)

def upgrade() -> None:
    op.execute("CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'user', 'scammer')")
    op.execute("CREATE TYPE message_channel AS ENUM ('mattermost', 'email')")
    op.execute("CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical')")

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("username", sa.String(64), nullable=False, unique=True),
        sa.Column("display_name", sa.String(128), nullable=False),
        sa.Column("email", sa.String(255), unique=True),
        sa.Column("role", user_role, nullable=False),
        sa.Column("mattermost_user_id", sa.String(64), unique=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "style_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True),
        sa.Column("reference_vector", postgresql.JSONB()),
        sa.Column("traits", postgresql.JSONB()),
        sa.Column("sample_count", sa.Integer(), server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("sender_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("channel", message_channel, nullable=False),
        sa.Column("external_id", sa.String(128)),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("metadata", postgresql.JSONB()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_messages_channel_created", "messages", ["channel", "created_at"])

    op.create_table(
        "message_features",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="CASCADE"), unique=True),
        sa.Column("feature_vector", postgresql.JSONB()),
        sa.Column("style_similarity", sa.Float()),
        sa.Column("ai_score", sa.Float()),
        sa.Column("metadata_anomaly_score", sa.Float()),
        sa.Column("risk_score", sa.Float()),
        sa.Column("analyzed_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "channel_links",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id_a", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="CASCADE")),
        sa.Column("message_id_b", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="CASCADE")),
        sa.Column("link_score", sa.Float(), nullable=False),
        sa.Column("reason_ru", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "alerts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("severity", alert_severity, nullable=False),
        sa.Column("alert_type", sa.String(64), nullable=False),
        sa.Column("title_ru", sa.String(255), nullable=False),
        sa.Column("explanation_ru", sa.Text(), nullable=False),
        sa.Column("related_message_ids", postgresql.ARRAY(postgresql.UUID(as_uuid=True))),
        sa.Column("target_user_ids", postgresql.ARRAY(postgresql.UUID(as_uuid=True))),
        sa.Column("delivered", sa.Boolean(), server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

def downgrade() -> None:
    op.drop_table("alerts")
    op.drop_table("channel_links")
    op.drop_table("message_features")
    op.drop_index("ix_messages_channel_created", "messages")
    op.drop_table("messages")
    op.drop_table("style_profiles")
    op.drop_table("users")
    op.execute("DROP TYPE alert_severity")
    op.execute("DROP TYPE message_channel")
    op.execute("DROP TYPE user_role")
