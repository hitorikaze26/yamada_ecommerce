"""Add color_hex column to product_variations."""

import sqlalchemy as sa
from alembic import op

revision = "z1a2b3c4d5e6"
down_revision = "y9z1a2b3c4d5"
branch_labels = None
depends_on = None


COMMON_COLORS: dict[str, str] = {
    "red": "#FF0000", "blue": "#0000FF", "green": "#008000", "yellow": "#FFFF00",
    "black": "#000000", "white": "#FFFFFF", "gray": "#808080", "grey": "#808080",
    "pink": "#FFC0CB", "purple": "#800080", "orange": "#FFA500", "brown": "#A52A2A",
    "navy": "#000080", "teal": "#008080", "maroon": "#800000", "coral": "#FF7F50",
    "cream": "#FFFDD0", "beige": "#F5F5DC", "tan": "#D2B48C", "gold": "#FFD700",
    "silver": "#C0C0C0", "lime": "#00FF00", "olive": "#808000", "indigo": "#4B0082",
    "violet": "#EE82EE", "turquoise": "#40E0D0", "cyan": "#00FFFF", "magenta": "#FF00FF",
    "lavender": "#E6E6FA", "mint": "#98FF98", "peach": "#FFDAB9", "rose": "#FF007F",
    "champagne": "#F7E7CE", "ivory": "#FFFFF0", "charcoal": "#36454F", "taupe": "#483C32",
    "burgundy": "#800020", "wine": "#722F37", "blush": "#DE5D83", "mauve": "#E0B0FF",
    "mustard": "#FFDB58", "seafoam": "#9FE2BF", "ruby": "#E0115F", "emerald": "#50C878",
    "sapphire": "#0F52BA", "pearl": "#FDF5E6", "bronze": "#CD7F32", "copper": "#B87333",
    "rust": "#B7410E", "plum": "#DDA0DD", "sage": "#BCB88A", "khaki": "#C3B091",
    "tomato": "#FF6347", "salmon": "#FA8072", "apricot": "#FBCEB1", "cinnamon": "#D2691E",
    "cranberry": "#9B1B30", "raspberry": "#E30B5D", "sky blue": "#87CEEB",
    "baby blue": "#89CFF0", "royal blue": "#4169E1", "dark blue": "#00008B",
    "light blue": "#ADD8E6", "forest green": "#228B22", "dark green": "#006400",
    "light green": "#90EE90", "dark grey": "#A9A9A9", "light grey": "#D3D3D3",
    "dark gray": "#A9A9A9", "light gray": "#D3D3D3", "hot pink": "#FF69B4",
    "deep pink": "#FF1493", "pale pink": "#FADADD", "dusty rose": "#C9A9A6",
    "camel": "#C19A6B", "caramel": "#C68E17", "chocolate": "#7B3F00",
    "coffee": "#6F4E37", "denim": "#1560BD", "military green": "#4B5320",
    "neon": "#00FF41", "pastel": "#FADADD",
}


def _color_name_to_hex(name: str | None) -> str | None:
    if not name:
        return None
    cleaned = name.strip().lower()
    if cleaned.startswith("#"):
        return cleaned[:7]
    if cleaned in COMMON_COLORS:
        return COMMON_COLORS[cleaned]
    return None


def upgrade():
    op.add_column("product_variations", sa.Column("color_hex", sa.String(7), nullable=True))

    conn = op.get_bind()
    rows = conn.execute(
        sa.text("SELECT id, color FROM product_variations WHERE color IS NOT NULL AND (color_hex IS NULL OR color_hex = '')")
    ).fetchall()

    updated = 0
    for row in rows:
        hex_val = _color_name_to_hex(row.color)
        if hex_val:
            conn.execute(
                sa.text("UPDATE product_variations SET color_hex = :hex WHERE id = :id"),
                {"hex": hex_val, "id": row.id},
            )
            updated += 1

    print(f"Backfilled color_hex for {updated} variations")


def downgrade():
    op.drop_column("product_variations", "color_hex")
