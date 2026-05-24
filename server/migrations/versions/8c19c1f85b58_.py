"""empty message

Revision ID: 8c19c1f85b58
Revises: 4269324a07c9
Create Date: 2025-12-11 13:49:17.063542

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8c19c1f85b58'
down_revision = '4269324a07c9'
branch_labels = None
depends_on = None


def upgrade():
    # No-op: schema already has the desired structure in production.
    # This migration is retained only for revision history.
    pass


def downgrade():
    # No-op: matching the upgrade() which performs no schema changes.
    pass
