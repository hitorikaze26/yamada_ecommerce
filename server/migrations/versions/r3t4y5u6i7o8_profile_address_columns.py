"""Add Philippine address + avatar columns to profile tables (idempotent)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import has_column, table_exists

from alembic import op
import sqlalchemy as sa

revision = "r3t4y5u6i7o8"
down_revision = "q2w3e4r5t6y7"
branch_labels = None
depends_on = None

_PH_COLS = (
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


def upgrade():
    for table in ("seller_profiles", "buyer_profiles", "rider_profiles"):
        for column in _PH_COLS:
            _add_string(table, column)

    for column in ("avatar_path", "banner_path", "valid_id_path"):
        _add_string("seller_profiles", column)

    for column in ("avatar_path", "valid_id_path"):
        _add_string("buyer_profiles", column)

    for column in (
        "vehicle_type",
        "license_number",
        "license_path",
        "orcr_path",
        "avatar_path",
    ):
        _add_string("rider_profiles", column)

    for column in ("tagline", "categories_json", "dti_path", "bir_tin_path", "business_permit_path"):
        _add_string("store_registrations", column)


def downgrade():
    pass
