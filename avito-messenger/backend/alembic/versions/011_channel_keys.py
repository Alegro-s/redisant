"""Channel encryption keys for E2E messenger

Revision ID: 011_channel_keys
"""

from alembic import op
import sqlalchemy as sa

revision = "011_channel_keys"
down_revision = "010_user_registration_auth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "channel_keys",
        sa.Column("channel_id", sa.String(128), primary_key=True),
        sa.Column("key_b64", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("channel_keys")
