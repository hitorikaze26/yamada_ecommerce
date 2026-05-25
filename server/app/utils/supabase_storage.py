"""Supabase Storage helper for production file uploads (replaces local filesystem)."""
import os
import uuid
from datetime import datetime, timezone
from typing import BinaryIO

from werkzeug.utils import secure_filename
from flask import current_app

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

# folder -> (max_bytes, allowed mime prefixes)
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
    max_bytes, prefixes = UPLOAD_LIMITS.get(folder, (DEFAULT_MAX_BYTES, DEFAULT_MIME_PREFIXES))
    stream = file
    pos = stream.tell()
    stream.seek(0, os.SEEK_END)
    size = stream.tell()
    stream.seek(pos)
    if size > max_bytes:
        raise ValueError(f"File exceeds maximum size of {max_bytes // (1024 * 1024)}MB")
    content_type = (getattr(file, "content_type", None) or "application/octet-stream").lower()
    if not any(content_type.startswith(p) for p in prefixes):
        raise ValueError(f"File type '{content_type}' is not allowed for {folder}")


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
        """Upload file to Supabase Storage.

        Returns public HTTPS URL for public buckets, or a relative storage path
        (e.g. docs/rider_docs/uuid.jpg) for private buckets.
        """
        validate_upload_file(file, folder)
        if not filename:
            filename = secure_filename(getattr(file, "filename", "file") or "file")
        ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
        unique = f"{folder}/{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}.{ext}"
        bucket = BUCKET_MAP.get(folder, "misc")
        file.seek(0)
        self.client.storage.from_(bucket).upload(
            path=unique,
            file=file.read(),
            file_options={
                "content-type": getattr(file, "content_type", None) or "application/octet-stream",
                "upsert": "false",
            },
        )
        if is_private_bucket(bucket):
            return f"{bucket}/{unique}"
        return self.client.storage.from_(bucket).get_public_url(unique)

    def create_signed_url(self, bucket: str, path: str, expires_in: int = 300) -> str:
        """Generate a short-lived signed URL for private bucket objects."""
        if bucket not in PRIVATE_BUCKETS:
            return self.client.storage.from_(bucket).get_public_url(path)
        result = self.client.storage.from_(bucket).create_signed_url(path, expires_in)
        if isinstance(result, dict):
            return result.get("signedURL") or result.get("signedUrl") or ""
        return str(result)

    def delete(self, url: str) -> None:
        """Delete file by public URL or stored path."""
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
