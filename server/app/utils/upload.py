"""Unified file upload: Supabase Storage in production, local static in development.

PRINCIPLES
----------
1. All stored DB paths use the same relative format:
   ``{folder}/{uuid}_{timestamp}.{ext}``  (e.g. ``avatars/a1b2c3_1712345678.jpg``)

2. URL resolution (relative → absolute HTTPS) happens at serve-time only,
   in ``public_url_for_stored_path()`` or via the frontend's ``resolveImageUrl()``.

3. Development (local filesystem) stores files under ``app/static/{folder}/``
   and generates ``/static/{folder}/{file}`` URLs.

4. The ``save_upload()`` function delegates to ``SupabaseStorage.save()``;
   validation runs once in the storage layer, not duplicated here.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone

from flask import current_app
from werkzeug.utils import secure_filename

from app.utils.supabase_storage import storage, path_is_private


# ── Supabase detection ───────────────────────────────────────────────────


def use_supabase_storage() -> bool:
    """Use Supabase when configured (keys present, or explicit force)."""
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


# ── Save ──────────────────────────────────────────────────────────────────


def save_upload(
    file,
    folder: str,
    *,
    filename: str | None = None,
) -> str:
    """Save an uploaded file.

    Returns a relative path string suitable for DB storage:
    ``{folder}/{uuid}_{timestamp}.{ext}``

    In development (local filesystem), files are saved to
    ``app/static/{folder}/`` and the returned path is relative to the
    static directory.

    In production (Supabase Storage), files are uploaded to the
    appropriate bucket and the returned path is the bucket-relative path.
    """
    if use_supabase_storage():
        return storage.save(file, folder, filename=filename)

    # ── Local filesystem (development) ────────────────────────────────
    upload_root = current_app.static_folder or os.path.join(
        current_app.root_path, "static"
    )
    target_dir = os.path.join(upload_root, folder)
    os.makedirs(target_dir, exist_ok=True)

    raw_name = filename or secure_filename(
        getattr(file, "filename", "file") or "file"
    )
    stored_name = (
        f"{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}_"
        f"{secure_filename(raw_name)}"
    )

    filepath = os.path.join(target_dir, stored_name)
    file.save(filepath)
    return os.path.join(folder, stored_name).replace("\\", "/")


# ── URL resolution ────────────────────────────────────────────────────────


def public_url_for_stored_path(
    stored: str | None,
    *,
    allow_private: bool = False,
) -> str:
    """Build a client-facing absolute URL from a stored path.

    Args:
        stored: The path as stored in the DB (relative path or legacy HTTPS URL).
        allow_private: If True, return a signed URL for private bucket files.
                       If False, return empty string for private files.

    Resolution order:
        1. Empty / None → empty string
        2. Already an HTTPS URL → pass through
        3. Supabase Storage (public) → ``get_public_url()``
        4. Supabase Storage (private, allowed) → ``get_signed_url()``
        5. Supabase Storage (private, not allowed) → empty string
        6. Local filesystem → ``/static/{path}`` via Flask
    """
    if not stored:
        return ""

    value = str(stored).replace("\\", "/")

    if value.startswith("http://") or value.startswith("https://"):
        return value

    if use_supabase_storage():
        is_private = path_is_private(value)

        if is_private and not allow_private:
            return ""

        if is_private and allow_private:
            try:
                return storage.get_signed_url(value, expires_in=300)
            except Exception:
                current_app.logger.exception(
                    "Failed to sign private storage URL: %s", value
                )
                return ""

        try:
            return storage.get_public_url(value)
        except Exception:
            current_app.logger.exception(
                "Failed to resolve public storage URL: %s", value
            )
            pass

    from app.utils.static_urls import public_static_url as _fallback_url

    return _fallback_url(value) or ""
