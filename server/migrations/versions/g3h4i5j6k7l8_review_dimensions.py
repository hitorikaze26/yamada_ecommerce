"""Add multi-dimensional review fields

Revision ID: g3h4i5j6k7l8
Revises: f2a3b4c5d6e7
Create Date: 2026-05-23 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'g3h4i5j6k7l8'
down_revision = 'f2a3b4c5d6e7'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'reviews',
        sa.Column('review_format', sa.String(length=32), nullable=False, server_default='default'),
    )
    op.add_column('reviews', sa.Column('ratings_json', sa.TEXT(), nullable=True))
    op.add_column('reviews', sa.Column('delivery_satisfaction', sa.Integer(), nullable=True))
    op.add_column('reviews', sa.Column('delivery_pills_json', sa.TEXT(), nullable=True))


def downgrade():
    op.drop_column('reviews', 'delivery_pills_json')
    op.drop_column('reviews', 'delivery_satisfaction')
    op.drop_column('reviews', 'ratings_json')
    op.drop_column('reviews', 'review_format')
