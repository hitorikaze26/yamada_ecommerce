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


def _get_client() -> Client:
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_KEY", "")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
    return create_client(url, key)


BUCKET_MAP = {
    "product_images": "product-images",
    "seller_avatars": "avatars",
    "avatars": "avatars",
    "buyer_ids": "docs",
    "seller_ids": "docs",
    "seller_dti": "docs",
    "seller_bir": "docs",
    "seller_permits": "docs",
    "rider_docs": "docs",
    "report_evidence": "docs",
    "chat_uploads": "chat",
    "seller_banners": "avatars",
    "product_videos": "product-images",
    "rider_avatars": "avatars",
}

ALLOWED_MIME_PREFIXES = ("image/", "application/pdf")


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
        """Upload file to Supabase Storage. Returns public URL."""
        if not filename:
            filename = secure_filename(getattr(file, "filename", "file") or "file")
        ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
        unique = f"{folder}/{uuid.uuid4().hex}_{int(datetime.now(timezone.utc).timestamp())}.{ext}"
        bucket = BUCKET_MAP.get(folder, "misc")
        self.client.storage.from_(bucket).upload(
            path=unique,
            file=file,
            file_options={"content-type": file.content_type or "application/octet-stream"},
        )
        public_url = self.client.storage.from_(bucket).get_public_url(unique)
        return public_url

    def delete(self, url: str) -> None:
        """Delete file by public URL."""
        for bucket in set(BUCKET_MAP.values()):
            try:
                path = url.split(f"{bucket}/")[-1]
                self.client.storage.from_(bucket).remove([path])
                return
            except Exception:
                continue


storage = SupabaseStorage()
