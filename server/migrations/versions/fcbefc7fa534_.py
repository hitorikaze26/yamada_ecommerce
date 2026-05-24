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


def _string_column(name: str, *, nullable: bool = True) -> sa.Column:
    return sa.Column(
        name,
        sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
        nullable=nullable,
    )


def _create_buyer_profiles(*, include_avatar: bool) -> None:
    columns = [
        sa.Column('id', sa.BIGINT(), nullable=False),
        sa.Column('user_id', sa.BIGINT(), nullable=False),
        _string_column('region_code'),
        _string_column('region_name'),
        _string_column('province_code'),
        _string_column('province_name'),
        _string_column('municipality_code'),
        _string_column('municipality_name'),
        _string_column('barangay_code'),
        _string_column('barangay_name'),
        _string_column('street_address'),
        _string_column('postal_code'),
        _string_column('valid_id_path'),
    ]
    if include_avatar:
        columns.append(_string_column('avatar_path'))
    columns.extend(
        [
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id'),
        ]
    )
    op.create_table('buyer_profiles', *columns)


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
    existing_tables = set(inspector.get_table_names())

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

    if 'buyer_profiles' not in existing_tables:
        _create_buyer_profiles(include_avatar=True)
    else:
        buyer_columns = {
            col['name'] for col in inspector.get_columns('buyer_profiles')
        }
        if 'avatar_path' not in buyer_columns:
            with op.batch_alter_table('buyer_profiles', schema=None) as batch_op:
                batch_op.add_column(_string_column('avatar_path'))


def downgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = set(inspector.get_table_names())

    if 'buyer_profiles' in existing_tables:
        buyer_columns = {
            col['name'] for col in inspector.get_columns('buyer_profiles')
        }
        if 'avatar_path' in buyer_columns:
            with op.batch_alter_table('buyer_profiles', schema=None) as batch_op:
                batch_op.drop_column('avatar_path')

    if 'wishlist_items' in existing_tables:
        op.drop_table('wishlist_items')
