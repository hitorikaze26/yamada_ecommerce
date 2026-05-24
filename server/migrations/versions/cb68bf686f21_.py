from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'cb68bf686f21'
down_revision = 'add_product_extended_fields'
branch_labels = None
depends_on = None


def upgrade():
    # This revision was auto-generated with unwanted index changes.
    # All schema changes for low_stock_threshold are handled in 2da0b6927737.
    pass


def downgrade():
    # No-op to match the empty upgrade.
    pass