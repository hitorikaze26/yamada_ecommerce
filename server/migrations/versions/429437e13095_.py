"""empty message

Revision ID: 429437e13095
Revises: 193d70db8d79
Create Date: 2025-12-11 18:24:18.753364

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '429437e13095'
down_revision = '193d70db8d79'
branch_labels = None
depends_on = None


def upgrade():
    """Schema already matches models (avatar_path present); nothing to do."""
    pass


def downgrade():
    # No-op downgrade; avatar_path column will remain
    pass
