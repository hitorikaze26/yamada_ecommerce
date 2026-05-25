"""Add a partial unique index preventing duplicate active RiderDelivery rows per order.

This is the DB-level safety net for the concurrent acceptance fix.
Two riders racing to accept the same order will be serialised by the FOR UPDATE
lock, but this index guarantees no duplicates even if locking fails.
"""

from alembic import op
import sqlalchemy as sa


revision = "w3x4y5z6a7b8"
down_revision = "v2w3x4y5z6a7"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index(
        "idx_unique_active_delivery",
        "rider_deliveries",
        ["order_id"],
        unique=True,
        postgresql_where=sa.text("status != 'cancelled'"),
    )


def downgrade():
    op.drop_index("idx_unique_active_delivery", table_name="rider_deliveries")
