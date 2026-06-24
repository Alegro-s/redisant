"""User registration auth and preferences

Revision ID: 010_user_registration_auth
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "010_user_registration_auth"
down_revision = "009"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column("users", sa.Column("password_hash", sa.String(255), nullable=True))
    op.add_column("users", sa.Column("email_verified", sa.Boolean(), server_default="false", nullable=False))
    op.add_column("users", sa.Column("user_settings", JSONB(), server_default="{}", nullable=False))

def downgrade() -> None:
    op.drop_column("users", "user_settings")
    op.drop_column("users", "email_verified")
    op.drop_column("users", "password_hash")
