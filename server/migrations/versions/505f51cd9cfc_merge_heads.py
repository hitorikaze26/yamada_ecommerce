"""merge heads

Revision ID: 505f51cd9cfc
Revises: 5d22f768844e, add_cart_tables
Create Date: 2026-05-07 12:19:50.292096

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '505f51cd9cfc'
down_revision = ('5d22f768844e', 'add_cart_tables')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
