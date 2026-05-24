"""Add shipping coordinates and distance cache

Revision ID: add_shipping_coordinates_manual
Revises: 34a5b6d32064, 3d9c3fb34104
Create Date: 2026-05-06 20:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = 'add_shipping_coordinates_manual'
down_revision = ('34a5b6d32064', '3d9c3fb34104')
branch_labels = None
depends_on = None


def column_exists(table_name, column_name):
    """Check if a column exists in a table"""
    bind = op.get_context().bind
    inspector = inspect(bind)
    columns = [col['name'] for col in inspector.get_columns(table_name)]
    return column_name in columns


def table_exists(table_name):
    """Check if a table exists"""
    bind = op.get_context().bind
    inspector = inspect(bind)
    tables = inspector.get_table_names()
    return table_name in tables


def upgrade():
    # Add latitude and longitude to stores table (only if they don't exist)
    if not column_exists('stores', 'latitude'):
        op.add_column('stores', sa.Column('latitude', sa.Numeric(10, 8), nullable=True))
    if not column_exists('stores', 'longitude'):
        op.add_column('stores', sa.Column('longitude', sa.Numeric(11, 8), nullable=True))
    
    # Create user_addresses table (if not exists)
    if not table_exists('user_addresses'):
        op.create_table('user_addresses',
            sa.Column('id', sa.BigInteger(), nullable=False),
            sa.Column('user_id', sa.BigInteger(), nullable=False),
            sa.Column('full_address', sa.String(500), nullable=False),
            sa.Column('latitude', sa.Numeric(10, 8), nullable=False),
            sa.Column('longitude', sa.Numeric(11, 8), nullable=False),
            sa.Column('is_default', sa.Boolean(), default=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index(op.f('ix_user_addresses_user_id'), 'user_addresses', ['user_id'], unique=False)
    
    # Create distance_cache table (if not exists)
    if not table_exists('distance_cache'):
        op.create_table('distance_cache',
            sa.Column('id', sa.BigInteger(), nullable=False),
            sa.Column('origin_lat', sa.Numeric(10, 8), nullable=False),
            sa.Column('origin_lng', sa.Numeric(11, 8), nullable=False),
            sa.Column('dest_lat', sa.Numeric(10, 8), nullable=False),
            sa.Column('dest_lng', sa.Numeric(11, 8), nullable=False),
            sa.Column('distance_km', sa.Numeric(8, 3), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index('idx_distance_cache_coordinates', 'distance_cache', 
                       ['origin_lat', 'origin_lng', 'dest_lat', 'dest_lng'], unique=False)


def downgrade():
    # Remove distance_cache table
    op.drop_index('idx_distance_cache_coordinates', table_name='distance_cache')
    op.drop_table('distance_cache')
    
    # Remove user_addresses table
    op.drop_index(op.f('ix_user_addresses_user_id'), table_name='user_addresses')
    op.drop_table('user_addresses')
    
    # Remove latitude and longitude from stores table
    op.drop_column('stores', 'longitude')
    op.drop_column('stores', 'latitude')
