import json
from datetime import datetime

from flask import current_app, jsonify, request
from flask_jwt_extended import jwt_required
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.models import (
    Category,
    ProductCategory,
    ChatSettings,
    Order,
    OrderSettings,
    OrderStatus,
    Product,
    ProductModerationStatus,
    Review,
    Seller,
    ShippingSettings,
    ShopCustomization,
    Store,
    StoreFollow,
    StoreRegistration,
    StoreRequestStatus,
    User,
    db,
)

from . import stores_public


from app.utils.static_urls import public_static_url as _public_image_url


def _store_rating_stats(store_id: int) -> tuple[float, int]:
    row = db.session.execute(
        select(
            func.coalesce(func.avg(Product.rating), 0),
            func.coalesce(func.sum(Product.review_count), 0),
        ).where(
            Product.store_id == store_id,
            Product.moderation_status == ProductModerationStatus.ACTIVE,
            Product.is_live.is_(True),
        )
    ).one()
    return float(row[0] or 0), int(row[1] or 0)


def _trust_badges(
    is_verified: bool,
    rating: float,
    review_count: int,
    response_rate: float,
    cancellation_rate: float,
) -> list[str]:
    badges: list[str] = []
    if is_verified:
        badges.append("verified_seller")
    if rating >= 4.5 and review_count >= 5:
        badges.append("top_rated")
    if response_rate >= 90:
        badges.append("responsive_seller")
    if cancellation_rate <= 5:
        badges.append("fast_shipper")
    return badges


def _serialize_store_card(store: Store) -> dict:
    seller = store.seller
    registration = seller.registration if seller else None
    rating, review_count = _store_rating_stats(store.id)
    logo = _public_image_url(getattr(seller, "avatar_path", None)) if seller else None
    return {
        "id": store.id,
        "store_id": store.id,
        "store_name": store.store_name,
        "name": store.store_name,
        "tagline": registration.tagline if registration else None,
        "logo_url": logo,
        "image_url": logo,
        "rating": round(rating, 1),
        "review_count": review_count,
        "is_verified": bool(
            registration
            and registration.request_status.name == StoreRequestStatus.ACCEPTED.name
        ),
    }


@stores_public.get("/featured")
def featured_stores():
    """Featured boutiques for home/search discovery."""
    limit = request.args.get("limit", type=int) or 6
    try:
        stores = (
            db.session.execute(
                select(Store).order_by(Store.created_at.desc()).limit(limit)
            )
            .scalars()
            .all()
        )
        return jsonify(stores=[_serialize_store_card(s) for s in stores]), 200
    except Exception:
        db.session.rollback()
        return jsonify(stores=[]), 200


def _serialize_store_product(product: Product, store_name: str, categories: list[str]) -> dict:
    images: list[str] = []
    if product.image_url:
        url = _public_image_url(product.image_url)
        if url:
            images.append(url)
    for media in getattr(product, "media", []) or []:
        if media.media_type == "image" and media.path:
            url = _public_image_url(media.path)
            if url and url not in images:
                images.append(url)

    slug = getattr(product, "slug", None) or str(product.id)

    return {
        "id": product.id,
        "slug": slug,
        "name": product.name,
        "category": categories[0] if categories else getattr(product, "subcategory", None) or "",
        "subcategory": getattr(product, "subcategory", None),
        "categories": categories,
        "description": product.description or "",
        "images": images,
        "image_url": images[0] if images else None,
        "price": float(product.price or 0),
        "sale_price": float(product.sale_price) if product.sale_price is not None else None,
        "salePrice": float(product.sale_price) if product.sale_price is not None else None,
        "brand": product.brand,
        "rating": float(getattr(product, "rating", 0) or 0),
        "review_count": int(getattr(product, "review_count", 0) or 0),
        "reviewCount": int(getattr(product, "review_count", 0) or 0),
        "store_id": product.store_id,
        "sellerId": str(product.store_id),
        "seller_name": store_name,
        "sellerName": store_name,
        "is_live": bool(getattr(product, "is_live", True)),
        "visibility": bool(getattr(product, "is_live", True)),
        "created_at": product.created_at.isoformat() if product.created_at else None,
        "createdAt": product.created_at.isoformat() if product.created_at else None,
        "updated_at": (
            product.updated_at.isoformat()
            if product.updated_at
            else (product.created_at.isoformat() if product.created_at else None)
        ),
        "updatedAt": (
            product.updated_at.isoformat()
            if product.updated_at
            else (product.created_at.isoformat() if product.created_at else None)
        ),
        "variations": [
            {
                "id": v.id,
                "size": v.size,
                "color": v.color,
                "sku": v.sku,
                "inventory": getattr(v, "inventory", 0),
                "price": float(v.price) if v.price is not None else None,
            }
            for v in getattr(product, "variations", []) or []
        ],
    }


