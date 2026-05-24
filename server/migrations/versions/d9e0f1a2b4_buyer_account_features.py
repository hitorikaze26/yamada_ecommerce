"""buyer account: coupons, problem reports, order coupon fields

Revision ID: d9e0f1a2b4
Revises: c8d9e0f1a2b3
Create Date: 2026-05-21 16:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = 'd9e0f1a2b4'
down_revision = 'c8d9e0f1a2b3'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    tables = inspector.get_table_names()

    if 'coupons' not in tables:
        op.create_table(
            'coupons',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('code', sa.String(50), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('description', sa.TEXT(), nullable=True),
            sa.Column('discount_type', sa.String(20), nullable=False),
            sa.Column('discount_value', sa.Float(), nullable=False),
            sa.Column('min_order_amount', sa.Float(), nullable=True),
            sa.Column('max_uses', sa.Integer(), nullable=True),
            sa.Column('used_count', sa.Integer(), nullable=False),
            sa.Column('expires_at', sa.DateTime(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False),
            sa.Column('scope', sa.String(20), nullable=False),
            sa.Column('store_id', sa.BIGINT(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['store_id'], ['stores.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('code', 'store_id', name='uq_coupon_code_store'),
        )

    if 'coupon_redemptions' not in tables:
        op.create_table(
            'coupon_redemptions',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('coupon_id', sa.BIGINT(), nullable=False),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('order_id', sa.BIGINT(), nullable=True),
            sa.Column('redeemed_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['coupon_id'], ['coupons.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )

    if 'problem_reports' not in tables:
        op.create_table(
            'problem_reports',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('reporter_user_id', sa.BIGINT(), nullable=False),
            sa.Column('category', sa.String(20), nullable=False),
            sa.Column('description', sa.TEXT(), nullable=False),
            sa.Column('store_id', sa.BIGINT(), nullable=True),
            sa.Column('order_id', sa.BIGINT(), nullable=True),
            sa.Column('rider_id', sa.BIGINT(), nullable=True),
            sa.Column('status', sa.Enum('pending', 'reviewed', 'resolved', name='problemreportstatus'), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['reporter_user_id'], ['user.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['store_id'], ['stores.id'], ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['rider_id'], ['user.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id'),
        )

    order_cols = {c['name'] for c in inspector.get_columns('orders')}
    if 'coupon_id' not in order_cols:
        op.add_column('orders', sa.Column('coupon_id', sa.BIGINT(), nullable=True))
        op.create_foreign_key('fk_orders_coupon_id', 'orders', 'coupons', ['coupon_id'], ['id'], ondelete='SET NULL')
    if 'coupon_discount' not in order_cols:
        op.add_column('orders', sa.Column('coupon_discount', sa.Float(), nullable=True, server_default='0'))


def downgrade():
    op.drop_constraint('fk_orders_coupon_id', 'orders', type_='foreignkey')
    op.drop_column('orders', 'coupon_discount')
    op.drop_column('orders', 'coupon_id')
    op.drop_table('problem_reports')
    op.drop_table('coupon_redemptions')
    op.drop_table('coupons')
