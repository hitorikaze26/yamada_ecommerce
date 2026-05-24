"""empty message

Revision ID: fcbefc7fa534
Revises: f47611a91919
Create Date: 2025-12-08 21:31:40.033243

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = 'fcbefc7fa534'
down_revision = 'f47611a91919'
branch_labels = None
depends_on = None


def upgrade():
    """Apply wishlist_items table and avatar_path column without touching seller_id indexes.

    Alembic auto-generation tried to drop the 'seller_id' index on
    'store_registrations' and 'stores', but MySQL needs that index for
    existing foreign key constraints. Dropping it causes:

      OperationalError: (pymysql.err.OperationalError) (1553,
      "Cannot drop index 'seller_id': needed in a foreign key constraint")

    We keep the new wishlist_items table and avatar_path column, and
    intentionally skip any index changes here.
    """

    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = inspector.get_table_names()

    if 'wishlist_items' not in existing_tables:
        op.create_table(
            'wishlist_items',
            sa.Column('id', sa.BIGINT(), nullable=False),
            sa.Column('user_id', sa.BIGINT(), nullable=False),
            sa.Column('product_id', sa.BIGINT(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )

    # Add avatar_path column only if it does not already exist
    buyer_columns = [col['name'] for col in inspector.get_columns('buyer_profiles')]
    if 'avatar_path' not in buyer_columns:
        with op.batch_alter_table('buyer_profiles', schema=None) as batch_op:
            batch_op.add_column(
                sa.Column(
                    'avatar_path',
                    sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
                    nullable=True,
                )
            )


def downgrade():
    # Only undo what we actually did in upgrade: drop avatar_path and wishlist_items.

    with op.batch_alter_table('buyer_profiles', schema=None) as batch_op:
        batch_op.drop_column('avatar_path')

    op.drop_table('wishlist_items')

