"""Per-user ML profiles for external AI pipeline

Revision ID: 005
Revises: 004
Create Date: 2026-05-27

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "005"
down_revision: Union[str, None] = "004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.create_table(
        "user_ml_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True),
        sa.Column("message_count_total", sa.Integer(), server_default="0"),
        sa.Column("message_count_24h", sa.Integer(), server_default="0"),
        sa.Column("mattermost_count", sa.Integer(), server_default="0"),
        sa.Column("email_count", sa.Integer(), server_default="0"),
        sa.Column("avg_risk_score", sa.Float()),
        sa.Column("max_risk_score", sa.Float()),
        sa.Column("avg_message_length", sa.Float()),
        sa.Column("high_risk_count", sa.Integer(), server_default="0"),
        sa.Column("last_message_at", sa.DateTime(timezone=True)),
        sa.Column("last_analyzed_at", sa.DateTime(timezone=True)),
        sa.Column("analysis_status", sa.String(32), server_default="pending"),
        sa.Column("needs_reanalysis", sa.Boolean(), server_default="true"),
        sa.Column("stylistic_features", postgresql.JSONB()),
        sa.Column("model_state", postgresql.JSONB()),
        sa.Column("profile_version", sa.Integer(), server_default="1"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_user_ml_needs_reanalysis", "user_ml_profiles", ["needs_reanalysis"])

    op.execute("""
        CREATE OR REPLACE VIEW v_user_ml_summary AS
        SELECT
            u.id AS user_id,
            u.username,
            u.display_name,
            u.role::text AS role,
            u.is_blocked,
            u.email,
            u.mattermost_user_id,
            COALESCE(ump.message_count_total, 0) AS message_count_total,
            COALESCE(ump.message_count_24h, 0) AS message_count_24h,
            COALESCE(ump.mattermost_count, 0) AS mattermost_count,
            COALESCE(ump.email_count, 0) AS email_count,
            ump.avg_risk_score,
            ump.max_risk_score,
            ump.avg_message_length,
            COALESCE(ump.high_risk_count, 0) AS high_risk_count,
            ump.last_message_at,
            ump.last_analyzed_at,
            COALESCE(ump.analysis_status, 'pending') AS analysis_status,
            COALESCE(ump.needs_reanalysis, true) AS needs_reanalysis,
            ump.stylistic_features,
            ump.model_state,
            COALESCE(ump.profile_version, 1) AS profile_version,
            sp.reference_vector AS style_reference_vector,
            sp.traits AS style_traits,
            sp.sample_count AS style_sample_count
        FROM users u
        LEFT JOIN user_ml_profiles ump ON ump.user_id = u.id
        LEFT JOIN style_profiles sp ON sp.user_id = u.id
        WHERE u.role NOT IN ('admin', 'super_admin')
    """)

    op.execute("""
        INSERT INTO user_ml_profiles (id, user_id, analysis_status, needs_reanalysis)
        SELECT gen_random_uuid(), u.id, 'pending', true
        FROM users u
        WHERE u.role NOT IN ('admin', 'super_admin')
        ON CONFLICT (user_id) DO NOTHING
    """)

def downgrade() -> None:
    op.execute("DROP VIEW IF EXISTS v_user_ml_summary")
    op.drop_index("ix_user_ml_needs_reanalysis", "user_ml_profiles")
    op.drop_table("user_ml_profiles")
