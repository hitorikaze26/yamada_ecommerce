"""Lowercase productmoderationstatus enum values

Revision ID: c3d4e5f6a1b2
Revises: a1b2c3d4e5f6
Create Date: 2026-05-29 12:00:00.000000

"""
from alembic import op

# revision identifiers, used by Alembic.
revision = 'c3d4e5f6a1b2'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == 'postgresql':
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'ACTIVE' TO 'active';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'UNDER_REVIEW' TO 'under_review';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'HIDDEN' TO 'hidden';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'REMOVED' TO 'removed';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'RESTRICTED' TO 'restricted';")
        return

    if dialect == 'mysql':
        op.execute("UPDATE products SET moderation_status = 'active' WHERE moderation_status = 'ACTIVE';")
        op.execute("UPDATE products SET moderation_status = 'under_review' WHERE moderation_status = 'UNDER_REVIEW';")
        op.execute("UPDATE products SET moderation_status = 'hidden' WHERE moderation_status = 'HIDDEN';")
        op.execute("UPDATE products SET moderation_status = 'removed' WHERE moderation_status = 'REMOVED';")
        op.execute("UPDATE products SET moderation_status = 'restricted' WHERE moderation_status = 'RESTRICTED';")
        op.execute(
            "ALTER TABLE products MODIFY moderation_status ENUM('active','under_review','hidden','removed','restricted') NOT NULL DEFAULT 'active';"
        )
        return

    # For other backends, the enum is not likely applicable or may already be aligned.


def downgrade():
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == 'postgresql':
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'active' TO 'ACTIVE';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'under_review' TO 'UNDER_REVIEW';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'hidden' TO 'HIDDEN';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'removed' TO 'REMOVED';")
        op.execute("ALTER TYPE productmoderationstatus RENAME VALUE 'restricted' TO 'RESTRICTED';")
        return

    if dialect == 'mysql':
        op.execute("UPDATE products SET moderation_status = 'ACTIVE' WHERE moderation_status = 'active';")
        op.execute("UPDATE products SET moderation_status = 'UNDER_REVIEW' WHERE moderation_status = 'under_review';")
        op.execute("UPDATE products SET moderation_status = 'HIDDEN' WHERE moderation_status = 'hidden';")
        op.execute("UPDATE products SET moderation_status = 'REMOVED' WHERE moderation_status = 'removed';")
        op.execute("UPDATE products SET moderation_status = 'RESTRICTED' WHERE moderation_status = 'restricted';")
        op.execute(
            "ALTER TABLE products MODIFY moderation_status ENUM('ACTIVE','UNDER_REVIEW','HIDDEN','REMOVED','RESTRICTED') NOT NULL DEFAULT 'ACTIVE';"
        )
        return

    # For other backends, do nothing.
