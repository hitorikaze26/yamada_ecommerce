"""Add seller reply and moderation fields to reviews

Revision ID: f2a3b4c5d6e7
Revises: e1f2a3b4c5d6
Create Date: 2026-05-22 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = 'f2a3b4c5d6e7'
down_revision = 'e1f2a3b4c5d6'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('reviews', sa.Column('seller_reply', sa.TEXT(), nullable=True))
    op.add_column('reviews', sa.Column('seller_reply_at', sa.DateTime(), nullable=True))
    op.add_column(
        'reviews',
        sa.Column('visibility', sa.String(length=20), nullable=False, server_default='visible'),
    )
    op.add_column('reviews', sa.Column('deleted_at', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('reviews', 'deleted_at')
    op.drop_column('reviews', 'visibility')
    op.drop_column('reviews', 'seller_reply_at')
    op.drop_column('reviews', 'seller_reply')
