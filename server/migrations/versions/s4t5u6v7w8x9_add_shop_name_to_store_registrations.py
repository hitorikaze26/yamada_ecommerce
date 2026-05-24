"""Sync store_registrations columns with the SQLAlchemy model (idempotent)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import has_column, table_exists

from alembic import op
import sqlalchemy as sa

revision = "s4t5u6v7w8x9"
down_revision = "r3t4y5u6i7o8"
branch_labels = None
depends_on = None


def _add_string(table: str, column: str) -> None:
    if table_exists(table) and not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.String().with_variant(sa.VARCHAR(length=255), "mysql"),
                nullable=True,
            ),
        )


def _add_text(table: str, column: str) -> None:
    if table_exists(table) and not has_column(table, column):
        op.add_column(table, sa.Column(column, sa.Text(), nullable=True))


def upgrade():
    if not table_exists("store_registrations"):
        return

    # Original table only had store_purpose (TEXT NOT NULL) — keep nullable add for drift.
    if not has_column("store_registrations", "store_purpose"):
        op.add_column("store_registrations", sa.Column("store_purpose", sa.Text(), nullable=True))

    for column in (
        "shop_name",
        "tagline",
        "categories_json",
        "dti_path",
        "bir_tin_path",
        "business_permit_path",
    ):
        if column == "categories_json":
            _add_text("store_registrations", column)
        else:
            _add_string("store_registrations", column)


def downgrade():
    pass
