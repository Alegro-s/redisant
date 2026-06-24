"""ML / training schema for AI expert handoff

Revision ID: 004
Revises: 003
Create Date: 2026-05-27

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "004"
down_revision: Union[str, None] = "003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

label_type = postgresql.ENUM(
    "legit",
    "impersonation",
    "ai_generated",
    "phishing",
    "suspicious",
    "unknown",
    name="training_label_type",
    create_type=False,
)

def upgrade() -> None:
    op.execute(
        "CREATE TYPE training_label_type AS ENUM "
        "('legit', 'impersonation', 'ai_generated', 'phishing', 'suspicious', 'unknown')"
    )

    op.add_column("messages", sa.Column("raw_payload", postgresql.JSONB()))
    op.add_column(
        "messages",
        sa.Column("impersonated_user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL")),
    )
    op.create_index("ix_messages_sender_created", "messages", ["sender_id", "created_at"])
    op.create_index("ix_messages_analysis_status", "messages", ["analysis_status"])

    op.add_column("message_features", sa.Column("layer_hits", postgresql.JSONB()))
    op.add_column("message_features", sa.Column("model_name", sa.String(128)))
    op.add_column("message_features", sa.Column("model_version", sa.String(64)))
    op.add_column("message_features", sa.Column("embedding", postgresql.JSONB()))
    op.add_column("message_features", sa.Column("raw_ai_response", postgresql.JSONB()))
    op.add_column("message_features", sa.Column("inference_ms", sa.Integer()))

    op.create_table(
        "analysis_runs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("model_name", sa.String(128), nullable=False),
        sa.Column("model_version", sa.String(64)),
        sa.Column("analysis_source", sa.String(32), nullable=False),
        sa.Column("request_payload", postgresql.JSONB()),
        sa.Column("response_payload", postgresql.JSONB()),
        sa.Column("risk_score", sa.Float()),
        sa.Column("inference_ms", sa.Integer()),
        sa.Column("success", sa.Boolean(), server_default="true"),
        sa.Column("error_message", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_analysis_runs_message", "analysis_runs", ["message_id"])
    op.create_index("ix_analysis_runs_created", "analysis_runs", ["created_at"])

    op.create_table(
        "training_labels",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("messages.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", label_type, nullable=False),
        sa.Column("confidence", sa.Float()),
        sa.Column("labeled_by", sa.String(128), server_default="expert"),
        sa.Column("notes", sa.Text()),
        sa.Column("is_gold", sa.Boolean(), server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_training_labels_message", "training_labels", ["message_id"], unique=True)
    op.create_index("ix_training_labels_label", "training_labels", ["label"])

    op.create_table(
        "style_profile_snapshots",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reference_vector", postgresql.JSONB()),
        sa.Column("traits", postgresql.JSONB()),
        sa.Column("sample_count", sa.Integer(), server_default="0"),
        sa.Column("snapshot_reason", sa.String(64), server_default="periodic"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_style_snapshots_user", "style_profile_snapshots", ["user_id", "created_at"])

    op.create_table(
        "dataset_exports",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("format", sa.String(16), server_default="jsonl"),
        sa.Column("file_path", sa.String(512)),
        sa.Column("record_count", sa.Integer(), server_default="0"),
        sa.Column("filters", postgresql.JSONB()),
        sa.Column("created_by", sa.String(128), server_default="system"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.execute("""
        CREATE OR REPLACE VIEW v_training_samples AS
        SELECT
            m.id AS message_id,
            m.created_at AS message_at,
            m.channel::text AS channel,
            m.body AS text,
            m.raw_payload,
            m.analysis_status,
            m.analysis_source,
            m.metadata AS message_metadata,
            u.id AS sender_uuid,
            u.username AS sender_username,
            u.role::text AS sender_role,
            imp.username AS impersonated_username,
            mf.style_similarity,
            mf.ai_score,
            mf.metadata_anomaly_score,
            mf.risk_score,
            mf.feature_vector,
            mf.layer_hits,
            mf.embedding,
            mf.model_name,
            mf.model_version,
            mf.raw_ai_response,
            tl.label::text AS training_label,
            tl.confidence AS label_confidence,
            tl.labeled_by,
            tl.notes AS label_notes,
            sp.traits AS sender_style_traits,
            sp.reference_vector AS sender_reference_vector
        FROM messages m
        LEFT JOIN users u ON u.id = m.sender_id
        LEFT JOIN users imp ON imp.id = m.impersonated_user_id
        LEFT JOIN message_features mf ON mf.message_id = m.id
        LEFT JOIN training_labels tl ON tl.message_id = m.id
        LEFT JOIN style_profiles sp ON sp.user_id = m.sender_id
    """)

def downgrade() -> None:
    op.execute("DROP VIEW IF EXISTS v_training_samples")
    op.drop_table("dataset_exports")
    op.drop_index("ix_style_snapshots_user", "style_profile_snapshots")
    op.drop_table("style_profile_snapshots")
    op.drop_index("ix_training_labels_label", "training_labels")
    op.drop_index("ix_training_labels_message", "training_labels")
    op.drop_table("training_labels")
    op.drop_index("ix_analysis_runs_created", "analysis_runs")
    op.drop_index("ix_analysis_runs_message", "analysis_runs")
    op.drop_table("analysis_runs")
    op.drop_column("message_features", "inference_ms")
    op.drop_column("message_features", "raw_ai_response")
    op.drop_column("message_features", "embedding")
    op.drop_column("message_features", "model_version")
    op.drop_column("message_features", "model_name")
    op.drop_column("message_features", "layer_hits")
    op.drop_index("ix_messages_analysis_status", "messages")
    op.drop_index("ix_messages_sender_created", "messages")
    op.drop_column("messages", "impersonated_user_id")
    op.drop_column("messages", "raw_payload")
    op.execute("DROP TYPE training_label_type")
