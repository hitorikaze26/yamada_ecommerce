from alembic import op
import sqlalchemy as sa

revision = "<new_id>"
down_revision = "cb68bf686f21"  # whatever Alembic generated, keep this
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "products",
        sa.Column("low_stock_threshold", sa.Integer(), nullable=True),
    )


def downgrade():
    op.drop_column("products", "low_stock_threshold")