def _resolve_store(store_id: int) -> Store | None:
    store = db.session.execute(select(Store).where(Store.id == store_id)).scalar_one_or_none()
    if store is not None:
        return store
    return db.session.execute(
        select(Store).where(Store.seller_id == store_id)
    ).scalar_one_or_none()


@stores_public.get("/<int:store_id>")
@jwt_required(optional=True)
def get_store_profile(store_id: int):
    """Public boutique storefront profile for buyers."""
    store = _resolve_store(store_id)
    if store is None:
        return jsonify(msg="Store not found"), 404

    seller = store.seller
    registration = seller.registration if seller else None
    user = store.user

    categories: list[str] = []
    if registration and registration.categories_json:
        try:
            parsed = json.loads(registration.categories_json)
            if isinstance(parsed, list):
                categories = [str(c) for c in parsed]
        except Exception:
            categories = []

    rating, review_count = _store_rating_stats(store.id)

    product_count = db.session.execute(
        select(func.count(Product.id)).where(
            Product.store_id == store.id,
            Product.moderation_status == ProductModerationStatus.ACTIVE,
            Product.is_live.is_(True),
        )
    ).scalar() or 0

    total_orders = (
        db.session.execute(
            select(func.count(Order.id)).where(Order.store_id == store.id)
        ).scalar()
        or 0
    )
    cancelled = (
        db.session.execute(
            select(func.count(Order.id)).where(
                Order.store_id == store.id,
                Order.status == OrderStatus.CANCELLED,
            )
        ).scalar()
        or 0
    )
    cancellation_rate = (cancelled / total_orders * 100) if total_orders else 0.0

    completed = (
        db.session.execute(
            select(func.count(Order.id)).where(
                Order.store_id == store.id,
                Order.status.in_([OrderStatus.DELIVERED, OrderStatus.COMPLETED]),
            )
        ).scalar()
        or 0
    )

    shipping_rows = db.session.execute(
        select(ShippingSettings).where(
            ShippingSettings.store_id == store.id,
            ShippingSettings.is_active.is_(True),
        )
    ).scalars().all()

    order_settings = db.session.execute(
        select(OrderSettings).where(OrderSettings.store_id == store.id)
    ).scalar_one_or_none()

    chat_settings = db.session.execute(
        select(ChatSettings).where(ChatSettings.store_id == store.id)
    ).scalar_one_or_none()

    customization = db.session.execute(
        select(ShopCustomization).where(ShopCustomization.store_id == store.id)
    ).scalar_one_or_none()

    is_verified = bool(
        registration
        and registration.request_status.name == StoreRequestStatus.ACCEPTED.name
    )

    response_rate = 96.0 if chat_settings and chat_settings.auto_reply_enabled else 88.0
    trust_badges = _trust_badges(
        is_verified, rating, review_count, response_rate, cancellation_rate
    )

    now = datetime.now()
    is_open = 9 <= now.hour < 21

    profile = {
        "id": store.id,
        "store_id": store.id,
        "store_name": store.store_name,
        "name": store.store_name,
        "tagline": (registration.tagline if registration else None) or "",
        "description": store.description or (registration.store_purpose if registration else ""),
        "email": store.store_email,
        "phone": store.store_phone_number,
        "address": store.address,
        "country": store.country,
        "logo_url": _public_image_url(getattr(seller, "avatar_path", None)) if seller else None,
        "banner_url": _public_image_url(getattr(seller, "banner_path", None)) if seller else None,
        "rating": round(rating, 1),
        "review_count": review_count,
        "followers_count": int(
            db.session.execute(
                select(func.count(StoreFollow.id)).where(StoreFollow.store_id == store.id)
            ).scalar()
            or 0
        ),
        "response_rate": response_rate,
        "response_time": "Usually replies within 1 hour"
        if chat_settings and chat_settings.auto_reply_enabled
        else "Typically replies within 24 hours",
        "joined_at": store.created_at.isoformat() if store.created_at else None,
        "is_verified": is_verified,
        "is_open": is_open,
        "business_hours": "Mon–Sun · 9:00 AM – 9:00 PM",
        "last_active": "Active today",
        "is_online": is_open,
        "product_count": int(product_count),
        "completed_orders": int(completed),
        "cancellation_rate": round(cancellation_rate, 1),
        "shipping_regions_count": len(shipping_rows),
        "shipping_summary": f"Ships to {len(shipping_rows)} locations"
        if shipping_rows
        else "Nationwide shipping available",
        "categories": categories,
        "announcement": customization.announcement if customization else None,
        "trust_badges": trust_badges,
        "seller": {
            "id": seller.id if seller else None,
            "full_name": seller.full_name if seller else None,
        },
        "policies": {
            "allow_cancellation": order_settings.allow_cancellation if order_settings else True,
            "max_cancellation_hours": order_settings.max_cancellation_hours if order_settings else 24,
            "allow_returns": order_settings.allow_returns if order_settings else True,
            "return_period_days": order_settings.return_period_days if order_settings else 7,
        },
        "vouchers": [],
        "live_selling": {"is_live": False, "title": None},
    }

    return jsonify(store=profile), 200


