"""Seller store insights, followers, wishlist stats, and review management."""

from __future__ import annotations

import datetime as dt
import logging

from flask import jsonify, request, abort
from flask_jwt_extended import current_user, jwt_required
from sqlalchemy import func, select, desc, asc
from sqlalchemy.orm import selectinload

from app.decorators import seller_required
from app.models import (
    Review,
    ReviewVisibility,
    Product,
    Store,
    Seller,
    StoreFollow,
    WishlistItem,
    User,
    OrderItem,
)
from app.notifications.service import create_notification
from app.review_utils import public_review_filter, serialize_review_row

from . import seller as seller_bp, db
from .routes import _public_image_url

logger = logging.getLogger(__name__)


def _seller_store():
    seller = db.session.execute(
        select(Seller).where(Seller.user_id == current_user.id)
    ).scalar_one_or_none()
    if seller is None:
        return None, None
    store = db.session.execute(
        select(Store).where(Store.seller_id == seller.id)
    ).scalar_one_or_none()
    return seller, store


@seller_bp.get("/insights")
@jwt_required()
@seller_required()
def get_seller_insights():
    _, store = _seller_store()
    if store is None:
        return jsonify(
            rating=0.0,
            reviewCount=0,
            followersCount=0,
            wishlistBuyerCount=0,
            wishlistProductBreakdown=[],
            ratingBreakdown={str(i): 0 for i in range(1, 6)},
        ), 200

    review_rows = db.session.execute(
        select(Review.rating)
        .join(Product, Review.product_id == Product.id)
        .where(Product.store_id == store.id, *public_review_filter())
    ).all()
    ratings = [int(r[0] or 0) for r in review_rows if r[0]]
    review_count = len(ratings)
    avg_rating = round(sum(ratings) / review_count, 1) if review_count else 0.0

    breakdown = {str(i): 0 for i in range(1, 6)}
    for r in ratings:
        if 1 <= r <= 5:
            breakdown[str(r)] += 1

    followers_count = (
        db.session.execute(
            select(func.count(StoreFollow.id)).where(StoreFollow.store_id == store.id)
        ).scalar()
        or 0
    )

    wishlist_buyer_count = (
        db.session.execute(
            select(func.count(func.distinct(WishlistItem.user_id)))
            .join(Product, WishlistItem.product_id == Product.id)
            .where(Product.store_id == store.id)
        ).scalar()
        or 0
    )

    wishlist_rows = db.session.execute(
        select(
            Product.id,
            Product.name,
            func.count(WishlistItem.id).label("wish_count"),
        )
        .join(WishlistItem, WishlistItem.product_id == Product.id)
        .where(Product.store_id == store.id)
        .group_by(Product.id, Product.name)
        .order_by(desc("wish_count"))
        .limit(10)
    ).all()

    breakdown_products = [
        {
            "productId": row.id,
            "productName": row.name,
            "wishlistCount": int(row.wish_count or 0),
        }
        for row in wishlist_rows
    ]

    return jsonify(
        storeId=store.id,
        rating=avg_rating,
        reviewCount=review_count,
        followersCount=int(followers_count),
        wishlistBuyerCount=int(wishlist_buyer_count),
        wishlistProductBreakdown=breakdown_products,
        ratingBreakdown=breakdown,
    ), 200


@seller_bp.get("/followers")
@jwt_required()
@seller_required()
def get_seller_followers():
    _, store = _seller_store()
    if store is None:
        return jsonify(followers=[], total=0), 200

    page = request.args.get("page", type=int) or 1
    per_page = min(request.args.get("perPage", type=int) or 30, 100)
    offset = (page - 1) * per_page

    total = (
        db.session.execute(
            select(func.count(StoreFollow.id)).where(StoreFollow.store_id == store.id)
        ).scalar()
        or 0
    )

    rows = db.session.execute(
        select(StoreFollow, User)
        .join(User, StoreFollow.user_id == User.id)
        .where(StoreFollow.store_id == store.id)
        .order_by(StoreFollow.created_at.desc())
        .offset(offset)
        .limit(per_page)
    ).all()

    followers = []
    for follow, user in rows:
        name = f"{user.given_name or ''} {user.surname or ''}".strip() or user.email
        followers.append(
            {
                "userId": user.id,
                "name": name,
                "email": user.email,
                "followedAt": follow.created_at.isoformat() if follow.created_at else None,
            }
        )

    return jsonify(followers=followers, total=int(total), page=page), 200


