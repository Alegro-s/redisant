"""audit log for admin actions

Revision ID: 003
Revises: 002
Create Date: 2026-05-27

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.create_table(
        "audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("target_username", sa.String(64), nullable=False),
        sa.Column("actor_username", sa.String(64), server_default="admin_panel"),
        sa.Column("details", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("ix_audit_logs_created", "audit_logs", ["created_at"])

def downgrade() -> None:
    op.drop_index("ix_audit_logs_created", "audit_logs")
    op.drop_table("audit_logs")
