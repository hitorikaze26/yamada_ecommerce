"""Add user archive and last_active_at fields."""

from alembic import op
import sqlalchemy as sa

revision = "m9n0o1p2q3r4"
down_revision = "l8m9n0o1p2q3"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "user",
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default="0"),
    )
    op.add_column("user", sa.Column("last_active_at", sa.DateTime(), nullable=True))
    op.add_column("user", sa.Column("archived_at", sa.DateTime(), nullable=True))
    op.execute(
        "UPDATE user SET last_active_at = COALESCE(updated_at, created_at) "
        "WHERE last_active_at IS NULL"
    )


def downgrade():
    op.drop_column("user", "archived_at")
    op.drop_column("user", "last_active_at")
    op.drop_column("user", "is_archived")
