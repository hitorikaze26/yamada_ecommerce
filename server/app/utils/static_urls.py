"""Build browser-safe URLs for stored files.

Resolves relative paths to absolute URLs using the appropriate backend:
- Supabase Storage when configured (production)
- Flask static when running locally (development)

This module exists to provide a single function (``public_static_url``)
that is imported by every route blueprint. It delegates to the full
``public_url_for_stored_path()`` when Supabase is active, or falls back
to Flask ``url_for("static", ...)`` for local development.

NOTE: The function name ``public_static_url`` is historical but
misleading — it now handles Supabase URLs too.
"""

from __future__ import annotations

from flask import current_app, url_for


def public_static_url(rel_path: str | None) -> str | None:
    """Resolve a stored file path to a client-facing absolute URL.

    Delegates to ``public_url_for_stored_path()`` when Supabase Storage
    is active.  Falls back to Flask ``/static/{path}`` for local dev.

    This function is imported by all route blueprints (as
    ``_public_image_url``) and is the single entry point for URL
    resolution on the backend.
    """
    if not rel_path:
        return None

    # Already a full URL — pass through
    raw = str(rel_path).replace("\\", "/")
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw

    # Supabase Storage (production)
    from app.utils.upload import use_supabase_storage as _supabase_active

    if _supabase_active():
        from app.utils.upload import public_url_for_stored_path

        return public_url_for_stored_path(raw) or None

    # Local filesystem (development)
    rel = normalize_static_relative_path(raw)
    if not rel:
        return None

    try:
        return url_for("static", filename=rel, _external=True)
    except Exception:
        static_prefix = (current_app.static_url_path or "/static").rstrip("/")
        return f"{static_prefix}/{rel}"


def normalize_static_relative_path(rel_path: str) -> str:
    """Normalize DB paths for URL use (forward slashes, no leading slash)."""
    rel = str(rel_path).replace("\\", "/")
    if rel.startswith("http://") or rel.startswith("https://"):
        return rel
    if rel.startswith("/orders/product_images/"):
        rel = rel[len("/orders/") :]
    return rel.lstrip("/")
