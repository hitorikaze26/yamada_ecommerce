"""Unified file upload: Supabase Storage in production, local static in development."""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone

from flask import current_app  # used in public_url_for_stored_path error logging
from werkzeug.utils import secure_filename


def use_supabase_storage() -> bool:
    """Use Supabase when configured (production with keys, or explicit force)."""
    if os.environ.get("FORCE_SUPABASE_UPLOADS", "").lower() in ("1", "true", "yes"):
        return bool(os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY"))
    if os.environ.get("FLASK_ENV", "development") != "production":
        return False
    return bool(os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY"))


def save_upload(
    file,
    folder: str,
    *,
    filename: str | None = None,
) -> str:
    """Save an uploaded file.

    Returns:
        - Full HTTPS public URL when using Supabase Storage (public buckets)
        - Bucket-relative path for private docs (e.g. ``docs/rider_docs/...``)
        - Relative path under static/ (e.g. ``product_images/foo.jpg``) for local disk
    """
    if use_supabase_storage():
        from app.utils.supabase_storage import storage, validate_upload_file

        validate_upload_file(file, folder)
        name = filename
        if not name:
            raw = secure_filename(getattr(file, "filename", None) or "file")
            name = f"{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}_{raw}"
        return storage.save(file, folder, filename=name)

    upload_root = current_app.static_folder or os.path.join(
        current_app.root_path, "static"
    )
    target_dir = os.path.join(upload_root, folder)
    os.makedirs(target_dir, exist_ok=True)

    if filename:
        stored_name = secure_filename(filename)
    else:
        raw = secure_filename(getattr(file, "filename", None) or "file")
        stored_name = f"{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}_{raw}"

    filepath = os.path.join(target_dir, stored_name)
    file.save(filepath)
    return os.path.join(folder, stored_name).replace("\\", "/")


def public_url_for_stored_path(stored: str, *, allow_private: bool = False) -> str:
    """Build a client-facing URL for a DB-stored path or Supabase URL."""
    if not stored:
        return ""
    value = str(stored).replace("\\", "/")
    if value.startswith("http://") or value.startswith("https://"):
        return value

    if use_supabase_storage():
        from app.utils.supabase_storage import (
            BUCKET_MAP,
            is_private_stored_path,
            storage,
            is_private_bucket,
        )

        if is_private_stored_path(value) and not allow_private:
            return ""

        if "/" in value and not value.startswith("static/"):
            bucket, _, path = value.partition("/")
            if is_private_bucket(bucket) and allow_private:
                try:
                    return storage.create_signed_url(bucket, path, expires_in=300)
                except Exception:
                    current_app.logger.exception("Failed to sign private storage URL")
                    return ""
            if bucket in BUCKET_MAP.values() and not is_private_bucket(bucket):
                try:
                    return storage.client.storage.from_(bucket).get_public_url(path)
                except Exception:
                    pass

    from app.utils.static_urls import public_static_url

    return public_static_url(value) or ""
