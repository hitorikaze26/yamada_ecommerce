"""Format order shipping_address stored as JSON / Python dict strings."""

from __future__ import annotations

import ast
import json
from typing import Any, Optional


def _normalize_parts(data: dict) -> dict[str, Optional[str]]:
    return {
        "streetAddress": data.get("streetAddress") or data.get("street_address"),
        "barangayName": data.get("barangayName") or data.get("barangay_name"),
        "municipalityName": data.get("municipalityName") or data.get("municipality_name"),
        "provinceName": data.get("provinceName") or data.get("province_name"),
        "regionName": data.get("regionName") or data.get("region_name"),
        "postalCode": data.get("postalCode") or data.get("postal_code"),
    }


def _parts_to_string(parts: dict[str, Optional[str]]) -> Optional[str]:
    ordered = [
        parts.get("streetAddress"),
        parts.get("barangayName"),
        parts.get("municipalityName"),
        parts.get("provinceName"),
        parts.get("regionName"),
        parts.get("postalCode"),
    ]
    values = [str(p).strip() for p in ordered if p and str(p).strip()]
    return ", ".join(values) if values else None


def format_shipping_address(raw_address: Any) -> Optional[str]:
    """Return a human-readable address or None."""
    if raw_address is None:
        return None
    if isinstance(raw_address, dict):
        return _parts_to_string(_normalize_parts(raw_address))

    text = str(raw_address).strip()
    if not text:
        return None

    if not (text.startswith("{") and ("street" in text.lower() or "barangay" in text.lower())):
        return text

    data: Optional[dict] = None
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            data = parsed
    except (json.JSONDecodeError, TypeError):
        pass

    if data is None:
        try:
            parsed = ast.literal_eval(text)
            if isinstance(parsed, dict):
                data = parsed
        except (SyntaxError, ValueError, TypeError):
            pass

    if data is None:
        return text

    return _parts_to_string(_normalize_parts(data)) or text
