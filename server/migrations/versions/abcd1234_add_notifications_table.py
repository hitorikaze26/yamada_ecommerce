"""add notifications table

Revision ID: abcd1234abcd
Revises: 193d70db8d79
Create Date: 2025-12-11 21:33:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "abcd1234abcd"
down_revision = "bf4d44f6b277"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "notifications",
        sa.Column("id", sa.BIGINT(), nullable=False),
        sa.Column("user_id", sa.BIGINT(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("role", sa.String(length=50), nullable=True),
        sa.Column("page", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("read", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["user.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    # Optional: if you want faster lookups by user/role/page
    op.create_index(
        "ix_notifications_user_role_page",
        "notifications",
        ["user_id", "role", "page"],
    )


def downgrade():
    op.drop_index("ix_notifications_user_role_page", table_name="notifications")
    op.drop_table("notifications")