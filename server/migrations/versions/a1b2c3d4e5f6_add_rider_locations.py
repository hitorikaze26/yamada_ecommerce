"""Add rider_locations table for live GPS tracking

Revision ID: a1b2c3d4e5f6
Revises: z1a2b3c4d5e6
Create Date: 2026-05-28 07:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = '6afb13360cc3'
branch_labels = None
depends_on = None


def table_exists(table_name):
    bind = op.get_context().bind
    inspector = inspect(bind)
    return table_name in inspector.get_table_names()


def upgrade():
    if not table_exists('rider_locations'):
        op.create_table(
            'rider_locations',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('rider_id', sa.BIGINT(), nullable=False),
            sa.Column('order_id', sa.BIGINT(), nullable=True),
            sa.Column('latitude', sa.Numeric(precision=10, scale=8), nullable=False),
            sa.Column('longitude', sa.Numeric(precision=11, scale=8), nullable=False),
            sa.Column('timestamp', sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(['rider_id'], ['user.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )


def downgrade():
    if table_exists('rider_locations'):
        op.drop_table('rider_locations')
