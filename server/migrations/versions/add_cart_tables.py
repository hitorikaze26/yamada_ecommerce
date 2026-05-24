"""add cart tables

Revision ID: add_cart_tables
Revises: 3d9c3fb34104
Create Date: 2026-05-07 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_cart_tables'
down_revision = '3d9c3fb34104'
branch_labels = None
depends_on = None


def upgrade():
    # Create carts table
    op.create_table('carts',
        sa.Column('id', sa.BigInteger(), nullable=False),
        sa.Column('user_id', sa.BigInteger(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', name='uq_carts_user_id')
    )
    
    # Create cart_items table
    op.create_table('cart_items',
        sa.Column('id', sa.BigInteger(), nullable=False),
        sa.Column('cart_id', sa.BigInteger(), nullable=False),
        sa.Column('product_id', sa.BigInteger(), nullable=False),
        sa.Column('variation_id', sa.BigInteger(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False, default=1),
        sa.Column('price_at_add', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['cart_id'], ['carts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['variation_id'], ['product_variations.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create index on cart_id for faster lookups
    op.create_index('ix_cart_items_cart_id', 'cart_items', ['cart_id'])


def downgrade():
    # Drop indexes
    op.drop_index('ix_cart_items_cart_id', table_name='cart_items')
    
    # Drop tables
    op.drop_table('cart_items')
    op.drop_table('carts')
