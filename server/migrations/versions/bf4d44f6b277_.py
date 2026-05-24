"""empty message

Revision ID: bf4d44f6b277
Revises: 8fd9bb783382
Create Date: 2025-12-11 20:08:41.694254

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import is_postgresql, table_exists

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'bf4d44f6b277'
down_revision = '8fd9bb783382'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()

    if not table_exists('seller_wallets'):
        op.create_table(
            'seller_wallets',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('seller_id', sa.BIGINT(), nullable=False),
            sa.Column('balance', sa.Float(), nullable=True),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(['seller_id'], ['seller_profiles.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('seller_id'),
        )

    if not table_exists('payment_transactions'):
        payment_status = sa.Enum(
            'held', 'settled', 'refunded', 'failed', name='paymentstatus'
        )
        payment_status.create(bind, checkfirst=True)
        status_default = (
            sa.text("'held'::paymentstatus")
            if is_postgresql()
            else 'held'
        )
        op.create_table(
            'payment_transactions',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('amount', sa.Float(), nullable=True),
            sa.Column('platform_fee', sa.Float(), nullable=True),
            sa.Column('status', payment_status, nullable=False, server_default=status_default),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.Column('order_id', sa.BIGINT(), nullable=False),
            sa.Column('seller_id', sa.BIGINT(), nullable=True),
            sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['seller_id'], ['seller_profiles.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )


def downgrade():
    if table_exists('payment_transactions'):
        op.drop_table('payment_transactions')
    if table_exists('seller_wallets'):
        op.drop_table('seller_wallets')
