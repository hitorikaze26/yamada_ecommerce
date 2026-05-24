"""Add shop_name column to store_registrations (idempotent)."""

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


def upgrade():
    if table_exists("store_registrations") and not has_column("store_registrations", "shop_name"):
        op.add_column(
            "store_registrations",
            sa.Column(
                "shop_name",
                sa.String().with_variant(sa.VARCHAR(length=255), "mysql"),
                nullable=True,
            ),
        )


def downgrade():
    if table_exists("store_registrations") and has_column("store_registrations", "shop_name"):
        op.drop_column("store_registrations", "shop_name")
