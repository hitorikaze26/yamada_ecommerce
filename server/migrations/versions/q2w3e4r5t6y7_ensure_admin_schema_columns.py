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

_STRING_COLS = (
    "region_code",
    "region_name",
    "province_code",
    "province_name",
    "municipality_code",
    "municipality_name",
    "barangay_code",
    "barangay_name",
    "street_address",
    "postal_code",
)


def _add_string_column(table: str, column: str) -> None:
    if not has_column(table, column):
        op.add_column(
            table,
            sa.Column(
                column,
                sa.String().with_variant(sa.VARCHAR(length=255), "mysql"),
                nullable=True,
            ),
        )


def _ensure_ph_address_columns(table: str) -> None:
    if not table_exists(table):
        return
    for column in _STRING_COLS:
        _add_string_column(table, column)


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

    if table_exists("seller_profiles"):
        _ensure_ph_address_columns("seller_profiles")
        for column in ("avatar_path", "banner_path", "valid_id_path"):
            _add_string_column("seller_profiles", column)

    if table_exists("buyer_profiles"):
        _ensure_ph_address_columns("buyer_profiles")
        for column in ("avatar_path", "valid_id_path"):
            _add_string_column("buyer_profiles", column)

    if table_exists("rider_profiles"):
        _ensure_ph_address_columns("rider_profiles")
        for column in (
            "vehicle_type",
            "license_number",
            "license_path",
            "orcr_path",
            "avatar_path",
        ):
            _add_string_column("rider_profiles", column)

    if table_exists("store_registrations"):
        for column in ("tagline", "categories_json"):
            _add_string_column("store_registrations", column)
        for column in ("dti_path", "bir_tin_path", "business_permit_path"):
            _add_string_column("store_registrations", column)

    # request_status on Supabase is already storerequeststatus enum
    # (ACCEPTED / REJECTED / PENDING). Do not assign plain text here.


def downgrade():
    pass
