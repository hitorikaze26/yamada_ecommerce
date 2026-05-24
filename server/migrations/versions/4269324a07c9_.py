"""empty message

Revision ID: 4269324a07c9
Revises: f28fa5e4f611
Create Date: 2025-12-11 12:02:25.748278

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import ensure_product_variations_table, table_exists

from alembic import op
import sqlalchemy as sa


revision = '4269324a07c9'
down_revision = 'f28fa5e4f611'
branch_labels = None
depends_on = None


def upgrade():
    ensure_product_variations_table()


def downgrade():
    if table_exists('product_variations'):
        op.drop_table('product_variations')
