"""Changes product.seller_id to store_id fk

Revision ID: 621ccc25ff5a
Revises: ed23d17dd682
Create Date: 2025-10-24 12:53:21.763513

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = '621ccc25ff5a'
down_revision = 'ed23d17dd682'
branch_labels = None
depends_on = None


def _fk_name_for_column(table: str, column: str) -> str | None:
    bind = op.get_bind()
    for fk in inspect(bind).get_foreign_keys(table):
        if column in fk.get('constrained_columns', []):
            return fk['name']
    return None


def upgrade():
    seller_fk = _fk_name_for_column('products', 'seller_id')

    with op.batch_alter_table('products', schema=None) as batch_op:
        batch_op.add_column(sa.Column('store_id', sa.BIGINT(), nullable=False))
        if seller_fk:
            batch_op.drop_constraint(seller_fk, type_='foreignkey')
        batch_op.create_foreign_key(None, 'stores', ['store_id'], ['id'], ondelete='CASCADE')
        batch_op.drop_column('seller_id')


def downgrade():
    bind = op.get_bind()
    store_fk = _fk_name_for_column('products', 'store_id')
    seller_id_type = (
        mysql.BIGINT(display_width=20)
        if bind.dialect.name == 'mysql'
        else sa.BIGINT()
    )

    with op.batch_alter_table('products', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('seller_id', seller_id_type, autoincrement=False, nullable=False)
        )
        if store_fk:
            batch_op.drop_constraint(store_fk, type_='foreignkey')
        batch_op.create_foreign_key(
            None, 'seller_profiles', ['seller_id'], ['id'], ondelete='CASCADE'
        )
        batch_op.drop_column('store_id')
