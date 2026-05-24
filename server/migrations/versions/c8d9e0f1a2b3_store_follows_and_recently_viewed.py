"""store follows and recently viewed products

Revision ID: c8d9e0f1a2b3
Revises: b2c3d4e5f6a7
Create Date: 2026-05-21 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = 'c8d9e0f1a2b3'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = inspector.get_table_names()

    if 'store_follows' not in existing_tables:
        op.create_table(
            'store_follows',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('store_id', sa.BIGINT(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['store_id'], ['stores.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id', 'store_id', name='uq_store_follows_user_store'),
        )

    if 'recently_viewed_products' not in existing_tables:
        op.create_table(
            'recently_viewed_products',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('product_id', sa.BIGINT(), nullable=False),
            sa.Column('viewed_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id', 'product_id', name='uq_recently_viewed_user_product'),
        )


def downgrade():
    op.drop_table('recently_viewed_products')
    op.drop_table('store_follows')
