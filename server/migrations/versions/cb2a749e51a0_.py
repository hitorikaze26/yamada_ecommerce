"""empty message

Revision ID: cb2a749e51a0
Revises: 8c19c1f85b58
Create Date: 2025-12-11 16:22:25.585950

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'cb2a749e51a0'
down_revision = '8c19c1f85b58'
branch_labels = None
depends_on = None


def upgrade():
    # No-op: banner_path is already present in the seller_profiles table.
    # This migration is kept only to advance the revision.
    pass


def downgrade():
    # No-op: matching upgrade(), do not alter schema.
    pass
