"""Ensure user archive and product moderation columns exist (idempotent)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import (
    bool_false_default,
    column_names,
    enum_for_create_table,
    has_column,
    is_postgresql,
    table_exists,
)

from alembic import op
import sqlalchemy as sa

revision = "q2w3e4r5t6y7"
down_revision = "p1q2r3s4t5u6"
branch_labels = None
depends_on = None


def upgrade():
    if table_exists("user"):
        if not has_column("user", "is_archived"):
            op.add_column(
                "user",
                sa.Column(
                    "is_archived",
                    sa.Boolean(),
                    nullable=False,
                    server_default=bool_false_default(),
                ),
            )
        if not has_column("user", "last_active_at"):
            op.add_column("user", sa.Column("last_active_at", sa.DateTime(), nullable=True))
        if not has_column("user", "archived_at"):
            op.add_column("user", sa.Column("archived_at", sa.DateTime(), nullable=True))

    if table_exists("products"):
        cols = column_names("products")
        if "moderation_status" not in cols:
            mod_enum = enum_for_create_table(
                "active",
                "under_review",
                "hidden",
                "removed",
                "restricted",
                name="productmoderationstatus",
            )
            status_default = (
                sa.text("'active'::productmoderationstatus")
                if is_postgresql()
                else "active"
            )
            op.add_column(
                "products",
                sa.Column(
                    "moderation_status",
                    mod_enum,
                    nullable=False,
                    server_default=status_default,
                ),
            )
        if "moderation_reason" not in cols:
            op.add_column("products", sa.Column("moderation_reason", sa.Text(), nullable=True))
        if "moderation_updated_at" not in cols:
            op.add_column(
                "products", sa.Column("moderation_updated_at", sa.DateTime(), nullable=True)
            )
        if "moderation_updated_by" not in cols:
            op.add_column(
                "products",
                sa.Column("moderation_updated_by", sa.BigInteger(), nullable=True),
            )
        if "edit_requested_at" not in cols:
            op.add_column(
                "products", sa.Column("edit_requested_at", sa.DateTime(), nullable=True)
            )
        if "edit_request_note" not in cols:
            op.add_column("products", sa.Column("edit_request_note", sa.Text(), nullable=True))

    if table_exists("store_registrations") and is_postgresql():
        op.execute(
            """
            UPDATE store_registrations
            SET request_status = CASE request_status::text
                WHEN '1' THEN 'ACCEPTED'
                WHEN '2' THEN 'REJECTED'
                WHEN '3' THEN 'PENDING'
                ELSE request_status::text
            END
            WHERE request_status::text IN ('1', '2', '3')
            """
        )


def downgrade():
    pass
