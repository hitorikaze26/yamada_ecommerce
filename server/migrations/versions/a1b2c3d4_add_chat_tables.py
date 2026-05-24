"""add chat tables

Revision ID: a1b2c3d4e5f6
Revises: 52de6d36d6b0
Create Date: 2026-05-21 10:00:00.000000

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import bool_false_default

from alembic import op
import sqlalchemy as sa


revision = "a1b2c3d4e5f6"
down_revision = "add_cost_price_and_discount"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "conversations",
        sa.Column("id", sa.BIGINT(), nullable=False),
        sa.Column(
            "kind",
            sa.Enum(
                "buyer_seller",
                "seller_admin",
                "admin_buyer",
                "rider_seller",
                name="conversationkind",
            ),
            nullable=False,
        ),
        sa.Column("store_id", sa.BIGINT(), nullable=True),
        sa.Column("order_id", sa.BIGINT(), nullable=True),
        sa.Column("buyer_user_id", sa.BIGINT(), nullable=True),
        sa.Column("last_message_at", sa.DateTime(), nullable=False),
        sa.Column("last_message_preview", sa.String(length=500), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["store_id"], ["stores.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["order_id"], ["orders.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["buyer_user_id"], ["user.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_conversations_kind_store_buyer",
        "conversations",
        ["kind", "store_id", "buyer_user_id"],
    )

    op.create_table(
        "conversation_participants",
        sa.Column("id", sa.BIGINT(), nullable=False),
        sa.Column("conversation_id", sa.BIGINT(), nullable=False),
        sa.Column("user_id", sa.BIGINT(), nullable=False),
        sa.Column("participant_role", sa.String(length=32), nullable=False),
        sa.Column("is_pinned", sa.Boolean(), nullable=False, server_default=bool_false_default()),
        sa.Column("last_read_at", sa.DateTime(), nullable=True),
        sa.Column("unread_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["conversations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "conversation_id", "user_id", name="uq_conv_participant_user"
        ),
    )

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.BIGINT(), nullable=False),
        sa.Column("conversation_id", sa.BIGINT(), nullable=False),
        sa.Column("sender_user_id", sa.BIGINT(), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "message_type",
            sa.Enum(
                "text",
                "image",
                "file",
                "product",
                "order",
                "system",
                name="chatmessagetype",
            ),
            nullable=False,
        ),
        sa.Column("metadata_json", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["conversation_id"], ["conversations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["sender_user_id"], ["user.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_chat_messages_conversation_created",
        "chat_messages",
        ["conversation_id", "created_at"],
    )

    op.create_table(
        "user_presence",
        sa.Column("user_id", sa.BIGINT(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("is_online", sa.Boolean(), nullable=False, server_default=bool_false_default()),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade():
    op.drop_table("user_presence")
    op.drop_index("ix_chat_messages_conversation_created", table_name="chat_messages")
    op.drop_table("chat_messages")
    op.drop_table("conversation_participants")
    op.drop_index("ix_conversations_kind_store_buyer", table_name="conversations")
    op.drop_table("conversations")
