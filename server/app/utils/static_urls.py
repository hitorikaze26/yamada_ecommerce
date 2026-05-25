"""Build browser-safe URLs for stored files.

Resolves relative paths to absolute URLs using the appropriate backend:
- Supabase Storage when configured (production)
- Flask static when running locally (development)

This module exists to provide a single function (``public_static_url``)
that is imported by every route blueprint. It delegates to the full
``public_url_for_stored_path()`` when Supabase is active, or falls back
to Flask ``url_for("static", ...)`` for local development.
"""

from __future__ import annotations

import os

from flask import current_app, url_for


def _supabase_configured() -> bool:
    """Check if Supabase Storage env vars are present (no imports needed)."""
    force = os.environ.get("FORCE_SUPABASE_UPLOADS", "").lower() in (
        "1",
        "true",
        "yes",
    )
    has_keys = bool(
        os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY")
    )
    if force:
        return has_keys
    if not has_keys:
        return False
    return True


def public_static_url(rel_path: str | None) -> str | None:
    """Resolve a stored file path to a client-facing absolute URL.

    Delegates to ``public_url_for_stored_path()`` when Supabase Storage
    is active.  Falls back to Flask ``/static/{path}`` for local dev.
    """
    if not rel_path:
        return None

    raw = str(rel_path).replace("\\", "/")
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw

    if _supabase_configured():
        from app.utils.upload import public_url_for_stored_path

        return public_url_for_stored_path(raw) or None

    rel = _normalize_static_relative_path(raw)
    if not rel:
        return None

    try:
        return url_for("static", filename=rel, _external=True)
    except Exception:
        static_prefix = (current_app.static_url_path or "/static").rstrip("/")
        return f"{static_prefix}/{rel}"


def _normalize_static_relative_path(rel_path: str) -> str:
    """Normalize DB paths for URL use (forward slashes, no leading slash)."""
    rel = str(rel_path).replace("\\", "/")
    if rel.startswith("http://") or rel.startswith("https://"):
        return rel
    if rel.startswith("/orders/product_images/"):
        rel = rel[len("/orders/") :]
    return rel.lstrip("/")