@seller_bp.get("/wishlist-insights")
@jwt_required()
@seller_required()
def get_wishlist_insights():
    _, store = _seller_store()
    if store is None:
        return jsonify(products=[], totalWishlists=0, uniqueBuyers=0), 200

    unique_buyers = (
        db.session.execute(
            select(func.count(func.distinct(WishlistItem.user_id)))
            .join(Product, WishlistItem.product_id == Product.id)
            .where(Product.store_id == store.id)
        ).scalar()
        or 0
    )

    rows = db.session.execute(
        select(
            Product.id,
            Product.name,
            Product.image_url,
            func.count(WishlistItem.id).label("wish_count"),
        )
        .join(WishlistItem, WishlistItem.product_id == Product.id)
        .where(Product.store_id == store.id)
        .group_by(Product.id, Product.name, Product.image_url)
        .order_by(desc("wish_count"))
    ).all()

    products = [
        {
            "productId": r.id,
            "productName": r.name,
            "imageUrl": _public_image_url(r.image_url),
            "wishlistCount": int(r.wish_count or 0),
        }
        for r in rows
    ]
    total_wishlists = sum(p["wishlistCount"] for p in products)

    return jsonify(
        products=products,
        totalWishlists=total_wishlists,
        uniqueBuyers=int(unique_buyers),
    ), 200


def _reviews_for_store_query(store_id: int, status_filter: str):
    q = (
        select(Review, Product, User, OrderItem)
        .join(Product, Review.product_id == Product.id)
        .outerjoin(User, Review.buyer_id == User.id)
        .outerjoin(OrderItem, Review.order_item_id == OrderItem.id)
        .where(Product.store_id == store_id, Review.deleted_at.is_(None))
    )
    sf = (status_filter or "all").lower()
    if sf == "visible":
        q = q.where(Review.visibility == ReviewVisibility.VISIBLE)
    elif sf == "hidden":
        q = q.where(Review.visibility == ReviewVisibility.HIDDEN)
    elif sf == "archived":
        q = q.where(Review.visibility == ReviewVisibility.ARCHIVED)
    return q


def _seller_review_row(review_id: int, store_id: int):
    """Load review with product/buyer/order item for the seller's store."""
    return db.session.execute(
        select(Review, Product, User, OrderItem)
        .join(Product, Review.product_id == Product.id)
        .outerjoin(User, Review.buyer_id == User.id)
        .outerjoin(OrderItem, Review.order_item_id == OrderItem.id)
        .where(
            Review.id == review_id,
            Product.store_id == store_id,
            Review.deleted_at.is_(None),
        )
    ).first()


def _serialize_seller_review_row(row) -> dict:
    review, product, buyer, order_item = row
    return serialize_review_row(review, _public_image_url, product, buyer, order_item)


@seller_bp.get("/reviews")
@jwt_required()
@seller_required()
def list_seller_reviews():
    _, store = _seller_store()
    if store is None:
        return jsonify(reviews=[], total=0), 200

    sort = (request.args.get("sort") or "newest").lower()
    status_filter = request.args.get("status") or "all"
    page = request.args.get("page", type=int) or 1
    per_page = min(request.args.get("perPage", type=int) or 20, 50)
    offset = (page - 1) * per_page

    base = _reviews_for_store_query(store.id, status_filter)
    total = (
        db.session.execute(
            select(func.count(Review.id))
            .select_from(Review)
            .join(Product, Review.product_id == Product.id)
            .where(
                Product.store_id == store.id,
                Review.deleted_at.is_(None),
                *(
                    [Review.visibility == ReviewVisibility.VISIBLE]
                    if status_filter == "visible"
                    else [Review.visibility == ReviewVisibility.HIDDEN]
                    if status_filter == "hidden"
                    else [Review.visibility == ReviewVisibility.ARCHIVED]
                    if status_filter == "archived"
                    else []
                ),
            )
        ).scalar()
        or 0
    )

    order = Review.created_at.desc()
    if sort == "oldest":
        order = Review.created_at.asc()
    elif sort == "rating_high":
        order = desc(Review.rating)
    elif sort == "rating_low":
        order = asc(Review.rating)

    rows = db.session.execute(
        base.order_by(order).offset(offset).limit(per_page)
    ).all()

    reviews = [
        serialize_review_row(review, _public_image_url, product, buyer, order_item)
        for review, product, buyer, order_item in rows
    ]

    return jsonify(reviews=reviews, total=int(total), page=page), 200


