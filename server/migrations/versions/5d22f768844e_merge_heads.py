"""merge heads

Revision ID: 5d22f768844e
Revises: 002_create_distance_cache, 22c113073f1b, 820ca3a374d3, add_shipping_coordinates, add_shipping_coordinates_manual
Create Date: 2026-05-07 08:45:06.934981

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '5d22f768844e'
down_revision = ('002_create_distance_cache', '22c113073f1b', '820ca3a374d3', 'add_shipping_coordinates', 'add_shipping_coordinates_manual')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
