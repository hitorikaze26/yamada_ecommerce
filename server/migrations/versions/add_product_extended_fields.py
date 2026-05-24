"""add extended product fields

Revision ID: add_product_extended_fields
Revises: fcbefc7fa534
Create Date: 2025-12-12 11:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "add_product_extended_fields"
down_revision = "dbb3dbea19e3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("products", schema=None) as batch_op:
        batch_op.add_column(sa.Column("brand", sa.String().with_variant(sa.VARCHAR(length=255), "mysql"), nullable=True))
        batch_op.add_column(sa.Column("sale_price", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("tags_json", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("product_condition", sa.String().with_variant(sa.VARCHAR(length=255), "mysql"), nullable=True))
        batch_op.add_column(sa.Column("weight_kg", sa.Float(), nullable=True))
        batch_op.add_column(sa.Column("material", sa.String().with_variant(sa.VARCHAR(length=255), "mysql"), nullable=True))
        batch_op.add_column(sa.Column("size_chart_json", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("care_instructions", sa.Text(), nullable=True))


def downgrade() -> None:
    with op.batch_alter_table("products", schema=None) as batch_op:
        batch_op.drop_column("care_instructions")
        batch_op.drop_column("size_chart_json")
        batch_op.drop_column("material")
        batch_op.drop_column("weight_kg")
        batch_op.drop_column("product_condition")
        batch_op.drop_column("tags_json")
        batch_op.drop_column("sale_price")
        batch_op.drop_column("brand")
