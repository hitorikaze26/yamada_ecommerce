"""Add cost_price to products and discount_amount to order_items

Revision ID: add_cost_price_and_discount
Revises: 5d22f768844e
Create Date: 2026-05-18 00:00:00.000000
"""
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision = 'add_cost_price_and_discount'
down_revision = ('5d22f768844e', '52de6d36d6b0')
branch_labels = None
depends_on = None


def upgrade():
    # cost_price: seller's cost of goods per product (nullable, defaults to 0)
    with op.batch_alter_table('products', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('cost_price', sa.Float(), nullable=True, server_default='0')
        )

    # discount_amount: per-line-item discount captured at checkout (nullable, defaults to 0)
    with op.batch_alter_table('order_items', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('discount_amount', sa.Float(), nullable=True, server_default='0')
        )


def downgrade():
    with op.batch_alter_table('order_items', schema=None) as batch_op:
        batch_op.drop_column('discount_amount')

    with op.batch_alter_table('products', schema=None) as batch_op:
        batch_op.drop_column('cost_price')
