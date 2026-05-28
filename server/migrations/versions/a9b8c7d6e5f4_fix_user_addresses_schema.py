"""Fix user_addresses: rename full_address→street_address, add missing PH address columns.

Revision ID: a9b8c7d6e5f4
Revises: f7e6d5c4b3a2
Create Date: 2026-05-28 08:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import mysql


revision = "a9b8c7d6e5f4"
down_revision = "f7e6d5c4b3a2"
branch_labels = None
depends_on = None


def table_exists(name: str) -> bool:
    return name in inspect(op.get_bind()).get_table_names()


def column_exists(table: str, column: str) -> bool:
    return column in {c["name"] for c in inspect(op.get_bind()).get_columns(table)}


def add_column_if_missing(table: str, column: sa.Column) -> None:
    if not column_exists(table, column.name):
        op.add_column(table, column)


def upgrade():
    if not table_exists("user_addresses"):
        op.create_table(
            "user_addresses",
            sa.Column("id", sa.BIGINT(), nullable=False),
            sa.Column("user_id", sa.BIGINT(), nullable=False),
            sa.Column("label", sa.String(100), nullable=True, server_default="Address"),
            sa.Column("street_address", sa.String(500), nullable=False),
            sa.Column("barangay_name", sa.String(100), nullable=True),
            sa.Column("municipality_name", sa.String(100), nullable=False),
            sa.Column("province_name", sa.String(100), nullable=False),
            sa.Column("region_name", sa.String(100), nullable=False),
            sa.Column("postal_code", sa.String(20), nullable=True),
            sa.Column("region_code", sa.String(20), nullable=True),
            sa.Column("province_code", sa.String(20), nullable=True),
            sa.Column("municipality_code", sa.String(20), nullable=True),
            sa.Column("barangay_code", sa.String(20), nullable=True),
            sa.Column("latitude", sa.Numeric(10, 8), nullable=True, server_default=sa.text("0.0")),
            sa.Column("longitude", sa.Numeric(11, 8), nullable=True, server_default=sa.text("0.0")),
            sa.Column("is_default", sa.Boolean(), nullable=True, server_default=sa.false()),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index(op.f("ix_user_addresses_user_id"), "user_addresses", ["user_id"], unique=False)
        return

    # Rename full_address → street_address if the old column exists
    if column_exists("user_addresses", "full_address") and not column_exists("user_addresses", "street_address"):
        op.alter_column("user_addresses", "full_address", new_column_name="street_address")

    # Add missing columns idempotently
    add_column_if_missing("user_addresses", sa.Column("label", sa.String(100), nullable=True, server_default="Address"))
    add_column_if_missing("user_addresses", sa.Column("barangay_name", sa.String(100), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("municipality_name", sa.String(100), nullable=False, server_default=""))
    add_column_if_missing("user_addresses", sa.Column("province_name", sa.String(100), nullable=False, server_default=""))
    add_column_if_missing("user_addresses", sa.Column("region_name", sa.String(100), nullable=False, server_default=""))
    add_column_if_missing("user_addresses", sa.Column("postal_code", sa.String(20), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("region_code", sa.String(20), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("province_code", sa.String(20), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("municipality_code", sa.String(20), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("barangay_code", sa.String(20), nullable=True))
    add_column_if_missing("user_addresses", sa.Column("is_default", sa.Boolean(), nullable=True, server_default=sa.false()))
    add_column_if_missing("user_addresses", sa.Column("created_at", sa.DateTime(), nullable=True))

    # Make latitude/longitude nullable if they are NOT NULL
    bind = op.get_bind()
    inspector = inspect(bind)
    for col_name in ("latitude", "longitude"):
        col_info = [c for c in inspector.get_columns("user_addresses") if c["name"] == col_name]
        if col_info and not col_info[0].get("nullable", True):
            col_type = sa.Numeric(10, 8) if col_name == "latitude" else sa.Numeric(11, 8)
            op.alter_column("user_addresses", col_name, nullable=True, type_=col_type)

    # Ensure FK exists
    fk_names = [fk["name"] for fk in inspector.get_foreign_keys("user_addresses") if "user_id" in fk.get("constrained_columns", [])]
    if not fk_names:
        op.create_foreign_key(None, "user_addresses", "user.id", ["user_id"], ["id"], ondelete="CASCADE")

    # Ensure index exists
    index_names = [ix["name"] for ix in inspector.get_indexes("user_addresses")]
    if "ix_user_addresses_user_id" not in index_names:
        op.create_index(op.f("ix_user_addresses_user_id"), "user_addresses", ["user_id"], unique=False)


def downgrade():
    pass
