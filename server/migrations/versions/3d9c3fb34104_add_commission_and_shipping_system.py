"""add commission and shipping system

Revision ID: 3d9c3fb34104
Revises: 34a5b6d32064
Create Date: 2026-05-06 18:30:02.653043

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '3d9c3fb34104'
down_revision = '2fa744df91e5'
branch_labels = None
depends_on = None


def upgrade():
    # Add new columns to orders table
    op.add_column('orders', sa.Column('shipping_fee', sa.Float(), nullable=True, default=0.0))
    op.add_column('orders', sa.Column('admin_commission', sa.Float(), nullable=True, default=0.0))
    
    # Create commission_settings table
    op.create_table('commission_settings',
        sa.Column('id', sa.BigInteger(), nullable=False),
        sa.Column('commission_rate', sa.Float(), nullable=True, default=0.10),
        sa.Column('applies_to_product_price_only', sa.Boolean(), nullable=True, default=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, default=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create rider_earnings table
    op.create_table('rider_earnings',
        sa.Column('id', sa.BigInteger(), nullable=False),
        sa.Column('delivery_id', sa.BigInteger(), nullable=False),
        sa.Column('rider_id', sa.BigInteger(), nullable=False),
        sa.Column('shipping_fee_total', sa.Float(), nullable=True, default=0.0),
        sa.Column('rider_share_percentage', sa.Float(), nullable=True, default=0.80),
        sa.Column('admin_share_percentage', sa.Float(), nullable=True, default=0.10),
        sa.Column('seller_share_percentage', sa.Float(), nullable=True, default=0.10),
        sa.Column('rider_earnings', sa.Float(), nullable=True, default=0.0),
        sa.Column('admin_earnings', sa.Float(), nullable=True, default=0.0),
        sa.Column('seller_earnings', sa.Float(), nullable=True, default=0.0),
        sa.Column('is_paid', sa.Boolean(), nullable=True, default=False),
        sa.Column('paid_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['delivery_id'], ['rider_deliveries.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['rider_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Insert default commission settings
    op.execute("""
        INSERT INTO commission_settings (commission_rate, applies_to_product_price_only, is_active, created_at)
        VALUES (0.10, 1, 1, NOW())
    """)


def downgrade():
    # Drop new tables
    op.drop_table('rider_earnings')
    op.drop_table('commission_settings')
    
    # Remove new columns from orders table
    op.drop_column('orders', 'admin_commission')
    op.drop_column('orders', 'shipping_fee')
