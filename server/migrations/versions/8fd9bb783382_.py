"""empty message

Revision ID: 8fd9bb783382
Revises: 429437e13095
Create Date: 2025-12-11 19:30:50.293065

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8fd9bb783382'
down_revision = '429437e13095'
branch_labels = None
depends_on = None


def upgrade():
    pass
    # ### end Alembic commands ###


def downgrade():
    with op.batch_alter_table("products", schema=None) as batch_op:
        batch_op.drop_column("is_live")

    # ### end Alembic commands ###
