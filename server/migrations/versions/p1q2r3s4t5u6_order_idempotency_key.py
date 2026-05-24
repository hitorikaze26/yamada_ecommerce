"""Add idempotency_key to orders for duplicate checkout prevention."""

from alembic import op
import sqlalchemy as sa


revision = "p1q2r3s4t5u6"
down_revision = "n0o1p2q3r4s5"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("orders", schema=None) as batch_op:
        batch_op.add_column(sa.Column("idempotency_key", sa.String(length=64), nullable=True))
        batch_op.create_index(
            "ix_orders_idempotency_key",
            ["idempotency_key"],
            unique=True,
        )


def downgrade():
    with op.batch_alter_table("orders", schema=None) as batch_op:
        batch_op.drop_index("ix_orders_idempotency_key")
        batch_op.drop_column("idempotency_key")
