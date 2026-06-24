"""Telegram channel + telegram_user_id on users

Revision ID: 006
Revises: 005
Create Date: 2026-05-27

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.execute("ALTER TYPE message_channel ADD VALUE IF NOT EXISTS 'telegram'")
    op.add_column("users", sa.Column("telegram_user_id", sa.String(64), nullable=True))
    op.create_index("ix_users_telegram_user_id", "users", ["telegram_user_id"], unique=True)

def downgrade() -> None:
    op.drop_index("ix_users_telegram_user_id", table_name="users")
    op.drop_column("users", "telegram_user_id")
