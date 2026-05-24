"""Alters store_registrations.request_status col type from str to enum

Revision ID: 7d9965f5df43
Revises: db4976136a6f
Create Date: 2025-10-23 20:15:55.586026

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = '7d9965f5df43'
down_revision = 'db4976136a6f'
branch_labels = None
depends_on = None

_STORE_REQUEST_STATUS = sa.Enum(
    'ACCEPTED', 'REJECTED', 'PENDING', name='storerequeststatus'
)


def upgrade():
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
            existing_type=mysql.VARCHAR(length=255),
            type_=_STORE_REQUEST_STATUS,
            existing_nullable=False,
        )


def downgrade():
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
            existing_type=_STORE_REQUEST_STATUS,
            type_=mysql.VARCHAR(length=255),
            existing_nullable=False,
        )
