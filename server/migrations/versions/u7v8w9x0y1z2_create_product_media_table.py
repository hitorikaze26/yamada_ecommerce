"""Create the product_media table that was accidentally commented out in f28fa5e4f611."""

from alembic import op
import sqlalchemy as sa


revision = "u7v8w9x0y1z2"
down_revision = "t5u6v7w8x9y0"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "product_media",
        sa.Column("id", sa.BIGINT(), nullable=False),
        sa.Column("product_id", sa.BIGINT(), nullable=False),
        sa.Column(
            "media_type",
            sa.String(20).with_variant(sa.VARCHAR(length=255), "mysql"),
            nullable=False,
            server_default="image",
        ),
        sa.Column(
            "path",
            sa.String(500).with_variant(sa.VARCHAR(length=500), "mysql"),
            nullable=False,
        ),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["product_id"], ["products.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade():
    op.drop_table("product_media")
