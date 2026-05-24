"""add refund_requests table

Revision ID: 7b12585dcf4b
Revises: abcd1234abcd
Create Date: 2025-12-12 08:47:24.531920

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import enum_for_create_table, is_postgresql, table_exists

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '7b12585dcf4b'
down_revision = 'abcd1234abcd'
branch_labels = None
depends_on = None

_REFUND_STATUS_VALUES = (
    'requested',
    'approved_by_seller',
    'rejected_by_seller',
    'approved',
    'rejected',
)


def upgrade():
    if table_exists('refund_requests'):
        return

    refund_status = enum_for_create_table(*_REFUND_STATUS_VALUES, name='refundstatus')

    status_default = (
        sa.text("'requested'::refundstatus")
        if is_postgresql()
        else 'requested'
    )

    op.create_table(
        'refund_requests',
        sa.Column('id', sa.BIGINT(), nullable=False),
        sa.Column('reason', sa.TEXT(), nullable=True),
        sa.Column('status', refund_status, nullable=False, server_default=status_default),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('order_id', sa.BIGINT(), nullable=False),
        sa.Column('buyer_id', sa.BIGINT(), nullable=True),
        sa.Column('seller_id', sa.BIGINT(), nullable=True),
        sa.Column('payment_transaction_id', sa.BIGINT(), nullable=True),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['buyer_id'], ['user.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['seller_id'], ['seller_profiles.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(
            ['payment_transaction_id'], ['payment_transactions.id'], ondelete='SET NULL'
        ),
        sa.PrimaryKeyConstraint('id'),
    )


def downgrade():
    if table_exists('refund_requests'):
        op.drop_table('refund_requests')
