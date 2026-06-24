"""user block fields and AI analysis status on messages

Revision ID: 002
Revises: 001
Create Date: 2026-05-27

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column("users", sa.Column("is_blocked", sa.Boolean(), server_default="false", nullable=False))
    op.add_column("users", sa.Column("block_reason", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True))

    op.add_column("messages", sa.Column("analysis_status", sa.String(32), server_default="pending", nullable=False))
    op.add_column("messages", sa.Column("analysis_source", sa.String(32), server_default="stub", nullable=False))

def downgrade() -> None:
    op.drop_column("messages", "analysis_source")
    op.drop_column("messages", "analysis_status")
    op.drop_column("users", "blocked_at")
    op.drop_column("users", "block_reason")
    op.drop_column("users", "is_blocked")
