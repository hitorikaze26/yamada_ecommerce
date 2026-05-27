from __future__ import annotations

"""Centralized helpers for creating and querying notifications.

These helpers wrap the bare SQLAlchemy model so the rest of the codebase
has a small, well‑named API to work with for different roles and events.

NOTE: The current Notification model only supports:
  - user_id, title, body, role, page, created_at, read
The richer spec you provided (category, type, data, etc.) can be layered
on later via a schema and migration. For now we accept a few extra
fields but only persist what the model supports.
"""

from typing import Any, List, Optional

from flask import current_app, has_app_context
from sqlalchemy import event

from app.models import db, Notification, User

_PENDING_EMITS_KEY = "pending_notification_emits"
_PENDING_EMAILS_KEY = "pending_notification_emails"


def serialize_notification(n: Notification) -> dict[str, Any]:
    return {
        "id": n.id,
        "userId": n.user_id,
        "title": n.title,
        "description": n.body,
        "createdAt": n.created_at.isoformat() if n.created_at else None,
        "read": n.read,
        "role": n.role,
        "page": n.page,
    }


def _queue_realtime_emit(n: Notification) -> None:
    pending = db.session.info.setdefault(_PENDING_EMITS_KEY, [])
    pending.append(serialize_notification(n))


def _queue_notification_email(n: Notification) -> None:
    pending = db.session.info.setdefault(_PENDING_EMAILS_KEY, [])

    user = db.session.get(User, n.user_id)
    user_email = user.email if user is not None and user.active else None

    pending.append(
        {
            "user_id": n.user_id,
            "title": n.title,
            "message": n.body,
            "page": n.page,
            "role": n.role,
            "_email": user_email,
        }
    )


@event.listens_for(db.session, "after_commit")
def _emit_pending_notifications(session) -> None:
    pending = session.info.pop(_PENDING_EMITS_KEY, None)
    if pending:
        from .realtime import emit_to_user

        for payload in pending:
            user_id = payload.get("userId")
            if user_id is not None:
                emit_to_user(int(user_id), "notification", payload)

    pending_emails = session.info.pop(_PENDING_EMAILS_KEY, None)
    if not pending_emails:
        return

    from app.services.email_service import send_notification_email

    for item in pending_emails:
        user_email = item.get("_email")
        if not user_email:
            continue
        try:
            send_notification_email(
                to_email=user_email,
                title=item["title"],
                message=item["message"],
                page=item.get("page"),
                role=item.get("role"),
            )
        except Exception:
            if has_app_context():
                current_app.logger.exception(
                    "Failed to send notification email to user %s",
                    item["user_id"],
                )


# ---------------------------------------------------------------------------
# Core helpers (all roles)
# ---------------------------------------------------------------------------


def create_notification(
    *,
    user_id: int,
    role: Optional[str] = None,
    title: str,
    message: str,
    page: Optional[str] = None,
    category: Optional[str] = None,  # currently informational only
    ntype: Optional[str] = None,  # "in_app" | "email" | "realtime" (unused for now)
    data: Optional[dict[str, Any]] = None,  # structured payload (unused for now)
) -> Notification:
    """Enqueue a notification in the current DB session.

    The caller is responsible for committing/rolling back. Extra parameters
    like category / ntype / data are accepted for forward‑compatibility but
    are not yet persisted because the underlying model does not expose
    dedicated columns.
    """

    n = Notification(
        user_id=user_id,
        title=title,
        body=message,
        role=role,
        page=page,
    )
    db.session.add(n)
    db.session.flush()
    _queue_realtime_emit(n)
    _queue_notification_email(n)
    return n


