"""Product moderation, refund dispute fields, moderation logs."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import (
    bool_false_default,
    column_names,
    is_mysql,
    is_postgresql,
    pg_add_enum_value,
    table_exists,
)

from alembic import op
import sqlalchemy as sa

revision = "n0o1p2q3r4s5"
down_revision = "m9n0o1p2q3r4"
branch_labels = None
depends_on = None

_MODERATION_VALUES = (
    "active",
    "under_review",
    "hidden",
    "removed",
    "restricted",
)
_REFUND_STATUS_NEW_VALUES = ("disputed", "evidence_requested", "admin_review")


def _add_moderation_status_column() -> None:
    if "moderation_status" in column_names("products"):
        return

    if is_postgresql():
        mod_enum = sa.Enum(*_MODERATION_VALUES, name="productmoderationstatus")
        mod_enum.create(op.get_bind(), checkfirst=True)
        op.add_column(
            "products",
            sa.Column(
                "moderation_status",
                mod_enum,
                nullable=False,
                server_default=sa.text("'active'::productmoderationstatus"),
            ),
        )
        return

    op.add_column(
        "products",
        sa.Column(
            "moderation_status",
            sa.Enum(*_MODERATION_VALUES, name="productmoderationstatus"),
            nullable=False,
            server_default="active",
        ),
    )


def _extend_refund_status_enum() -> None:
    if not table_exists("refund_requests"):
        return

    if is_postgresql():
        for value in _REFUND_STATUS_NEW_VALUES:
            pg_add_enum_value("refundstatus", value)
        return

    if is_mysql():
        op.execute(
            "ALTER TABLE refund_requests MODIFY COLUMN status "
            "ENUM('requested','approved_by_seller','rejected_by_seller','approved','rejected',"
            "'disputed','evidence_requested','admin_review') NOT NULL"
        )


def upgrade():
    _add_moderation_status_column()
    op.add_column("products", sa.Column("moderation_reason", sa.Text(), nullable=True))
    op.add_column("products", sa.Column("moderation_updated_at", sa.DateTime(), nullable=True))
    op.add_column("products", sa.Column("moderation_updated_by", sa.BigInteger(), nullable=True))
    op.add_column("products", sa.Column("edit_requested_at", sa.DateTime(), nullable=True))
    op.add_column("products", sa.Column("edit_request_note", sa.Text(), nullable=True))
    op.create_foreign_key(
        "fk_products_moderation_updated_by_user",
        "products",
        "user",
        ["moderation_updated_by"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "product_moderation_logs",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column(
            "product_id",
            sa.BigInteger(),
            sa.ForeignKey("products.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "admin_id",
            sa.BigInteger(),
            sa.ForeignKey("user.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )

    if table_exists("refund_requests"):
        refund_cols = column_names("refund_requests")
        if "buyer_evidence_note" not in refund_cols:
            op.add_column("refund_requests", sa.Column("buyer_evidence_note", sa.Text(), nullable=True))
        if "seller_response_note" not in refund_cols:
            op.add_column("refund_requests", sa.Column("seller_response_note", sa.Text(), nullable=True))
        if "admin_note" not in refund_cols:
            op.add_column("refund_requests", sa.Column("admin_note", sa.Text(), nullable=True))
        if "evidence_paths_json" not in refund_cols:
            op.add_column("refund_requests", sa.Column("evidence_paths_json", sa.Text(), nullable=True))
        if "disputed_at" not in refund_cols:
            op.add_column("refund_requests", sa.Column("disputed_at", sa.DateTime(), nullable=True))
        if "evidence_requested_at" not in refund_cols:
            op.add_column(
                "refund_requests", sa.Column("evidence_requested_at", sa.DateTime(), nullable=True)
            )
        if "frozen_at" not in refund_cols:
            op.add_column("refund_requests", sa.Column("frozen_at", sa.DateTime(), nullable=True))
        if "is_transaction_frozen" not in refund_cols:
            op.add_column(
                "refund_requests",
                sa.Column(
                    "is_transaction_frozen",
                    sa.Boolean(),
                    nullable=False,
                    server_default=bool_false_default(),
                ),
            )

    _extend_refund_status_enum()


def downgrade():
    if table_exists("refund_requests") and is_mysql():
        op.execute(
            "ALTER TABLE refund_requests MODIFY COLUMN status "
            "ENUM('requested','approved_by_seller','rejected_by_seller','approved','rejected') NOT NULL"
        )

    if table_exists("refund_requests"):
        for col in (
            "is_transaction_frozen",
            "frozen_at",
            "evidence_requested_at",
            "disputed_at",
            "evidence_paths_json",
            "admin_note",
            "seller_response_note",
            "buyer_evidence_note",
        ):
            if col in column_names("refund_requests"):
                op.drop_column("refund_requests", col)

    op.drop_table("product_moderation_logs")
    if table_exists("products"):
        op.drop_constraint("fk_products_moderation_updated_by_user", "products", type_="foreignkey")
        for col in (
            "edit_request_note",
            "edit_requested_at",
            "moderation_updated_by",
            "moderation_updated_at",
            "moderation_reason",
            "moderation_status",
        ):
            if col in column_names("products"):
                op.drop_column("products", col)
