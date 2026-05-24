"""Shared helpers for review visibility, validation, serialization, and aggregates."""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy import select, func

from app.models import (
    Review,
    ReviewVisibility,
    Product,
    User,
    Category,
    ProductCategory,
)

ACCESSORIES_SHOES_CATEGORY_NAME = "shoes and accessories"

REVIEW_FORMAT_DEFAULT = "default"
REVIEW_FORMAT_ACCESSORIES = "accessories_shoes"

DIMENSION_KEYS_DEFAULT = [
    "quality",
    "fabricFeel",
    "comfort",
    "fit",
    "appearance",
    "productAccuracy",
    "packaging",
    "deliveryExperience",
]

DIMENSION_KEYS_ACCESSORIES = [
    "quality",
    "comfort",
    "fit",
    "sizingAccuracy",
    "materialQuality",
    "appearance",
    "durability",
    "packaging",
    "deliveryExperience",
]

DELIVERY_PILL_OPTIONS = [
    "On time",
    "Well packaged",
    "Friendly rider",
    "Easy to find",
    "Damaged package",
    "Late delivery",
    "Poor packaging",
    "Rude handling",
]


def review_is_public(review: Review) -> bool:
    if review.deleted_at is not None:
        return False
    vis = (review.visibility or ReviewVisibility.VISIBLE).lower()
    return vis == ReviewVisibility.VISIBLE


def public_review_filter():
    """SQLAlchemy filter clause for buyer-visible reviews."""
    return (
        Review.deleted_at.is_(None),
        Review.visibility == ReviewVisibility.VISIBLE,
    )


def review_format_for_product(product_id: int, db_session) -> str:
    """Return review format based on product category."""
    row = db_session.execute(
        select(Category.name)
        .join(ProductCategory, ProductCategory.category_id == Category.id)
        .where(ProductCategory.product_id == product_id)
    ).first()
    if row and row[0] == ACCESSORIES_SHOES_CATEGORY_NAME:
        return REVIEW_FORMAT_ACCESSORIES
    return REVIEW_FORMAT_DEFAULT


def dimension_keys_for_format(review_format: str) -> list[str]:
    if review_format == REVIEW_FORMAT_ACCESSORIES:
        return DIMENSION_KEYS_ACCESSORIES
    return DIMENSION_KEYS_DEFAULT


def parse_ratings_json(raw: str | None) -> dict[str, int]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return {k: int(v) for k, v in data.items() if v is not None}
    except Exception:
        pass
    return {}


def parse_delivery_pills_json(raw: str | None) -> list[str]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            return [str(x) for x in data if x]
    except Exception:
        pass
    return []


def compute_overall_rating(review_format: str, ratings: dict[str, int], overall_rating: int | None) -> int:
    """Compute canonical overall rating for aggregates."""
    if review_format == REVIEW_FORMAT_DEFAULT:
        if overall_rating is not None and 1 <= overall_rating <= 5:
            return overall_rating
    values = [v for v in ratings.values() if 1 <= v <= 5]
    if values:
        return round(sum(values) / len(values))
    return 5


def validate_review_payload(data: dict, review_format: str) -> tuple[dict | None, str | None]:
    """Validate review submission body. Returns (normalized_dict, error_msg)."""
    ratings_in = data.get("ratings") or {}
    if not isinstance(ratings_in, dict):
        return None, "Invalid ratings"

    keys = dimension_keys_for_format(review_format)
    ratings: dict[str, int] = {}
    for key in keys:
        val = ratings_in.get(key)
        if val is None:
            return None, f"Missing rating for {key}"
        try:
            rating_val = int(val)
        except (TypeError, ValueError):
            return None, f"Invalid rating for {key}"
        if rating_val < 1 or rating_val > 5:
            return None, f"Rating for {key} must be between 1 and 5"
        ratings[key] = rating_val

    overall = data.get("overallRating")
    overall_int: int | None = None
    if overall is not None:
        try:
            overall_int = int(overall)
        except (TypeError, ValueError):
            return None, "Invalid overall rating"
        if overall_int < 1 or overall_int > 5:
            return None, "Overall rating must be between 1 and 5"
    elif review_format == REVIEW_FORMAT_DEFAULT:
        return None, "Overall rating is required"

    delivery_sat = data.get("deliverySatisfaction")
    if delivery_sat is None:
        return None, "Delivery satisfaction is required"
    try:
        delivery_sat_int = int(delivery_sat)
    except (TypeError, ValueError):
        return None, "Invalid delivery satisfaction"
    if delivery_sat_int < 1 or delivery_sat_int > 5:
        return None, "Delivery satisfaction must be between 1 and 5"

    pills_in = data.get("deliveryPills") or []
    if not isinstance(pills_in, list):
        return None, "Invalid delivery pills"
    pills: list[str] = []
    for p in pills_in:
        p_str = str(p).strip()
        if p_str and p_str in DELIVERY_PILL_OPTIONS and p_str not in pills:
            pills.append(p_str)

    customer_review = (data.get("customerReview") or data.get("comment") or "").strip()

    canonical_rating = compute_overall_rating(review_format, ratings, overall_int)

    return {
        "review_format": review_format,
        "ratings": ratings,
        "rating": canonical_rating,
        "comment": customer_review or None,
        "delivery_satisfaction": delivery_sat_int,
        "delivery_pills": pills,
    }, None