@stores_public.get("/<int:store_id>/products")
@jwt_required(optional=True)
def get_store_products(store_id: int):
    """Live products for a storefront (full payload for mobile Product model)."""
    store = _resolve_store(store_id)
    if store is None:
        return jsonify(msg="Store not found"), 404

    limit = request.args.get("limit", type=int) or 100
    sort_param = request.args.get("sort")

    try:
        stmt = (
            select(Product)
            .where(
                Product.store_id == store.id,
                Product.moderation_status == ProductModerationStatus.ACTIVE,
                Product.is_live.is_(True),
            )
            .options(
                selectinload(Product.variations),
                selectinload(Product.media),
            )
        )
        if sort_param == "newest":
            stmt = stmt.order_by(Product.created_at.desc())
        elif sort_param == "popular":
            stmt = stmt.order_by(Product.rating.desc(), Product.review_count.desc())
        else:
            stmt = stmt.order_by(Product.created_at.desc())

        products = db.session.execute(stmt.limit(limit)).scalars().all()

        product_ids = [p.id for p in products]
        categories_by_product: dict[int, list[str]] = {pid: [] for pid in product_ids}
        if product_ids:
            cat_rows = db.session.execute(
                select(ProductCategory.product_id, Category.name)
                .join(Category, ProductCategory.category_id == Category.id)
                .where(ProductCategory.product_id.in_(product_ids))
            ).all()
            for row in cat_rows:
                categories_by_product.setdefault(row.product_id, []).append(row.name)

        data = [
            _serialize_store_product(
                p,
                store.store_name,
                categories_by_product.get(p.id, []),
            )
            for p in products
        ]
        return jsonify(products=data), 200
    except Exception:
        db.session.rollback()
        return jsonify(products=[]), 200


@stores_public.get("/<int:store_id>/reviews")
@jwt_required(optional=True)
def get_store_reviews(store_id: int):
    limit = request.args.get("limit", type=int) or 30
    store = _resolve_store(store_id)
    if store is None:
        return jsonify(msg="Store not found"), 404

    try:
        from app.review_utils import public_review_filter, serialize_review_row
        from app.models import OrderItem

        rows = db.session.execute(
            select(Review, Product, User, OrderItem)
            .join(Product, Review.product_id == Product.id)
            .outerjoin(User, Review.buyer_id == User.id)
            .outerjoin(OrderItem, Review.order_item_id == OrderItem.id)
            .where(Product.store_id == store.id, *public_review_filter())
            .order_by(Review.created_at.desc())
            .limit(limit)
        ).all()

        result = [
            serialize_review_row(review, _public_image_url, product, buyer, order_item)
            for review, product, buyer, order_item in rows
        ]

        breakdown = {str(i): 0 for i in range(1, 6)}
        for item in result:
            key = str(int(item.get("rating") or 0))
            if key in breakdown:
                breakdown[key] += 1

        return jsonify(reviews=result, breakdown=breakdown), 200
    except Exception:
        db.session.rollback()
        return jsonify(reviews=[], breakdown={}), 200
