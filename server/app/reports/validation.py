"""Validate report submissions and resolve targets."""

from __future__ import annotations

from sqlalchemy import select

from app.models import (
    Order,
    OrderStatus,
    ReportType,
    RiderDelivery,
    Store,
    db,
)

ALLOWED_TARGETS = {
    "buyer": {"seller", "rider"},
    "seller": {"buyer", "rider"},
    "rider": {"seller", "buyer"},
}

# Default restriction hints when admin punishes without picking one
TYPE_PUNISHMENT_DEFAULTS: dict[str, dict] = {
    "spam": {"severity": "restriction", "restrictionType": "messaging_disabled", "days": None},
    "spam_promotions": {"severity": "restriction", "restrictionType": "messaging_disabled", "days": None},
    "fake_orders": {"severity": "restriction", "restrictionType": "no_ordering", "days": 3},
    "refund_abuse": {"severity": "restriction", "restrictionType": "refund_limited", "days": None},
    "fake_reviews": {"severity": "restriction", "restrictionType": "review_disabled", "days": None},
    "fake_products": {"severity": "restriction", "restrictionType": "listing_suspended", "days": None},
    "delayed_shipping": {"severity": "restriction", "restrictionType": "order_limit", "days": None},
    "scam_activity": {"severity": "restriction", "restrictionType": "withdrawal_freeze", "days": None},
    "review_manipulation": {"severity": "restriction", "restrictionType": "review_disabled", "days": None},
    "delivery_delay_abuse": {"severity": "restriction", "restrictionType": "assignment_reduced", "days": None},
    "fake_delivery_completion": {"severity": "restriction", "restrictionType": "delivery_suspension", "days": 7},
    "location_fraud": {"severity": "restriction", "restrictionType": "tracking_disabled", "days": None},
    "harassment": {"severity": "restriction", "restrictionType": "communication_restricted", "days": None},
}


def _latest_delivery(order_id: int) -> RiderDelivery | None:
    return db.session.execute(
        select(RiderDelivery)
        .where(RiderDelivery.order_id == order_id)
        .order_by(RiderDelivery.created_at.desc())
    ).scalars().first()


def validate_and_resolve_report(
    *,
    reporter_user_id: int,
    reporter_role: str,
    report_type_id: int | None,
    target_user_id: int | None,
    target_role: str | None,
    store_id: int | None,
    order_id: int | None,
) -> tuple[dict, str | None]:
    """
    Validate a report and return resolved fields or an error message.
    Returns ({target_user_id, target_role, store_id, order_id, report_type}, error)
    """
    if not report_type_id:
        return {}, "Report type is required"

    rt = db.session.get(ReportType, report_type_id)
    if rt is None or not rt.is_active:
        return {}, "Invalid report type"

    target_role_norm = (target_role or "").strip().lower() or None
    allowed = ALLOWED_TARGETS.get(reporter_role, set())

    if reporter_role == "buyer":
        if target_role_norm == "seller" or store_id:
            if not store_id:
                return {}, "storeId is required when reporting a store"
            store = db.session.get(Store, store_id)
            if store is None:
                return {}, "Store not found"
            if store.user_id is None:
                return {}, "Store owner not found"
            resolved_role = "seller"
            err = _ensure_report_type_matches_target(rt, resolved_role)
            if err:
                return {}, err
            return {
                "target_user_id": store.user_id,
                "target_role": resolved_role,
                "store_id": store_id,
                "order_id": order_id,
                "report_type": rt,
            }, None

        if target_role_norm == "rider":
            if not order_id:
                return {}, "orderId is required when reporting a rider"
            order = db.session.execute(
                select(Order).where(Order.id == order_id, Order.buyer_id == reporter_user_id)
            ).scalar_one_or_none()
            if order is None:
                return {}, "Order not found"
            if order.status not in (
                OrderStatus.OUT_FOR_DELIVERY,
                OrderStatus.DELIVERED,
                OrderStatus.COMPLETED,
            ):
                return {}, (
                    "Rider reports are available after the order is out for delivery or delivered"
                )
            delivery = _latest_delivery(order.id)
            if delivery is None or not delivery.rider_id:
                return {}, "No rider assigned to this order yet"
            err = _ensure_report_type_matches_target(rt, "rider")
            if err:
                return {}, err
            return {
                "target_user_id": delivery.rider_id,
                "target_role": "rider",
                "store_id": order.store_id,
                "order_id": order.id,
                "report_type": rt,
            }, None

        return {}, "Specify targetRole as seller (with storeId) or rider (with orderId)"

    if reporter_role == "seller":
        if not order_id:
            return {}, "orderId is required"
        store = db.session.execute(
            select(Store).where(Store.user_id == reporter_user_id)
        ).scalar_one_or_none()
        if store is None:
            return {}, "Seller store not found"
        order = db.session.execute(
            select(Order).where(Order.id == order_id, Order.store_id == store.id)
        ).scalar_one_or_none()
        if order is None:
            return {}, "Order not found for your store"

        if target_role_norm == "rider":
            delivery = _latest_delivery(order.id)
            if delivery is None or not delivery.rider_id:
                return {}, "No rider assigned to this order"
            err = _ensure_report_type_matches_target(rt, "rider")
            if err:
                return {}, err
            return {
                "target_user_id": delivery.rider_id,
                "target_role": "rider",
                "store_id": store.id,
                "order_id": order.id,
                "report_type": rt,
            }, None

        if target_role_norm in (None, "buyer"):
            if order.buyer_id is None:
                return {}, "Buyer not found for this order"
            err = _ensure_report_type_matches_target(rt, "buyer")
            if err:
                return {}, err
            return {
                "target_user_id": order.buyer_id,
                "target_role": "buyer",
                "store_id": store.id,
                "order_id": order.id,
                "report_type": rt,
            }, None

        return {}, f"Invalid target role. Allowed: {', '.join(sorted(allowed))}"

    if reporter_role == "rider":
        if not order_id:
            return {}, "orderId is required"

        delivery = db.session.execute(
            select(RiderDelivery).where(
                RiderDelivery.order_id == order_id,
                RiderDelivery.rider_id == reporter_user_id,
            )
        ).scalar_one_or_none()
        if delivery is None:
            delivery = _latest_delivery(order_id)
            if delivery is None or delivery.rider_id != reporter_user_id:
                return {}, "You are not assigned to this delivery"

        order = db.session.get(Order, order_id)
        if order is None:
            return {}, "Order not found"

        if target_role_norm == "buyer":
            if order.buyer_id is None:
                return {}, "Buyer not found for this order"
            err = _ensure_report_type_matches_target(rt, "buyer")
            if err:
                return {}, err
            return {
                "target_user_id": order.buyer_id,
                "target_role": "buyer",
                "store_id": order.store_id,
                "order_id": order.id,
                "report_type": rt,
            }, None

        if target_role_norm in (None, "seller"):
            if order.store_id is None:
                return {}, "Store not found for this order"
            store = db.session.get(Store, order.store_id)
            if store is None or store.user_id is None:
                return {}, "Seller not found for this order"
            err = _ensure_report_type_matches_target(rt, "seller")
            if err:
                return {}, err
            return {
                "target_user_id": store.user_id,
                "target_role": "seller",
                "store_id": store.id,
                "order_id": order.id,
                "report_type": rt,
            }, None

        return {}, f"Invalid target role. Allowed: {', '.join(sorted(allowed))}"

    return {}, "Invalid reporter role"


def _ensure_report_type_matches_target(report_type: ReportType, resolved_target_role: str) -> str | None:
    if report_type.target_role != resolved_target_role:
        return "This report reason does not apply to the person you are reporting"
    return None
