"""Supabase Storage helper for production file uploads (replaces local filesystem)."""
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

PUBLIC_BUCKETS = frozenset({"product-images", "avatars", "chat", "misc"})
PRIVATE_BUCKETS = frozenset({"docs"})

BUCKET_MAP = {
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
}

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
}

DEFAULT_MAX_BYTES = 10 * 1024 * 1024
DEFAULT_MIME_PREFIXES = ("image/", "application/pdf", "video/")


def _get_client() -> Client:
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
    return create_client(url, key)


def is_private_bucket(bucket: str) -> bool:
    return bucket in PRIVATE_BUCKETS


def is_private_stored_path(stored: str) -> bool:
    if not stored:
        return False
    value = str(stored).replace("\\", "/").lstrip("/")
    if value.startswith("docs/"):
        return True
    for folder, bucket in BUCKET_MAP.items():
        if bucket in PRIVATE_BUCKETS and value.startswith(f"{folder}/"):
            return True
    return False


def validate_upload_file(file: BinaryIO, folder: str) -> None:
    from app.utils.mime_utils import is_allowed_upload

    max_bytes, prefixes = UPLOAD_LIMITS.get(folder, (DEFAULT_MAX_BYTES, DEFAULT_MIME_PREFIXES))
    stream = file
    pos = stream.tell()
    stream.seek(0, os.SEEK_END)
    size = stream.tell()
    stream.seek(pos)
    if size <= 0:
        raise ValueError("Uploaded file is empty")
    if size > max_bytes:
        raise ValueError(f"File exceeds maximum size of {max_bytes // (1024 * 1024)}MB")
    filename = getattr(file, "filename", None)
    reported = getattr(file, "content_type", None)
    content_type = infer_content_type(filename, reported)
    if not is_allowed_upload(filename, content_type, prefixes):
        raise ValueError(
            f"File type '{content_type}' is not allowed for {folder}. "
            f"Allowed: images, PDF, or video (by folder)."
        )


def probe_storage_connection() -> dict:
    """Verify Supabase Storage is reachable (used by /api/health)."""
    result = {"configured": False, "reachable": False, "docs_list_ok": False}
    if not (os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_KEY")):
        return result
    result["configured"] = True
    try:
        client = _get_client()
        listing = client.storage.from_("docs").list(path="", options={"limit": 1})
        result["reachable"] = True
        result["docs_list_ok"] = listing is not None
    except Exception as exc:
        result["error"] = str(exc)[:200]
    return result


class SupabaseStorage:
    """Drop-in replacement for local file saves."""

    def __init__(self):
        self._client = None

    @property
    def client(self) -> Client:
        if self._client is None:
            self._client = _get_client()
        return self._client

    def save(self, file: BinaryIO, folder: str, filename: str | None = None) -> str:
        """Upload file to Supabase Storage."""
        validate_upload_file(file, folder)
        raw_name = filename or secure_filename(getattr(file, "filename", "file") or "file")
        ext = raw_name.rsplit(".", 1)[-1] if "." in raw_name else "bin"
        unique = f"{folder}/{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}.{ext}"
        bucket = BUCKET_MAP.get(folder, "misc")
        content_type = infer_content_type(raw_name, getattr(file, "content_type", None))

        file.seek(0)
        payload = file.read()
        if not payload:
            raise ValueError("Uploaded file is empty")

        try:
            response = self.client.storage.from_(bucket).upload(
                path=unique,
                file=payload,
                file_options={
                    "content-type": content_type,
                    "upsert": False,
                    "cache-control": "3600",
                },
            )
            current_app.logger.info(
                "[storage] uploaded bucket=%s path=%s bytes=%s response=%s",
                bucket,
                unique,
                len(payload),
                str(response)[:120],
            )
        except Exception as exc:
            current_app.logger.exception(
                "[storage] upload failed bucket=%s path=%s: %s", bucket, unique, exc
            )
            raise RuntimeError(f"Storage upload failed: {exc}") from exc

        if is_private_bucket(bucket):
            return f"{bucket}/{unique}"
        return self.client.storage.from_(bucket).get_public_url(unique)

    def create_signed_url(self, bucket: str, path: str, expires_in: int = 300) -> str:
        if bucket not in PRIVATE_BUCKETS:
            return self.client.storage.from_(bucket).get_public_url(path)
        result = self.client.storage.from_(bucket).create_signed_url(path, expires_in)
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

    def delete(self, url: str) -> None:
        value = str(url).replace("\\", "/")
        for bucket in set(BUCKET_MAP.values()):
            marker = f"/storage/v1/object/public/{bucket}/"
            if marker in value:
                path = value.split(marker, 1)[-1]
                self.client.storage.from_(bucket).remove([path])
                return
            if value.startswith(f"{bucket}/"):
                path = value[len(f"{bucket}/") :]
                self.client.storage.from_(bucket).remove([path])
                return


storage = SupabaseStorage()
