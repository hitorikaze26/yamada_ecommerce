"""Add user archive and last_active_at fields."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import bool_false_default, quote_user_table

from alembic import op
import sqlalchemy as sa

revision = "m9n0o1p2q3r4"
down_revision = "l8m9n0o1p2q3"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "user",
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=bool_false_default()),
    )
    op.add_column("user", sa.Column("last_active_at", sa.DateTime(), nullable=True))
    op.add_column("user", sa.Column("archived_at", sa.DateTime(), nullable=True))
    user_table = quote_user_table()
    op.execute(
        f"UPDATE {user_table} SET last_active_at = COALESCE(updated_at, created_at) "
        "WHERE last_active_at IS NULL"
    )


def downgrade():
    op.drop_column("user", "archived_at")
    op.drop_column("user", "last_active_at")
    op.drop_column("user", "is_archived")
