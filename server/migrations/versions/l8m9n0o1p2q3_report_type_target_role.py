"""Rename report_types.reporter_role to target_role (who is being reported)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import is_postgresql, is_mysql, pg_rename_column, column_names

from alembic import op


revision = "l8m9n0o1p2q3"
down_revision = "k7l8m9n0o1p2"
branch_labels = None
depends_on = None


def upgrade():
    cols = column_names("report_types")
    if "reporter_role" not in cols or "target_role" in cols:
        return

    if is_postgresql():
        pg_rename_column("report_types", "reporter_role", "target_role")
        return

    if is_mysql():
        op.execute(
            "ALTER TABLE report_types CHANGE COLUMN reporter_role target_role "
            "VARCHAR(20) NOT NULL"
        )


def downgrade():
    cols = column_names("report_types")
    if "target_role" not in cols or "reporter_role" in cols:
        return

    if is_postgresql():
        pg_rename_column("report_types", "target_role", "reporter_role")
        return

    if is_mysql():
        op.execute(
            "ALTER TABLE report_types CHANGE COLUMN target_role reporter_role "
            "VARCHAR(20) NOT NULL"
        )
