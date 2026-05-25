"""Seed the categories table with the default marketplace categories.

This ensures category rows exist so `createProduct` DB lookups succeed
for the canonical names returned by CATEGORY_ID_TO_NAME.
"""

from alembic import op
from sqlalchemy import text

revision = "v2w3x4y5z6a7"
down_revision = "u7v8w9x0y1z2"
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()
    categories = [
        "Dresses and Skirts",
        "Bottoms",
        "tops and blouses",
        "activewear and yoga pants",
        "lingerie and sleepwear",
        "jackets and coats",
        "shoes and accessories",
    ]
    for name in categories:
        existing = conn.execute(
            text("SELECT 1 FROM categories WHERE name = :name"),
            {"name": name},
        ).fetchone()
        if existing is None:
            conn.execute(
                text("INSERT INTO categories (name) VALUES (:name)"),
                {"name": name},
            )


def downgrade():
    conn = op.get_bind()
    categories = [
        "Dresses and Skirts",
        "Bottoms",
        "tops and blouses",
        "activewear and yoga pants",
        "lingerie and sleepwear",
        "jackets and coats",
        "shoes and accessories",
    ]
    for name in categories:
        conn.execute(
            text("DELETE FROM categories WHERE name = :name"),
            {"name": name},
        )
