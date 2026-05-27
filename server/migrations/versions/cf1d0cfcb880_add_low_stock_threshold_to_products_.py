import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import column_names

from alembic import op
import sqlalchemy as sa

revision = "<new_id>"
down_revision = "cb68bf686f21"
branch_labels = None
depends_on = None


def upgrade():
    if "low_stock_threshold" not in column_names("products"):
        op.add_column(
            "products",
            sa.Column("low_stock_threshold", sa.Integer(), nullable=True),
        )


def downgrade():
    if "low_stock_threshold" in column_names("products"):
        op.drop_column("products", "low_stock_threshold")
