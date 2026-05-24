"""Add COMPLETED to orders.status enum

Revision ID: e1f2a3b4c5d6
Revises: d9e0f1a2b4
Create Date: 2026-05-22 00:45:00.000000

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import is_postgresql, is_mysql, pg_add_enum_value

from alembic import op


revision = 'e1f2a3b4c5d6'
down_revision = 'd9e0f1a2b4'
branch_labels = None
depends_on = None


def upgrade():
    if is_postgresql():
        pg_add_enum_value('orderstatus', 'COMPLETED')
        return

    if is_mysql():
        op.execute(
            """
            ALTER TABLE orders
            MODIFY COLUMN status ENUM(
                'PENDING',
                'CONFIRMED',
                'PROCESSING',
                'SHIPPED',
                'OUT_FOR_DELIVERY',
                'DELIVERED',
                'CANCELLED',
                'RETURNED',
                'COMPLETED'
            ) NOT NULL
            """
        )


def downgrade():
    if is_postgresql():
        # PostgreSQL cannot remove enum values easily; leave COMPLETED in type.
        return

    if is_mysql():
        op.execute(
            """
            ALTER TABLE orders
            MODIFY COLUMN status ENUM(
                'PENDING',
                'CONFIRMED',
                'PROCESSING',
                'SHIPPED',
                'OUT_FOR_DELIVERY',
                'DELIVERED',
                'CANCELLED',
                'RETURNED'
            ) NOT NULL
            """
        )
