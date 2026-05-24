"""Alters store_registrations.request_status col type from enum to str

Revision ID: db4976136a6f
Revises: 9f65ec0c8ea8
Create Date: 2025-10-23 20:07:43.010849

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = 'db4976136a6f'
down_revision = '9f65ec0c8ea8'
branch_labels = None
depends_on = None

_STORE_REQUEST_STATUS = sa.Enum(
    'ACCEPTED', 'REJECTED', 'PENDING', name='storerequeststatus'
)


def upgrade():
    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        op.execute(
            "ALTER TABLE store_registrations "
            "ALTER COLUMN request_status TYPE VARCHAR(255) "
            "USING request_status::text"
        )
        return

    with op.batch_alter_table('store_registrations', schema=None) as batch_op:
        batch_op.alter_column(
            'request_status',
            existing_type=mysql.ENUM('ACCEPTED', 'REJECTED', 'PENDING'),
            type_=sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
            existing_nullable=False,
        )


def downgrade():
    bind = op.get_bind()
    if bind.dialect.name == 'postgresql':
        _STORE_REQUEST_STATUS.create(bind, checkfirst=True)
        op.execute(
            "ALTER TABLE store_registrations "
            "ALTER COLUMN request_status TYPE storerequeststatus "
            "USING request_status::storerequeststatus"
        )
        return

    with op.batch_alter_table('store_registrations', schema=None) as batch_op:
        batch_op.alter_column(
            'request_status',
            existing_type=sa.String().with_variant(sa.VARCHAR(length=255), 'mysql'),
            type_=mysql.ENUM('ACCEPTED', 'REJECTED', 'PENDING'),
            existing_nullable=False,
        )
