"""Ensure products table matches Product SQLAlchemy model (idempotent)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import (
    bool_false_default,
    bool_true_default,
    column_names,
    enum_for_create_table,
    has_column,
    is_postgresql,
    pg_add_enum_value,
    table_exists,
)

from alembic import op
import sqlalchemy as sa

revision = "t5u6v7w8x9y0"
down_revision = "s4t5u6v7w8x9"
branch_labels = None
depends_on = None

_MODERATION_VALUES = (
    "active",
    "under_review",
    "hidden",
    "removed",
    "restricted",
)


def _add_bool(table: str, column: str, *, default_true: bool = False) -> None:
    if not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.Boolean(),
                nullable=False,
                server_default=bool_true_default() if default_true else bool_false_default(),
            ),
        )


def _add_float(table: str, column: str, *, default: str | None = None) -> None:
    if not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.Float(),
                nullable=True,
                server_default=default,
            ),
        )


def _add_int(table: str, column: str, *, default: str | None = None) -> None:
    if not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.Integer(),
                nullable=True,
                server_default=default,
            ),
        )


def _add_string(table: str, column: str, *, length: int = 255) -> None:
    if not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.String().with_variant(sa.VARCHAR(length=length), "mysql"),
                nullable=True,
            ),
        )


def _add_text(table: str, column: str) -> None:
    if not has_column(table, column):
        op.add_column(table, sa.Column(column, sa.Text(), nullable=True))


def _ensure_moderation_columns() -> None:
    if not table_exists("products"):
        return

    cols = column_names("products")
    if "moderation_status" not in cols:
        mod_enum = enum_for_create_table(
            *_MODERATION_VALUES, name="productmoderationstatus"
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
    elif is_postgresql():
        for value in _MODERATION_VALUES:
            pg_add_enum_value("productmoderationstatus", value)

    for column in (
        "moderation_reason",
        "moderation_updated_at",
        "moderation_updated_by",
        "edit_requested_at",
        "edit_request_note",
    ):
        if not has_column("products", column):
            if column == "moderation_updated_by":
                op.add_column(
                    "products",
                    sa.Column(column, sa.BigInteger(), nullable=True),
                )
            elif column.endswith("_at"):
                op.add_column(
                    "products", sa.Column(column, sa.DateTime(), nullable=True)
                )
            else:
                _add_text("products", column)


def upgrade():
    if not table_exists("products"):
        return

    _ensure_moderation_columns()

    _add_bool("products", "is_live", default_true=True)
    _add_text("products", "image_url")
    _add_float("products", "cost_price", default="0")
    _add_float("products", "sale_price")
    _add_int("products", "low_stock_threshold")
    _add_float("products", "rating", default="0")
    _add_int("products", "review_count", default="0")
    _add_string("products", "subcategory", length=100)
    _add_string("products", "brand", length=100)
    _add_text("products", "tags_json")
    _add_string("products", "product_condition", length=50)
    _add_float("products", "weight_kg")
    _add_string("products", "material", length=100)
    _add_text("products", "size_chart_json")
    _add_text("products", "care_instructions")


def downgrade():
    pass
