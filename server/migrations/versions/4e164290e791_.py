"""empty message

Revision ID: 4e164290e791
Revises: cb2a749e51a0
Create Date: 2025-12-11 16:25:34.663572

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4e164290e791'
down_revision = 'cb2a749e51a0'
branch_labels = None
depends_on = None


def upgrade():
    # No-op: indexes are required by existing foreign key constraints.
    # This migration is retained only for revision history.
    pass


def downgrade():
    # No-op: matching upgrade(), do not alter schema.
    pass
