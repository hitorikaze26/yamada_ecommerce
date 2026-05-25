"""Add is_cover, sort_order to product_media; backfill rows for existing products."""

import sqlalchemy as sa
from alembic import op
from datetime import datetime

revision = "y9z1a2b3c4d5"
down_revision = "w3x4y5z6a7b8"
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()

    # 1. Add columns (nullable initially for backfill)
    op.add_column("product_media", sa.Column("sort_order", sa.Integer(), nullable=True))
    op.add_column("product_media", sa.Column("is_cover", sa.Boolean(), nullable=True))

    # 2. Backfill: create ProductMedia rows for products with image_url but no media
    rows = conn.execute(
        sa.text("""
            SELECT p.id, p.image_url, p.created_at
            FROM products p
            WHERE p.image_url IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM product_media pm WHERE pm.product_id = p.id
              )
        """)
    ).fetchall()

    now = datetime.utcnow()
    inserted_count = 0
    for row in rows:
        conn.execute(
            sa.text("""
                INSERT INTO product_media (product_id, media_type, path, sort_order, is_cover, created_at)
                VALUES (:pid, 'image', :path, 0, TRUE, :ts)
            """),
            {"pid": row.id, "path": row.image_url, "ts": row.created_at or now},
        )
        inserted_count += 1

    # 3. Mark existing ProductMedia rows as cover when path matches product.image_url
    conn.execute(
        sa.text("""
            UPDATE product_media pm
            SET is_cover = TRUE
            FROM products p
            WHERE pm.product_id = p.id
              AND p.image_url IS NOT NULL
              AND pm.path = p.image_url
        """)
    )

    # 4. For products with media still unmarked, mark the earliest row as cover
    conn.execute(
        sa.text("""
            UPDATE product_media pm
            SET is_cover = TRUE
            WHERE pm.id IN (
                SELECT MIN(pm2.id)
                FROM product_media pm2
                WHERE (pm2.is_cover IS NULL OR pm2.is_cover = FALSE)
                GROUP BY pm2.product_id
            )
        """)
    )

    # 5. Set explicit sort_order: cover first (0), then by created_at
    conn.execute(
        sa.text("""
            UPDATE product_media pm
            SET sort_order = sub.rn
            FROM (
                SELECT id, ROW_NUMBER() OVER (
                    PARTITION BY product_id
                    ORDER BY
                        CASE WHEN is_cover THEN 0 ELSE 1 END,
                        created_at ASC,
                        id ASC
                ) - 1 AS rn
                FROM product_media
            ) sub
            WHERE pm.id = sub.id
        """)
    )

    # 6. All remaining unmarked is_cover rows default to FALSE
    conn.execute(
        sa.text("UPDATE product_media SET is_cover = FALSE WHERE is_cover IS NULL")
    )
    conn.execute(
        sa.text("UPDATE product_media SET sort_order = 0 WHERE sort_order IS NULL")
    )

    # 7. Set NOT NULL constraints + defaults
    op.alter_column("product_media", "sort_order", nullable=False, server_default=sa.text("0"))
    op.alter_column("product_media", "is_cover", nullable=False, server_default=sa.text("false"))

    print(f"Backfilled {inserted_count} ProductMedia rows from products.image_url")


def downgrade():
    op.drop_column("product_media", "is_cover")
    op.drop_column("product_media", "sort_order")
