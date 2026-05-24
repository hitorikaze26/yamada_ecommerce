"""Add universal category to report_types."""

from alembic import op
import sqlalchemy as sa


revision = "k7l8m9n0o1p2"
down_revision = "j6k7l8m9n0o1"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("report_types", schema=None) as batch_op:
        batch_op.add_column(sa.Column("category", sa.String(length=50), nullable=True))


def downgrade():
    with op.batch_alter_table("report_types", schema=None) as batch_op:
        batch_op.drop_column("category")