def notify_buyer_refund_requested(*, user_id: int, order_id: int) -> Notification:
    """Notify a buyer that their refund request was submitted."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Refund requested",
        message=f"Your refund request for order #{order_id} has been submitted.",
        page="/orders",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_buyer_refund_approved(*, user_id: int, order_id: int) -> Notification:
    """Notify a buyer that their refund was approved."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Refund approved",
        message=f"Your refund request for order #{order_id} has been approved.",
        page="/orders",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_buyer_refund_declined(*, user_id: int, order_id: int) -> Notification:
    """Notify a buyer that their refund was declined."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Refund declined",
        message=f"Your refund request for order #{order_id} has been declined.",
        page="/orders",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_buyer_promo_discount_alert(*, user_id: int, title: str, message: str) -> Notification:
    """Notify a buyer about a promotional discount or voucher."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title=title,
        message=message,
        page="/buyer",
        category="promotions",
        ntype="in_app",
    )


def notify_buyer_product_back_in_stock(*, user_id: int, product_name: str) -> Notification:
    """Notify a buyer when a product they follow is back in stock."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Product back in stock",
        message=f"'{product_name}' is back in stock.",
        page="/buyer",
        category="orders",
        ntype="in_app",
    )


def mark_as_read(notification_id: int) -> bool:
    """Mark a single notification as read.

    Returns True if a row was affected, False otherwise.
    """

    n = db.session.get(Notification, notification_id)
    if n is None:
        return False
    n.read = True
    db.session.add(n)
    return True


def get_notifications(
    user_id: int,
    *,
    limit: Optional[int] = None,
    unread_only: bool = False,
) -> List[Notification]:
    """Fetch notifications for a user, newest first.

    This is a convenience wrapper around simple filtering logic; most
    HTTP endpoints should continue to own their own serialization.
    """

    query = Notification.query.filter_by(user_id=user_id)

    if unread_only:
        query = query.filter_by(read=False)

    query = query.order_by(Notification.created_at.desc())

    if limit is not None and limit > 0:
        query = query.limit(limit)

    return list(query.all())


def push_realtime_notification(user_id: int, payload: dict[str, Any]) -> None:
    """Emit a notification payload immediately (e.g. after mark-read sync)."""
    from .realtime import emit_to_user

    emit_to_user(user_id, "notification", payload)


def emit_notifications_read(user_id: int, *, role: str | None = None) -> None:
    """Tell connected clients to refresh unread badge after bulk read."""
    from .realtime import emit_to_user

    emit_to_user(user_id, "notifications_read", {"role": role})


# ---------------------------------------------------------------------------
# Role‑specific convenience helpers
# ---------------------------------------------------------------------------


# Buyer helpers -------------------------------------------------------------


def notify_buyer_order_status(
    *,
    user_id: int,
    order_id: int,
    status_label: str,
) -> Notification:
    """Notify a buyer about an order status change."""

    title = "Order status updated"
    message = f"Your order #{order_id} status is now {status_label}."
    return create_notification(
        user_id=user_id,
        role="buyer",
        title=title,
        message=message,
        page="/orders",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id, "status": status_label},
    )


def notify_buyer_account_approved(*, user_id: int) -> Notification:
    """Notify a buyer that their account has been approved."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Account approved",
        message="Your buyer account has been approved.",
        page="/buyer/profile",
        category="system",
        ntype="in_app",
    )


def notify_buyer_account_rejected(*, user_id: int) -> Notification:
    """Notify a buyer that their account has been rejected."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Account rejected",
        message="Your buyer account has been rejected by an administrator.",
        page="/buyer/profile",
        category="system",
        ntype="in_app",
    )


# Seller helpers ------------------------------------------------------------


def notify_seller_new_order(*, user_id: int, order_id: int) -> Notification:
    """Notify a seller when a new order is placed."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="New order received",
        message=f"You have received a new order #{order_id}.",
        page="/seller",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_seller_payout_released(*, user_id: int, order_id: int, amount: float) -> Notification:
    """Notify a seller when a payout has been credited to their wallet."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Payout released",
        message=f"Funds from order #{order_id} (₱{amount:.2f}) have been credited to your wallet.",
        page="/seller",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id, "amount": amount},
    )


def notify_seller_low_stock_alert(*, user_id: int, product_name: str, stock_level: int) -> Notification:
    """Notify a seller when stock for a product is low."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Low stock alert",
        message=f"Stock for '{product_name}' is low (remaining: {stock_level}).",
        page="/seller/products",
        category="seller_management",
        ntype="in_app",
    )


