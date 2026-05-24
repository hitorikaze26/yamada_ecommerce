"""empty message

Revision ID: 021585b592d5
Revises: 64489a8644ba
Create Date: 2025-12-08 18:20:41.433929

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = '021585b592d5'
down_revision = '64489a8644ba'
branch_labels = None
depends_on = None


def _string_column(name: str, *, nullable: bool = True) -> sa.Column:
    return sa.Column(
        name,
        sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
        nullable=nullable,
    )


def _create_buyer_profiles() -> None:
    op.create_table(
        'buyer_profiles',
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
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )


def _create_rider_profiles() -> None:
    op.create_table(
        'rider_profiles',
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
        _string_column('vehicle_type'),
        _string_column('license_number'),
        _string_column('license_path'),
        _string_column('orcr_path'),
        _string_column('avatar_path'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['user.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id'),
    )


def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = set(inspector.get_table_names())

    if 'buyer_profiles' not in existing_tables:
        _create_buyer_profiles()

    if 'rider_profiles' not in existing_tables:
        _create_rider_profiles()

    with op.batch_alter_table('user', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                'given_name',
                sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                'surname',
                sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                'contact_number',
                sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
                nullable=True,
            )
        )


def downgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    existing_tables = set(inspector.get_table_names())

    with op.batch_alter_table('user', schema=None) as batch_op:
        batch_op.drop_column('contact_number')
        batch_op.drop_column('surname')
        batch_op.drop_column('given_name')

    if 'buyer_profiles' in existing_tables:
        op.drop_table('buyer_profiles')

    if 'rider_profiles' in existing_tables:
        op.drop_table('rider_profiles')
