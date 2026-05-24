"""Coupon validation and serialization helpers."""
from datetime import datetime

from sqlalchemy import select, func

from app.models import Coupon, CouponRedemption, db


def serialize_coupon(c: Coupon) -> dict:
    return {
        "id": c.id,
        "code": c.code,
        "title": c.title,
        "description": c.description or "",
        "discountType": c.discount_type,
        "discount_type": c.discount_type,
        "discountValue": float(c.discount_value),
        "discount_value": float(c.discount_value),
        "minOrderAmount": float(c.min_order_amount or 0),
        "min_order_amount": float(c.min_order_amount or 0),
        "maxUses": c.max_uses,
        "max_uses": c.max_uses,
        "usedCount": c.used_count,
        "used_count": c.used_count,
        "expiresAt": c.expires_at.isoformat() if c.expires_at else None,
        "expires_at": c.expires_at.isoformat() if c.expires_at else None,
        "isActive": c.is_active,
        "is_active": c.is_active,
        "scope": c.scope,
        "storeId": c.store_id,
        "store_id": c.store_id,
    }


def validate_coupon(*, code: str, user_id: int, store_id: int | None, subtotal: float) -> tuple[Coupon | None, float, str]:
    """Return (coupon, discount_amount, message). discount 0 if invalid."""
    normalized = (code or "").strip().upper()
    if not normalized:
        return None, 0.0, "Coupon code is required"

    coupon = db.session.execute(
        select(Coupon).where(func.upper(Coupon.code) == normalized, Coupon.is_active.is_(True))
    ).scalar_one_or_none()

    if coupon is None:
        return None, 0.0, "Invalid or inactive coupon code"

    if coupon.expires_at and coupon.expires_at < datetime.now():
        return None, 0.0, "This coupon has expired"

    if coupon.max_uses is not None and coupon.used_count >= coupon.max_uses:
        return None, 0.0, "This coupon has reached its usage limit"

    if subtotal < float(coupon.min_order_amount or 0):
        return None, 0.0, f"Minimum order amount is {coupon.min_order_amount}"

    if coupon.scope == "store":
        if store_id is None or coupon.store_id != store_id:
            return None, 0.0, "This coupon is not valid for this store"

    if coupon.discount_type == "percent":
        discount = round(subtotal * float(coupon.discount_value) / 100.0, 2)
    else:
        discount = min(float(coupon.discount_value), subtotal)

    if discount <= 0:
        return None, 0.0, "Coupon does not apply to this order"

    return coupon, discount, "Coupon applied"
