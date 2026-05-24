"""empty message

Revision ID: f47611a91919
Revises: 021585b592d5
Create Date: 2025-12-08 20:55:16.804687

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f47611a91919'
down_revision = '021585b592d5'
branch_labels = None
depends_on = None


def upgrade():
    """No-op migration.

    Alembic autogeneration attempted to drop the 'seller_id' index on
    'store_registrations' and 'stores', but MySQL requires this index for
    existing foreign key constraints. Dropping it results in:

      OperationalError: (pymysql.err.OperationalError) (1553,
      "Cannot drop index 'seller_id': needed in a foreign key constraint")

    To avoid breaking constraints in production, we intentionally leave this
    migration empty.
    """
    pass


def downgrade():
    # No-op downgrade corresponding to the no-op upgrade.
    pass
