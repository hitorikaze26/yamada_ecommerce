"""merge migration heads

Revision ID: 22c113073f1b
Revises: 34a5b6d32064, 3d9c3fb34104
Create Date: 2026-05-06 18:30:43.884491

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '22c113073f1b'
down_revision = ('34a5b6d32064', '3d9c3fb34104')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
