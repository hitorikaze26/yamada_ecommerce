"""chat participant archive and soft delete

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-05-22 10:00:00.000000

"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialect_helpers import bool_false_default

from alembic import op
import sqlalchemy as sa


revision = "b2c3d4e5f6a7"
down_revision = "a1b2c3d4e5f6"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "conversation_participants",
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=bool_false_default()),
    )
    op.add_column(
        "conversation_participants",
        sa.Column("deleted_at", sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_column("conversation_participants", "deleted_at")
    op.drop_column("conversation_participants", "is_archived")
