"""Supabase Storage helper for production file uploads.

DESIGN PRINCIPLES
-----------------
1. ALWAYS store relative paths in the database, never full HTTPS URLs.
   Stored format: ``{folder}/{uuid}_{timestamp}.{ext}``
   Example: ``avatars/a1b2c3d4e5_1712345678.jpg``

2. URL resolution happens at serve-time only (when building API responses).
   ``SupabaseStorage.get_public_url(path)`` or ``get_signed_url(path)``
   convert the relative path to an absolute HTTPS URL.

3. Single naming strategy:
   ``{uuid_hex}_{unix_timestamp}.{ext}``
   The original filename is discarded (stored as metadata on Supabase instead).

4. No double-path: the path segment inside a bucket is exactly the stored path.
   ``get_public_url("avatars/uuid.jpg")`` →
   ``https://<ref>.supabase.co/storage/v1/object/public/avatars/avatars/uuid.jpg``
   This is correct because the object IS stored at ``avatars/uuid.jpg`` inside the bucket.

5. Validation runs once per upload (in ``save()`` only, not duplicated).

6. Legacy paths (full HTTPS URLs stored before this redesign) are handled
   transparently by ``resolve_image_url()`` on the frontend and
   ``public_url_for_stored_path()`` on the backend.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from typing import BinaryIO

from werkzeug.utils import secure_filename
from flask import current_app

from app.utils.mime_utils import infer_content_type

try:
    from supabase import create_client, Client
except ImportError:
    Client = None

# ── Bucket configuration ──────────────────────────────────────────────────

PUBLIC_BUCKETS = frozenset({"product-images", "avatars", "chat", "misc"})
PRIVATE_BUCKETS = frozenset({"docs"})

# Maps logical upload folder → Supabase bucket name
BUCKET_MAP: dict[str, str] = {
    "product_images": "product-images",
    "seller_avatars": "avatars",
    "avatars": "avatars",
    "buyer_ids": "docs",
    "seller_ids": "docs",
    "seller_dti": "docs",
    "seller_permits": "docs",
    "seller_bir": "docs",
    "rider_docs": "docs",
    "report_evidence": "docs",
    "chat_uploads": "chat",
    "seller_banners": "avatars",
    "product_videos": "product-images",
    "rider_avatars": "avatars",
    "proof_photos": "docs",
}

# ── Upload limits per folder (max_bytes, allowed_mime_prefixes) ───────────

UPLOAD_LIMITS: dict[str, tuple[int, tuple[str, ...]]] = {
    "product_images": (10 * 1024 * 1024, ("image/",)),
    "product_videos": (25 * 1024 * 1024, ("video/",)),
    "avatars": (5 * 1024 * 1024, ("image/",)),
    "seller_avatars": (5 * 1024 * 1024, ("image/",)),
    "seller_banners": (8 * 1024 * 1024, ("image/",)),
    "rider_avatars": (5 * 1024 * 1024, ("image/",)),
    "chat_uploads": (10 * 1024 * 1024, ("image/", "video/", "application/pdf")),
    "buyer_ids": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "seller_ids": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "seller_dti": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "seller_bir": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "seller_permits": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "rider_docs": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "report_evidence": (10 * 1024 * 1024, ("image/", "application/pdf")),
    "proof_photos": (10 * 1024 * 1024, ("image/",)),
}

DEFAULT_MAX_BYTES = 10 * 1024 * 1024
DEFAULT_MIME_PREFIXES = ("image/", "application/pdf", "video/")


# ── Helpers ───────────────────────────────────────────────────────────────


def _get_client() -> Client:
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
    return create_client(url, key)


def folder_to_bucket(folder: str) -> str:
    """Resolve a logical upload folder to its Supabase bucket name."""
    return BUCKET_MAP.get(folder, "misc")


def bucket_is_private(bucket: str) -> bool:
    return bucket in PRIVATE_BUCKETS


def folder_is_private(folder: str) -> bool:
    return bucket_is_private(folder_to_bucket(folder))


def path_is_private(path: str) -> bool:
    """Check if a stored relative path belongs to a private bucket.

    Works with stored paths like ``seller_dti/uuid.pdf`` by finding the
    folder prefix and mapping it through BUCKET_MAP.
    """
    if not path:
        return False
    value = str(path).replace("\\", "/").lstrip("/")
    folder = value.split("/")[0]
    bucket = BUCKET_MAP.get(folder)
    if bucket and bucket in PRIVATE_BUCKETS:
        return True
    return False


def extract_bucket_and_path(stored: str) -> tuple[str, str] | None:
    """Given a stored path (``folder/uuid.ext``), return ``(bucket, path)``.

    Returns ``None`` if the folder prefix is unknown.
    """
    value = str(stored).replace("\\", "/").lstrip("/")
    folder = value.split("/")[0]
    bucket = BUCKET_MAP.get(folder)
    if not bucket:
        return None
    return bucket, value


# ── Validation ────────────────────────────────────────────────────────────


def validate_upload_file(file: BinaryIO, folder: str) -> None:
    """Validate file size and MIME type against folder-specific limits.

    This is called once, from ``SupabaseStorage.save()``.
    """
    from app.utils.mime_utils import is_allowed_upload

    max_bytes, prefixes = UPLOAD_LIMITS.get(
        folder, (DEFAULT_MAX_BYTES, DEFAULT_MIME_PREFIXES)
    )
    stream = file
    pos = stream.tell()
    stream.seek(0, os.SEEK_END)
    size = stream.tell()
    stream.seek(pos)
    if size <= 0:
        raise ValueError("Uploaded file is empty")
    if size > max_bytes:
        raise ValueError(
            f"File exceeds maximum size of {max_bytes // (1024 * 1024)}MB"
        )
    filename = getattr(file, "filename", None)
    reported = getattr(file, "content_type", None)
    content_type = infer_content_type(filename, reported)
    if not is_allowed_upload(filename, content_type, prefixes):
        raise ValueError(
            f"File type '{content_type}' is not allowed for {folder}. "
            f"Allowed: images, PDF, or video (by folder)."
        )


# ── Connection probe (health check) ───────────────────────────────────────


def probe_storage_connection() -> dict:
    """Verify Supabase Storage is reachable (used by /api/health)."""
    result = {
        "configured": False,
        "reachable": False,
        "docs_list_ok": False,
    }
    if not (
        os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY")
    ):
        return result
    result["configured"] = True
    try:
        client = _get_client()
        listing = client.storage.from_("docs").list(
            path="", options={"limit": 1}
        )
        result["reachable"] = True
        result["docs_list_ok"] = listing is not None
    except Exception as exc:
        result["error"] = str(exc)[:200]
    return result


# ── Path generation ───────────────────────────────────────────────────────


def generate_storage_path(
    folder: str,
    *,
    original_filename: str | None = None,
) -> str:
    """Generate a unique, consistent storage path for an uploaded file.

    Format: ``{folder}/{uuid_hex}_{unix_timestamp}.{ext}``

    The original filename is NOT embedded in the path (it is stored as
    metadata on the object and/or in a file_uploads table). Only the file
    extension is preserved from the original name.
    """
    raw = secure_filename(original_filename or "file")
    ext = raw.rsplit(".", 1)[-1] if "." in raw else "bin"
    ts = int(datetime.now(timezone.utc).timestamp())
    unique = f"{folder}/{uuid.uuid4().hex}_{ts}.{ext}"
    return unique


# ── Main storage service ──────────────────────────────────────────────────


class SupabaseStorage:
    """Supabase Storage service for production file uploads.

    All public methods raise ``RuntimeError`` on failure; callers should
    catch and translate to appropriate HTTP responses.
    """

    def __init__(self):
        self._client: Client | None = None

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = _get_client()
        return self._client

    # ── Upload ─────────────────────────────────────────────────────────

    def save(
        self,
        file: BinaryIO,
        folder: str,
        *,
        filename: str | None = None,
    ) -> str:
        """Upload a file to Supabase Storage.

        Args:
            file: The uploaded file object (from ``request.files``).
            folder: Logical folder name (e.g. ``"avatars"``, ``"seller_dti"``).
            filename: Optional override for the stored name. If omitted,
                      derived from the file's native filename.

        Returns:
            A relative path suitable for DB storage:
            ``{folder}/{uuid}_{timestamp}.{ext}``

        Raises:
            ValueError: If validation fails.
            RuntimeError: If the upload call fails.
        """
        # ── 1. Validate ────────────────────────────────────────────────
        validate_upload_file(file, folder)

        # ── 2. Generate storage path ───────────────────────────────────
        raw_name = filename or secure_filename(
            getattr(file, "filename", "file") or "file"
        )
        stored_path = generate_storage_path(folder, original_filename=raw_name)

        bucket = folder_to_bucket(folder)
        content_type = infer_content_type(
            raw_name, getattr(file, "content_type", None)
        )

        original_name = getattr(file, "filename", None)
        original_name_str = str(original_name) if original_name else "uploaded_file"

        # ── 3. Upload ──────────────────────────────────────────────────
        file.seek(0)
        payload = file.read()
        if not payload:
            raise ValueError("Uploaded file is empty")

        try:
            response = self.client.storage.from_(bucket).upload(
                path=stored_path,
                file=payload,
                file_options={
                    "content-type": content_type,
                    "upsert": False,
                    "cache-control": "3600",
                    "x-upsert": "false",
                },
            )
            current_app.logger.info(
                "[storage] uploaded bucket=%s path=%s bytes=%s response=%s",
                bucket,
                stored_path,
                len(payload),
                str(response)[:120],
            )
        except Exception as exc:
            current_app.logger.exception(
                "[storage] upload failed bucket=%s path=%s: %s",
                bucket,
                stored_path,
                exc,
            )
            raise RuntimeError(f"Storage upload failed: {exc}") from exc

        # ── 4. Return relative path (never a full URL) ─────────────────
        return stored_path

    # ── URL resolution ─────────────────────────────────────────────────

    def get_public_url(self, stored_path: str) -> str:
        """Resolve a stored relative path to a public HTTPS URL.

        For private buckets this returns an empty string (use
        ``get_signed_url()`` instead).
        """
        if stored_path.startswith("http://") or stored_path.startswith("https://"):
            return stored_path

        resolved = extract_bucket_and_path(stored_path)
        if not resolved:
            return stored_path

        bucket, path_in_bucket = resolved
        if bucket in PRIVATE_BUCKETS:
            current_app.logger.warning(
                "[storage] get_public_url called for private bucket %s path=%s",
                bucket,
                stored_path,
            )
            return ""

        return self.client.storage.from_(bucket).get_public_url(path_in_bucket)

    def get_signed_url(
        self,
        stored_path: str,
        *,
        expires_in: int = 300,
    ) -> str:
        """Resolve a stored relative path to a time-limited signed URL.

        For public buckets this falls back to ``get_public_url()``.
        """
        if stored_path.startswith("http://") or stored_path.startswith("https://"):
            return stored_path

        resolved = extract_bucket_and_path(stored_path)
        if not resolved:
            return stored_path

        bucket, path_in_bucket = resolved

        if bucket not in PRIVATE_BUCKETS:
            return self.client.storage.from_(bucket).get_public_url(path_in_bucket)

        try:
            result = self.client.storage.from_(bucket).create_signed_url(
                path_in_bucket, expires_in
            )
            return self._parse_signed_url_response(result)
        except Exception as exc:
            current_app.logger.exception(
                "[storage] signed-url failed bucket=%s path=%s: %s",
                bucket,
                path_in_bucket,
                exc,
            )
            raise RuntimeError(f"Failed to generate signed URL: {exc}") from exc

    @staticmethod
    def _parse_signed_url_response(result: object) -> str:
        """Extract the signed URL string from Supabase's response format.

        Supabase-py can return a dict with keys like ``signedURL``,
        or a nested dict under ``data``, or a raw string.
        """
        if isinstance(result, dict):
            inner = result.get("data")
            if isinstance(inner, dict):
                return (
                    inner.get("signedUrl")
                    or inner.get("signedURL")
                    or inner.get("signed_url")
                    or ""
                )
            return (
                result.get("signedURL")
                or result.get("signedUrl")
                or result.get("signed_url")
                or ""
            )
        return str(result)

    # ── Delete ─────────────────────────────────────────────────────────

    def delete(self, stored_path: str) -> None:
        """Delete a file from Supabase Storage by its stored relative path.

        Accepts both relative paths (``folder/uuid.ext``) and legacy full
        HTTPS URLs for backward compatibility.
        """
        value = str(stored_path).replace("\\", "/")

        # Handle legacy full HTTPS URLs
        for bucket in set(BUCKET_MAP.values()):
            marker = f"/storage/v1/object/public/{bucket}/"
            if marker in value:
                internal_path = value.split(marker, 1)[-1]
                self.client.storage.from_(bucket).remove([internal_path])
                return

        resolved = extract_bucket_and_path(value)
        if not resolved:
            current_app.logger.warning(
                "[storage] delete: unknown path format %s", stored_path
            )
            return

        bucket, path_in_bucket = resolved
        try:
            self.client.storage.from_(bucket).remove([path_in_bucket])
            current_app.logger.info(
                "[storage] deleted bucket=%s path=%s", bucket, path_in_bucket
            )
        except Exception as exc:
            current_app.logger.exception(
                "[storage] delete failed bucket=%s path=%s: %s",
                bucket,
                path_in_bucket,
                exc,
            )


# ── Singleton ─────────────────────────────────────────────────────────────

storage = SupabaseStorage()
