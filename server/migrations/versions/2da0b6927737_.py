from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "2da0b6927737"
down_revision = "4e164290e791"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "products",
        sa.Column("low_stock_threshold", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("products", "low_stock_threshold")