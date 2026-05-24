"""Add COMPLETED to orders.status enum

Revision ID: e1f2a3b4c5d6
Revises: d9e0f1a2b4
Create Date: 2026-05-22 00:45:00.000000

"""
from alembic import op


revision = 'e1f2a3b4c5d6'
down_revision = 'd9e0f1a2b4'
branch_labels = None
depends_on = None


def upgrade():
    # MySQL enum was created without COMPLETED; buyer confirm-received needs it.
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
