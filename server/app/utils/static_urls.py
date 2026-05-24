"""Build browser-safe URLs for files stored under Flask static."""

from __future__ import annotations

from flask import current_app, url_for


def normalize_static_relative_path(rel_path: str) -> str:
    """Normalize DB paths for URL use (forward slashes, no leading slash)."""
    rel = str(rel_path).replace("\\", "/")
    if rel.startswith("http://") or rel.startswith("https://"):
        return rel
    if rel.startswith("/orders/product_images/"):
        rel = rel[len("/orders/") :]
    return rel.lstrip("/")


def public_static_url(rel_path: str | None) -> str | None:
    """Map a stored relative image path to an absolute static file URL."""
    if not rel_path:
        return None

    raw = str(rel_path).replace("\\", "/")
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw

    rel = normalize_static_relative_path(raw)
    if not rel:
        return None

    try:
        return url_for("static", filename=rel, _external=True)
    except Exception:
        static_prefix = (current_app.static_url_path or "/static").rstrip("/")
        return f"{static_prefix}/{rel}"
