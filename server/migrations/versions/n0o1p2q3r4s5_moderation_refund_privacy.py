"""Product moderation, refund dispute fields, moderation logs."""

from alembic import op
import sqlalchemy as sa

revision = "n0o1p2q3r4s5"
down_revision = "m9n0o1p2q3r4"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "products",
        sa.Column(
            "moderation_status",
            sa.Enum(
                "active",
                "under_review",
                "hidden",
                "removed",
                "restricted",
                name="productmoderationstatus",
            ),
            nullable=False,
            server_default="active",
        ),
    )
    op.add_column("products", sa.Column("moderation_reason", sa.Text(), nullable=True))
    op.add_column("products", sa.Column("moderation_updated_at", sa.DateTime(), nullable=True))
    op.add_column("products", sa.Column("moderation_updated_by", sa.BigInteger(), nullable=True))
    op.add_column("products", sa.Column("edit_requested_at", sa.DateTime(), nullable=True))
    op.add_column("products", sa.Column("edit_request_note", sa.Text(), nullable=True))
    op.create_foreign_key(
        "fk_products_moderation_updated_by_user",
        "products",
        "user",
        ["moderation_updated_by"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "product_moderation_logs",
        sa.Column("id", sa.BigInteger(), primary_key=True),
        sa.Column("product_id", sa.BigInteger(), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("admin_id", sa.BigInteger(), sa.ForeignKey("user.id", ondelete="SET NULL"), nullable=True),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )

    op.add_column("refund_requests", sa.Column("buyer_evidence_note", sa.Text(), nullable=True))
    op.add_column("refund_requests", sa.Column("seller_response_note", sa.Text(), nullable=True))
    op.add_column("refund_requests", sa.Column("admin_note", sa.Text(), nullable=True))
    op.add_column("refund_requests", sa.Column("evidence_paths_json", sa.Text(), nullable=True))
    op.add_column("refund_requests", sa.Column("disputed_at", sa.DateTime(), nullable=True))
    op.add_column("refund_requests", sa.Column("evidence_requested_at", sa.DateTime(), nullable=True))
    op.add_column("refund_requests", sa.Column("frozen_at", sa.DateTime(), nullable=True))
    op.add_column(
        "refund_requests",
        sa.Column("is_transaction_frozen", sa.Boolean(), nullable=False, server_default="0"),
    )

    # Extend MySQL ENUM for refund status
    op.execute(
        "ALTER TABLE refund_requests MODIFY COLUMN status "
        "ENUM('requested','approved_by_seller','rejected_by_seller','approved','rejected',"
        "'disputed','evidence_requested','admin_review') NOT NULL"
    )


def downgrade():
    op.execute(
        "ALTER TABLE refund_requests MODIFY COLUMN status "
        "ENUM('requested','approved_by_seller','rejected_by_seller','approved','rejected') NOT NULL"
    )
    op.drop_column("refund_requests", "is_transaction_frozen")
    op.drop_column("refund_requests", "frozen_at")
    op.drop_column("refund_requests", "evidence_requested_at")
    op.drop_column("refund_requests", "disputed_at")
    op.drop_column("refund_requests", "evidence_paths_json")
    op.drop_column("refund_requests", "admin_note")
    op.drop_column("refund_requests", "seller_response_note")
    op.drop_column("refund_requests", "buyer_evidence_note")

    op.drop_table("product_moderation_logs")
    op.drop_constraint("fk_products_moderation_updated_by_user", "products", type_="foreignkey")
    op.drop_column("products", "edit_request_note")
    op.drop_column("products", "edit_requested_at")
    op.drop_column("products", "moderation_updated_by")
    op.drop_column("products", "moderation_updated_at")
    op.drop_column("products", "moderation_reason")
    op.drop_column("products", "moderation_status")
