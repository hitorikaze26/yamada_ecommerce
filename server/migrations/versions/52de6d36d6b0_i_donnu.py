"""i donnu

Revision ID: 52de6d36d6b0
Revises: 505f51cd9cfc
Create Date: 2026-05-07 13:04:58.057872

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = '52de6d36d6b0'
down_revision = '505f51cd9cfc'
branch_labels = None
depends_on = None


def upgrade():
    # Auto-generated migration contained index drops that conflict with existing
    # FK constraints (ix_cart_items_cart_id etc.). Marked as no-op because the
    # live database schema is already correct.
    pass


def downgrade():
    pass
