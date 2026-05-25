"""MIME helpers for uploads when browsers send empty or generic types."""

from __future__ import annotations

EXT_TO_MIME: dict[str, str] = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "gif": "image/gif",
    "heic": "image/heic",
    "heif": "image/heif",
    "pdf": "application/pdf",
    "mp4": "video/mp4",
    "webm": "video/webm",
}


def infer_content_type(filename: str | None, reported: str | None) -> str:
    """Prefer a real MIME type; infer from extension when missing or octet-stream."""
    reported_norm = (reported or "").strip().lower()
    if reported_norm and reported_norm not in ("application/octet-stream", "binary/octet-stream"):
        return reported_norm

    name = (filename or "").lower()
    if "." in name:
        ext = name.rsplit(".", 1)[-1]
        if ext in EXT_TO_MIME:
            return EXT_TO_MIME[ext]
    return reported_norm or "application/octet-stream"


def is_allowed_mime(content_type: str, allowed_prefixes: tuple[str, ...]) -> bool:
    ct = (content_type or "").lower()
    if any(ct.startswith(prefix) for prefix in allowed_prefixes):
        return True
    if ct in ("application/octet-stream", "binary/octet-stream"):
        return False
    return False


def is_allowed_upload(
    filename: str | None,
    reported_mime: str | None,
    allowed_prefixes: tuple[str, ...],
    *,
    extra_exact: frozenset[str] = frozenset(
        {"application/x-pdf", "image/heic", "image/heif"}
    ),
) -> bool:
    content_type = infer_content_type(filename, reported_mime)
    if content_type in extra_exact:
        return True
    return is_allowed_mime(content_type, allowed_prefixes)