def notify_seller_stock_depleted(*, user_id: int, product_name: str) -> Notification:
    """Notify a seller when stock for a product is depleted."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Stock depleted",
        message=f"Stock for '{product_name}' has been depleted.",
        page="/seller/products",
        category="seller_management",
        ntype="in_app",
    )


def notify_rider_pickup_update(*, user_id: int, order_id: int, new_location: str) -> Notification:
    """Notify a rider when the pickup location for a delivery has changed."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="Pickup location updated",
        message=f"Pickup location for order #{order_id} has been updated: {new_location}.",
        page="/rider/dashboard",
        category="logistics",
        ntype="in_app",
        data={"orderId": order_id, "newLocation": new_location},
    )


def notify_rider_delivery_cancellation(*, user_id: int, order_id: int) -> Notification:
    """Notify a rider that a delivery has been cancelled."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="Delivery cancelled",
        message=f"Delivery for order #{order_id} has been cancelled.",
        page="/rider/dashboard",
        category="logistics",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_rider_proof_of_delivery(*, user_id: int, order_id: int) -> Notification:
    """Notify a rider when proof of delivery has been uploaded/accepted."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="Proof of delivery received",
        message=f"Proof of delivery for order #{order_id} has been recorded.",
        page="/rider/dashboard",
        category="logistics",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_seller_product_approval(
    *,
    user_id: int,
    product_name: str,
    approved: bool,
) -> Notification:
    """Notify a seller when a product is approved/rejected."""

    if approved:
        title = "Product approved"
        message = f"Your product '{product_name}' has been approved."
    else:
        title = "Product rejected"
        message = f"Your product '{product_name}' has been rejected by admin."

    return create_notification(
        user_id=user_id,
        role="seller",
        title=title,
        message=message,
        page="/seller/products",
        category="seller_management",
        ntype="in_app",
    )


def notify_rider_account_approved(*, user_id: int) -> Notification:
    """Notify a rider that their account has been approved."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="Rider account approved",
        message="Your rider account has been approved.",
        page="/rider/dashboard",
        category="system",
        ntype="in_app",
    )


def notify_rider_account_rejected(*, user_id: int) -> Notification:
    """Notify a rider that their account has been rejected."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="Rider account rejected",
        message="Your rider account has been rejected by an administrator.",
        page="/rider/dashboard",
        category="system",
        ntype="in_app",
    )


# Admin helpers -------------------------------------------------------------


def notify_admin_new_seller_application(*, admin_user_id: int, application_id: int) -> Notification:
    """Notify an admin that a new seller application has been submitted.

    This assumes you have some mechanism to choose which admin user
    receives the notification.
    """

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="New seller application",
        message=f"Seller application #{application_id} requires review.",
        page="/admin/sellers",
        category="seller_management",
        ntype="in_app",
        data={"applicationId": application_id},
    )


def notify_admin_product_pending_approval(*, admin_user_id: int, product_id: int) -> Notification:
    """Notify an admin that a product is awaiting approval."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Product pending approval",
        message=f"Product #{product_id} is pending approval.",
        page="/admin/products",
        category="seller_management",
        ntype="in_app",
        data={"productId": product_id},
    )


def notify_admin_order_issue_reported(*, admin_user_id: int, order_id: int) -> Notification:
    """Notify an admin that an order issue was reported."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Order issue reported",
        message=f"An issue has been reported for order #{order_id}.",
        page="/admin/orders",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_admin_refund_request_submitted(*, admin_user_id: int, order_id: int) -> Notification:
    """Notify an admin that a refund request was submitted."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Refund request submitted",
        message=f"A refund request has been submitted for order #{order_id}.",
        page="/admin/refunds",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_admin_inventory_issue_detected(*, admin_user_id: int, message: str) -> Notification:
    """Notify an admin about an inventory-related system issue."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Inventory issue detected",
        message=message,
        page="/admin/system",
        category="system",
        ntype="in_app",
    )


