"""empty message

Revision ID: cf6564734b84
Revises: dff79da5b35f
Create Date: 2025-12-11 06:32:52.753048

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'cf6564734b84'
down_revision = 'dff79da5b35f'
branch_labels = None
depends_on = None


def upgrade():
    # Migration is a no-op because the target columns already exist in the database.
    pass


def downgrade():
    # No-op downgrade; schema changes were already applied outside this revision.
    pass
