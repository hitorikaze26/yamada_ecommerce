"""Rename report_types.reporter_role to target_role (who is being reported)."""

from alembic import op
import sqlalchemy as sa


revision = "l8m9n0o1p2q3"
down_revision = "k7l8m9n0o1p2"
branch_labels = None
depends_on = None


def upgrade():
    # MySQL requires full column definition on CHANGE
    op.execute(
        "ALTER TABLE report_types CHANGE COLUMN reporter_role target_role "
        "VARCHAR(20) NOT NULL"
    )


def downgrade():
    op.execute(
        "ALTER TABLE report_types CHANGE COLUMN target_role reporter_role "
        "VARCHAR(20) NOT NULL"
    )