@seller_bp.post("/reviews/<int:review_id>/reply")
@jwt_required()
@seller_required()
def reply_to_review(review_id: int):
    data = request.get_json(silent=True) or {}
    reply_text = (data.get("reply") or data.get("message") or "").strip()
    if not reply_text:
        return jsonify(msg="Reply text is required"), 400

    _, store = _seller_store()
    if store is None:
        return jsonify(msg="Store not found"), 404

    row = _seller_review_row(review_id, store.id)
    if row is None:
        return jsonify(msg="Review not found"), 404

    review, product, _buyer, _order_item = row
    now = dt.datetime.utcnow()
    review.seller_reply = reply_text
    review.seller_reply_at = now
    review.updated_at = now

    try:
        db.session.commit()
    except Exception as exc:
        db.session.rollback()
        logger.exception("Failed to save seller reply for review %s", review_id)
        return jsonify(msg="Failed to save reply"), 500

    notification_warning = None
    if review.buyer_id:
        try:
            create_notification(
                user_id=review.buyer_id,
                title="Seller replied to your review",
                message=f"The seller replied to your review on {product.name}.",
                role="buyer",
                page=f"/product/{product.id}",
                category="reviews",
                ntype="in_app",
                data={"reviewId": review.id, "productId": product.id},
            )
            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            notification_warning = "Reply saved; buyer notification could not be sent."
            logger.warning(
                "Reply saved for review %s but notification failed: %s",
                review_id,
                exc,
            )

    row = _seller_review_row(review_id, store.id)
    payload = {"msg": "Reply saved", "review": _serialize_seller_review_row(row)}
    if notification_warning:
        payload["warning"] = notification_warning
    return jsonify(payload), 200


@seller_bp.delete("/reviews/<int:review_id>/reply")
@jwt_required()
@seller_required()
def delete_review_reply(review_id: int):
    _, store = _seller_store()
    if store is None:
        return jsonify(msg="Store not found"), 404

    row = _seller_review_row(review_id, store.id)
    if row is None:
        return jsonify(msg="Review not found"), 404

    review, _product, _buyer, _order_item = row
    if not (review.seller_reply or "").strip():
        return jsonify(msg="No seller reply to delete"), 400

    review.seller_reply = None
    review.seller_reply_at = None
    review.updated_at = dt.datetime.utcnow()

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        logger.exception("Failed to delete seller reply for review %s", review_id)
        return jsonify(msg="Failed to delete reply"), 500

    row = _seller_review_row(review_id, store.id)
    return jsonify(
        msg="Reply removed",
        review=_serialize_seller_review_row(row),
    ), 200


@seller_bp.patch("/reviews/<int:review_id>")
@jwt_required()
@seller_required()
def moderate_review(review_id: int):
    if not request.is_json:
        abort(400)
    data = request.get_json() or {}

    _, store = _seller_store()
    if store is None:
        return jsonify(msg="Store not found"), 404

    review = db.session.execute(
        select(Review)
        .join(Product, Review.product_id == Product.id)
        .where(Review.id == review_id, Product.store_id == store.id)
    ).scalar_one_or_none()

    if review is None:
        return jsonify(msg="Review not found"), 404

    if data.get("delete") is True:
        review.deleted_at = dt.datetime.utcnow()
        review.visibility = ReviewVisibility.HIDDEN
    else:
        visibility = data.get("visibility")
        if visibility in {
            ReviewVisibility.VISIBLE,
            ReviewVisibility.HIDDEN,
            ReviewVisibility.ARCHIVED,
        }:
            review.visibility = visibility

    review.updated_at = dt.datetime.utcnow()
    product_id = review.product_id
    db.session.commit()

    if product_id is not None:
        from app.review_utils import recompute_product_review_stats

        recompute_product_review_stats(product_id, db.session)
        db.session.commit()

    return jsonify(msg="Review updated"), 200