def notify_admin_system_warning(*, admin_user_id: int, message: str) -> Notification:
    """Generic system warning for admins (errors, alerts, etc.)."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="System warning",
        message=message,
        page="/admin/system",
        category="system",
        ntype="in_app",
    )


def notify_admin_rider_verification_needed(*, admin_user_id: int, rider_user_id: int) -> Notification:
    """Notify an admin that a rider verification is pending/needed."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Rider verification needed",
        message=f"Rider user #{rider_user_id} requires verification.",
        page="/admin/riders",
        category="system",
        ntype="in_app",
        data={"riderUserId": rider_user_id},
    )


def notify_seller_store_registration_approved(*, user_id: int) -> Notification:
    """Notify a seller that their store registration has been approved."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Store registration approved",
        message="Your store registration has been approved.",
        page="/seller/dashboard",
        category="seller_management",
        ntype="in_app",
    )


def notify_seller_store_registration_rejected(*, user_id: int) -> Notification:
    """Notify a seller that their store registration has been rejected."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Store registration rejected",
        message="Your store registration has been rejected.",
        page="/seller/dashboard",
        category="seller_management",
        ntype="in_app",
    )


def notify_seller_refund_requested(*, user_id: int, order_id: int) -> Notification:
    """Notify a seller that a buyer submitted a refund request."""

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Refund request received",
        message=f"A buyer requested a refund for order #{order_id}. Please review it.",
        page="/seller/refunds",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_seller_product_moderation(
    *,
    user_id: int,
    product_name: str,
    status: str,
    reason: str | None = None,
) -> Notification:
    """Notify a seller about product moderation status changes."""

    status_labels = {
        "active": "restored to Active",
        "under_review": "Under Review",
        "hidden": "Hidden",
        "removed": "Removed",
        "restricted": "Restricted",
        "edit_requested": "Edit requested",
    }
    label = status_labels.get(status, status.replace("_", " ").title())
    message = f'Your product "{product_name}" is now {label}.'
    if reason:
        message += f" Note: {reason[:200]}"

    return create_notification(
        user_id=user_id,
        role="seller",
        title="Product moderation update",
        message=message,
        page="/seller/products",
        category="seller_management",
        ntype="in_app",
        data={"productName": product_name, "status": status},
    )


def notify_admin_refund_disputed(*, admin_user_id: int, order_id: int) -> Notification:
    """Notify an admin that a buyer disputed a seller-rejected refund."""

    return create_notification(
        user_id=admin_user_id,
        role="admin",
        title="Refund dispute escalated",
        message=f"A buyer disputed a refund rejection for order #{order_id}.",
        page="/admin/refunds",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


def notify_buyer_refund_seller_rejected(*, user_id: int, order_id: int) -> Notification:
    """Notify buyer that seller rejected refund; they may dispute."""

    return create_notification(
        user_id=user_id,
        role="buyer",
        title="Refund rejected by seller",
        message=(
            f"Your refund request for order #{order_id} was rejected by the seller. "
            "You may dispute this decision if you disagree."
        ),
        page="/buyer/refunds",
        category="orders",
        ntype="in_app",
        data={"orderId": order_id},
    )


# Rider helpers -------------------------------------------------------------


def notify_rider_new_delivery_assignment(*, user_id: int, order_id: int) -> Notification:
    """Notify a rider about a new delivery assignment."""

    return create_notification(
        user_id=user_id,
        role="rider",
        title="New delivery assigned",
        message=f"You have been assigned a new delivery for order #{order_id}.",
        page="/rider/dashboard",
        category="logistics",
        ntype="in_app",
        data={"orderId": order_id},
    )
