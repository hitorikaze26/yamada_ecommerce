"""empty message

Revision ID: dff79da5b35f
Revises: fcbefc7fa534
Create Date: 2025-12-09 21:31:17.974079

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'dff79da5b35f'
down_revision = 'fcbefc7fa534'
branch_labels = None
depends_on = None


def upgrade():
    # Migration intentionally left as a no-op to preserve existing indexes
    pass


def downgrade():
    # Downgrade is also a no-op for this revision
    pass

