from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision: str = "008"
down_revision: Union[str, None] = "007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column("users", sa.Column("voice_embedding", JSONB, nullable=True))
    op.add_column("users", sa.Column("voice_enrolled_at", sa.DateTime(timezone=True), nullable=True))

def downgrade() -> None:
    op.drop_column("users", "voice_enrolled_at")
    op.drop_column("users", "voice_embedding")
