"""Admin API privacy helpers — scrub sensitive fields from responses."""

from __future__ import annotations

SENSITIVE_USER_FIELDS = frozenset({
    "password_hash",
    "password",
    "passwordHash",
    "otp",
    "otp_code",
    "otpCode",
    "refresh_token",
    "refreshToken",
    "access_token",
    "accessToken",
    "jwt",
    "token",
})


def assert_no_sensitive_payload(payload: dict) -> None:
    """Dev-time guard: raise if sensitive keys appear in a dict."""
    for key in payload:
        if key in SENSITIVE_USER_FIELDS:
            raise ValueError(f"Sensitive field '{key}' must not appear in admin API responses")


def serialize_user_for_admin(user) -> dict:
    try:
        data = user.to_json() if hasattr(user, "to_json") else {}
    except Exception:
        data = {
            "id": getattr(user, "id", None),
            "email": getattr(user, "email", ""),
            "username": getattr(user, "username", ""),
        }
    for field in SENSITIVE_USER_FIELDS:
        data.pop(field, None)
    try:
        assert_no_sensitive_payload(data)
    except ValueError:
        for field in SENSITIVE_USER_FIELDS:
            data.pop(field, None)
    return data


def serialize_users_for_admin(users) -> list[dict]:
    """Serialize many users; skip rows that fail instead of failing the whole list."""
    payload: list[dict] = []
    for user in users:
        try:
            payload.append(serialize_user_for_admin(user))
        except Exception:
            continue
    return payload


def serialize_order_for_admin(order_dict: dict) -> dict:
    """Wrap order serializer output with an explicit allowlist for support use."""
    allowed = {
        "id",
        "orderNumber",
        "buyerId",
        "storeId",
        "status",
        "subtotal",
        "shipping",
        "total",
        "totalAmount",
        "shippingFee",
        "grandTotal",
        "adminCommission",
        "paymentMethod",
        "createdAt",
        "updatedAt",
        "items",
        "buyer",
        "store",
        "shippingAddress",
        "shippingAddressParts",
        "riderDelivery",
        "deliveries",
        "financialBreakdown",
        "paymentTransaction",
        "notes",
    }
    result = {k: v for k, v in order_dict.items() if k in allowed}
    if "buyer" in result and isinstance(result["buyer"], dict):
        result["buyer"] = serialize_user_for_admin_dict(result["buyer"])
    assert_no_sensitive_payload(result)
    return result


def serialize_user_for_admin_dict(data: dict) -> dict:
    cleaned = dict(data)
    for field in SENSITIVE_USER_FIELDS:
        cleaned.pop(field, None)
    return cleaned


def serialize_refund_for_admin(refund_dict: dict) -> dict:
    """Refund admin view — include dispute/evidence fields, scrub nested users."""
    result = dict(refund_dict)
    if "buyer" in result and isinstance(result["buyer"], dict):
        result["buyer"] = serialize_user_for_admin_dict(result["buyer"])
    if "seller" in result and isinstance(result["seller"], dict):
        result["seller"] = serialize_user_for_admin_dict(result["seller"])
    assert_no_sensitive_payload(result)
    return result