def parse_order_item_variant(raw: Any) -> dict | None:
    if not raw:
        return None
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else None
        except Exception:
            import ast

            try:
                parsed = ast.literal_eval(raw)
                return parsed if isinstance(parsed, dict) else None
            except Exception:
                return None
    return None


def format_variant_label(variant: dict | None) -> str | None:
    if not variant:
        return None
    parts = []
    if variant.get("color"):
        parts.append(str(variant["color"]))
    if variant.get("size"):
        parts.append(str(variant["size"]))
    return " / ".join(parts) if parts else None


def serialize_review_row(
    review: Review,
    public_image_url,
    product: Product | None = None,
    buyer: User | None = None,
    order_item=None,
) -> dict:
    images = []
    if review.images_json:
        try:
            images = json.loads(review.images_json) or []
        except Exception:
            images = []

    buyer_name = "Yamada Shopper"
    if buyer:
        buyer_name = (
            f"{buyer.given_name or ''} {buyer.surname or ''}".strip() or buyer.email or buyer_name
        )

    ratings = parse_ratings_json(review.ratings_json)
    delivery_pills = parse_delivery_pills_json(review.delivery_pills_json)
    variant = None
    unit_price = None
    quantity = None
    if order_item is not None:
        variant = format_variant_label(parse_order_item_variant(getattr(order_item, "variation", None)))
        unit_price = getattr(order_item, "unit_price", None)
        quantity = getattr(order_item, "quantity", None)

    return {
        "id": review.id,
        "rating": review.rating,
        "reviewFormat": review.review_format or REVIEW_FORMAT_DEFAULT,
        "ratings": ratings,
        "comment": review.comment,
        "deliverySatisfaction": review.delivery_satisfaction,
        "deliveryPills": delivery_pills,
        "createdAt": review.created_at.isoformat() if review.created_at else None,
        "productId": product.id if product else review.product_id,
        "productName": product.name if product else None,
        "productImage": public_image_url(getattr(product, "image_url", None)) if product else None,
        "buyerName": buyer_name,
        "buyerId": review.buyer_id,
        "verifiedPurchase": True,
        "images": images,
        "sellerReply": review.seller_reply,
        "sellerReplyAt": review.seller_reply_at.isoformat() if review.seller_reply_at else None,
        "visibility": review.visibility or ReviewVisibility.VISIBLE,
        "variant": variant,
        "unitPrice": unit_price,
        "quantity": quantity,
        "orderItemId": review.order_item_id,
        "orderId": getattr(order_item, "order_id", None) if order_item is not None else None,
    }


def compute_dimension_averages(reviews: list[Review]) -> dict[str, float]:
    """Average each dimension across visible reviews."""
    sums: dict[str, list[int]] = {}
    for review in reviews:
        if not review_is_public(review):
            continue
        ratings = parse_ratings_json(review.ratings_json)
        for key, val in ratings.items():
            if 1 <= val <= 5:
                sums.setdefault(key, []).append(val)
    return {
        key: round(sum(vals) / len(vals), 1)
        for key, vals in sums.items()
        if vals
    }


def compute_rating_breakdown(reviews: list[Review]) -> dict[str, int]:
    breakdown = {str(i): 0 for i in range(1, 6)}
    for review in reviews:
        if not review_is_public(review):
            continue
        r = int(review.rating or 0)
        if 1 <= r <= 5:
            breakdown[str(r)] += 1
    return breakdown


def recompute_product_review_stats(product_id: int, db_session) -> None:
    """Update Product.rating and review_count from visible reviews."""
    product = db_session.execute(
        select(Product).where(Product.id == product_id)
    ).scalar_one_or_none()
    if product is None:
        return

    reviews = db_session.execute(
        select(Review).where(Review.product_id == product_id, *public_review_filter())
    ).scalars().all()

    if reviews:
        total = sum(int(r.rating or 0) for r in reviews)
        product.rating = float(total) / float(len(reviews))
        product.review_count = len(reviews)
    else:
        product.rating = 0.0
        product.review_count = 0


def store_visible_reviews_query(store_id: int):
    from app.models import OrderItem

    return (
        select(Review, Product, User, OrderItem)
        .join(Product, Review.product_id == Product.id)
        .outerjoin(User, Review.buyer_id == User.id)
        .outerjoin(OrderItem, Review.order_item_id == OrderItem.id)
        .where(Product.store_id == store_id, *public_review_filter())
    )
