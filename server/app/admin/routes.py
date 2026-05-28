import json

from . import (
    admin as admin_bp,
    db,
    StoreRegistration,
    StoreRequestStatus,
    User,
    Seller,
    Store,
    Category,
    Product,
    ProductCategory,
)
from flask import (
    jsonify,
    abort,
    url_for,
    request,
    current_app,
)
from flask_jwt_extended import (
    jwt_required,
    current_user,
    get_jwt,
)
from app.decorators import (
    admin_required
)
from app.models import (
    Notification,
    PaymentTransaction,
    PaymentStatus,
    RefundRequest,
    RefundStatus,
    Order,
    OrderStatus,
    SellerWallet,
    DeliveryStatus,
    Coupon,
    ProblemReport,
    ReportStatus,
    Store,
    User,
    UserRole,
    Role,
    RiderDelivery,
    RiderLocation,
)
from app.coupon_helpers import serialize_coupon
from app.utils.static_urls import public_static_url
from app.order.routes import _serialize_order, ADMIN_COMMISSION_RATE, RIDER_FIXED_EARNING, RIDER_FEE_ADMIN_SHARE_PERCENT, RIDER_FEE_SELLER_SHARE_PERCENT
from app.admin.privacy import (
    serialize_user_for_admin,
    serialize_users_for_admin,
    serialize_order_for_admin,
    serialize_refund_for_admin,
)
from app.models import ProductModerationStatus, ProductModerationLog
from app.services.product_moderation_service import ProductModerationService
from app.services.refund_service import RefundService, compute_order_financials_for_refund, ADMIN_QUEUE_STATUSES
from app.notifications.service import (
    notify_seller_store_registration_approved,
    notify_seller_store_registration_rejected,
    notify_buyer_account_approved,
    notify_buyer_account_rejected,
    notify_rider_account_approved,
    notify_rider_account_rejected,
    notify_buyer_refund_approved,
    notify_buyer_refund_declined,
    notify_seller_product_approval,
)
from flask_jwt_extended import (
    jwt_required,
)
from sqlalchemy import inspect as sa_inspect, select, func
from sqlalchemy.orm import load_only, noload, selectinload
from datetime import datetime, timedelta


def _products_table_columns() -> set[str]:
    return {c["name"] for c in sa_inspect(db.engine).get_columns("products")}


def _admin_product_list_options(existing: set[str]):
    """Load only columns present in DB so admin list works before migrations catch up."""
    field_names = (
        "id",
        "name",
        "price",
        "store_id",
        "is_live",
        "moderation_status",
        "moderation_reason",
        "edit_requested_at",
        "edit_request_note",
    )
    attrs = [getattr(Product, name) for name in field_names if name in existing]
    opts = []
    if attrs:
        opts.append(load_only(*attrs))
    if "store_id" in existing:
        opts.append(
            selectinload(Product.store).load_only(Store.id, Store.store_name)
        )
    return opts


def _compute_order_financials_for_refund(order: Order) -> dict:
    """Backward-compatible alias for refund financial calculations."""
    return compute_order_financials_for_refund(order)


def _serialize_admin_refund(r: RefundRequest) -> dict:
    tx = r.payment_transaction
    order = r.order
    buyer = r.buyer or (order.buyer if order else None)
    seller = r.seller
    amount = float(tx.amount or 0.0) if tx is not None else 0.0

    evidence_paths = []
    if r.evidence_paths_json:
        try:
            evidence_paths = json.loads(r.evidence_paths_json)
        except Exception:
            pass

    payload = {
        "id": r.id,
        "transactionId": tx.id if tx is not None else None,
        "orderId": order.id if order is not None else None,
        "amount": amount,
        "status": r.status.value if isinstance(r.status, RefundStatus) else str(r.status),
        "reason": r.reason,
        "createdAt": r.created_at.isoformat() if r.created_at else None,
        "updatedAt": r.updated_at.isoformat() if r.updated_at else None,
        "buyerEvidenceNote": r.buyer_evidence_note,
        "sellerResponseNote": r.seller_response_note,
        "adminNote": r.admin_note,
        "evidencePaths": evidence_paths,
        "disputedAt": r.disputed_at.isoformat() if r.disputed_at else None,
        "evidenceRequestedAt": r.evidence_requested_at.isoformat() if r.evidence_requested_at else None,
        "isTransactionFrozen": bool(r.is_transaction_frozen),
        "frozenAt": r.frozen_at.isoformat() if r.frozen_at else None,
        "buyer": {
            "id": buyer.id if buyer is not None else None,
            "email": buyer.email if buyer is not None else None,
            "givenName": buyer.given_name if buyer is not None else None,
            "surname": buyer.surname if buyer is not None else None,
        },
        "seller": {
            "id": seller.id if seller is not None else None,
            "userId": seller.user_id if seller is not None else None,
        },
        "order": {
            "id": order.id if order is not None else None,
            "status": order.status.value if order and hasattr(order.status, "value") else None,
            "totalAmount": float(order.total_amount or 0) if order else None,
            "storeId": order.store_id if order else None,
        },
    }
    return serialize_refund_for_admin(payload)


def _serialize_store_registration_for_admin(registration: StoreRegistration) -> dict:
    """Serialize pending store registration without loading seller_profiles columns."""
    from app.utils.upload import public_url_for_stored_path

    def doc_url(path: str | None) -> str | None:
        if not path:
            return None
        url = public_url_for_stored_path(path, allow_private=True)
        return url or None

    user = registration.user
    status = registration.request_status.name if registration.request_status else "PENDING"
    seller_name = ""
    if user is not None:
        seller_name = f"{user.given_name or ''} {user.surname or ''}".strip()
    return {
        "id": registration.id,
        "user_id": registration.user_id,
        "seller_id": registration.seller_id,
        "Store name": registration.shop_name or "",
        "Store purpose": registration.store_purpose or "",
        "Store tagline": registration.tagline or "",
        "Categories json": registration.categories_json or "",
        "DTI path": registration.dti_path,
        "DTI url": doc_url(registration.dti_path),
        "BIR TIN path": registration.bir_tin_path,
        "BIR TIN url": doc_url(registration.bir_tin_path),
        "Business permit path": registration.business_permit_path,
        "Business permit url": doc_url(registration.business_permit_path),
        "Request status": status,
        "Request date created": (
            registration.created_at.isoformat() if registration.created_at else None
        ),
        "Seller full name": seller_name,
        "Seller email": user.email if user else "",
        "Seller street address": "",
        "Seller barangay": "",
        "Seller municipality": "",
        "Seller province": "",
        "Seller region": "",
    }


@admin_bp.get('/files/signed-url')
@jwt_required()
@admin_required()
def admin_signed_storage_url():
    """Return a short-lived signed URL for a stored file path.

    Accepts a stored relative path like ``seller_dti/a1b2c3_1712345678.pdf``
    and resolves it to the appropriate bucket automatically.
    """
    from flask import current_app
    from app.utils.upload import public_url_for_stored_path

    path = (request.args.get('path') or '').strip()
    if not path:
        return jsonify(msg='path is required'), 400

    url = public_url_for_stored_path(path, allow_private=True)
    if not url:
        return jsonify(msg='Could not resolve file URL'), 404
    return jsonify(url=url), 200


@admin_bp.get('/get-users')
@admin_bp.get('/users')
@jwt_required()
@admin_required()
def getUsers():
    from flask import current_app

    role_filter = (request.args.get('role') or '').strip().lower()
    try:
        stmt = select(User).options(
            selectinload(User.roles).selectinload(UserRole.role),
            selectinload(User.buyer_profile),
            noload(User.seller),
            selectinload(User.rider_profile),
        ).order_by(User.id.desc())
        if role_filter:
            stmt = (
                stmt.join(User.roles)
                .join(UserRole.role)
                .where(func.lower(Role.name) == role_filter)
                .distinct()
            )
        users = db.session.execute(stmt).scalars().unique().all()
        usersJSON = serialize_users_for_admin(users)
        return jsonify(users=usersJSON), 200
    except Exception as exc:
        current_app.logger.exception("[admin/get-users] failed: %s", exc)
        db.session.rollback()
        return (
            jsonify(
                msg="Error loading users. Run flask db upgrade on Railway, then redeploy.",
                detail=str(exc)[:300],
            ),
            500,
        )


@admin_bp.get('/users/<int:user_id>/orders')
@jwt_required()
@admin_required()
def get_user_orders(user_id: int):
    """List all orders for a specific buyer (user_id) for admin.

    This mirrors the buyer-scoped /orders endpoint but allows admins to
    inspect a buyer's order history from the admin UI.
    """

    try:
        rows = db.session.execute(
            select(Order)
            .where(Order.buyer_id == user_id)
            .order_by(Order.created_at.desc())
        ).scalars().all()

        return jsonify(orders=[_serialize_order(o) for o in rows]), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/users/<int:user_id>/activity-logs')
@jwt_required()
@admin_required()
def get_user_activity_logs(user_id: int):
    """Return recent notifications for a user as activity log entries."""

    try:
        user = db.session.get(User, user_id)
        if user is None:
            return jsonify(msg='User not found'), 404

        notifications = db.session.execute(
            select(Notification)
            .where(Notification.user_id == user_id)
            .order_by(Notification.created_at.desc())
            .limit(50)
        ).scalars().all()

        logs = [
            {
                'id': n.id,
                'type': 'notification',
                'title': n.title,
                'description': n.body,
                'role': n.role,
                'page': n.page,
                'read': n.read,
                'createdAt': n.created_at.isoformat() if n.created_at else None,
            }
            for n in notifications
        ]

        return jsonify(logs=logs), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/users/<int:user_id>/products')
@jwt_required()
@admin_required()
def get_user_seller_products(user_id: int):
    """List products for stores owned by the given seller user."""

    try:
        store = db.session.execute(
            select(Store).where(Store.user_id == user_id)
        ).scalar_one_or_none()

        if store is None:
            return jsonify(products=[]), 200

        existing = _products_table_columns()
        products = db.session.execute(
            select(Product)
            .where(Product.store_id == store.id)
            .options(*_admin_product_list_options(existing))
            .order_by(Product.id.desc())
        ).scalars().all()

        result = []
        for p in products:
            if "moderation_status" in existing:
                mod_status = (
                    p.moderation_status.value
                    if hasattr(p.moderation_status, 'value')
                    else str(p.moderation_status or 'active')
                )
            else:
                mod_status = 'active'
            result.append(
                {
                    'id': p.id,
                    'name': getattr(p, 'name', None),
                    'price': float(getattr(p, 'price', 0) or 0),
                    'isLive': bool(p.is_live) if "is_live" in existing else True,
                    'moderationStatus': mod_status,
                    'status': mod_status.replace('_', ' ').title(),
                    'storeId': store.id,
                    'storeName': store.store_name,
                }
            )

        return jsonify(products=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/users/<int:user_id>/deliveries')
@jwt_required()
@admin_required()
def get_user_rider_deliveries(user_id: int):
    """List rider deliveries assigned to the given user."""

    try:
        deliveries = db.session.execute(
            select(RiderDelivery)
            .where(RiderDelivery.rider_id == user_id)
            .options(selectinload(RiderDelivery.order))
            .order_by(RiderDelivery.created_at.desc())
        ).scalars().all()

        result = []
        for d in deliveries:
            status = d.status.value if hasattr(d.status, 'value') else str(d.status)
            order = d.order
            result.append(
                {
                    'id': d.id,
                    'orderId': d.order_id,
                    'status': status,
                    'fee': float(d.fee or 0),
                    'distanceKm': float(d.distance_km) if d.distance_km is not None else None,
                    'createdAt': d.created_at.isoformat() if d.created_at else None,
                    'orderStatus': order.status.value if order and hasattr(order.status, 'value') else (
                        str(order.status) if order else None
                    ),
                    'orderTotal': float(order.total_amount or 0) if order else None,
                }
            )

        return jsonify(deliveries=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/orders')
@jwt_required()
@admin_required()
def list_all_orders():
    """List all orders across buyers for admin.

    Returns a lightweight list with basic buyer info suitable for the
    admin orders UI. This is separate from the buyer-scoped /orders
    endpoint under the orders blueprint.
    """

    try:
        rows = db.session.execute(
            select(Order)
            .options(selectinload(Order.buyer), selectinload(Order.deliveries))
            .order_by(Order.created_at.desc())
        ).scalars().all()

        result: list[dict] = []
        for o in rows:
            status = o.status
            if isinstance(status, OrderStatus):
                status_value = status.value
            else:
                status_value = str(status) if status is not None else None

            buyer = o.buyer

            rider_fee = 0.0
            deliveries = getattr(o, "deliveries", None) or []
            if deliveries:
                deliveries_sorted = sorted(
                    deliveries,
                    key=lambda d: getattr(d, "created_at", None) or datetime.datetime.min,
                    reverse=True,
                )
                d = deliveries_sorted[0]
                status_value = d.status.value if hasattr(d.status, "value") else str(d.status)
                if status_value in {
                    DeliveryStatus.PICKUP.value,
                    DeliveryStatus.TRANSIT.value,
                    DeliveryStatus.DELIVERED.value,
                }:
                    rider_fee = RIDER_FIXED_EARNING

            result.append(
                {
                    "id": o.id,
                    "status": status_value,
                    "total": float(o.total_amount or 0.0),
                    "paymentMethod": o.payment_method,
                    "createdAt": o.created_at.isoformat() if getattr(o, "created_at", None) else None,
                    "buyer": {
                        "id": buyer.id if buyer is not None else None,
                        "email": buyer.email if buyer is not None else None,
                    },
                }
            )

        return jsonify(orders=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/orders/<int:order_id>')
@jwt_required()
@admin_required()
def get_order_detail(order_id: int):
    """Return full order detail for admin, independent of buyer scope."""

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg='Order not found'), 404

        return jsonify(order=serialize_order_for_admin(_serialize_order(order))), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/orders/<int:order_id>/financials')
@jwt_required()
@admin_required()
def get_order_financials_admin(order_id: int):
    """Return the financial breakdown for a single order for admin.

    This mirrors the buyer-scoped /orders/<id>/financials endpoint but
    is not restricted by buyer_id, so admins can inspect commission,
    rider fee sharing, seller payout, and phase (before/after pickup)
    for any order.
    """

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg='Order not found'), 404

        financials = _compute_order_financials_for_refund(order)

        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order.id)
        ).scalar_one_or_none()

        tx_payload = None
        if payment_tx is not None:
            tx_payload = {
                'id': payment_tx.id,
                'amount': float(payment_tx.amount or 0.0),
                'platformFee': float(payment_tx.platform_fee or 0.0),
                'status': payment_tx.status.value if hasattr(payment_tx.status, 'value') else str(payment_tx.status),
            }

        return jsonify(orderId=order.id, financials=financials, paymentTransaction=tx_payload), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/orders/<int:order_id>/refund/approve')
@jwt_required()
@admin_required()
def approve_refund(order_id: int):
    """Approve a refund request for an order.

    This marks the payment transaction as REFUNDED and notifies the buyer.
    """

    try:
        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order_id)
        ).scalar_one_or_none()

        if payment_tx is None:
            return jsonify(msg='Payment transaction not found for this order'), 404

        # If already refunded, avoid double-processing
        if payment_tx.status == PaymentStatus.REFUNDED:
            return jsonify(msg='Refund already processed for this order'), 400

        order = payment_tx.order
        if order is None or order.buyer_id is None:
            return jsonify(msg='Order or buyer not found for this transaction'), 404

        payment_tx.status = PaymentStatus.REFUNDED

        notify_buyer_refund_approved(
            user_id=order.buyer_id,
            order_id=order.id,
        )

        db.session.commit()

        return jsonify(msg='Refund approved', order_id=order.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/orders/<int:order_id>/refund/decline')
@jwt_required()
@admin_required()
def decline_refund(order_id: int):
    """Decline a refund request for an order and notify the buyer."""

    try:
        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order_id)
        ).scalar_one_or_none()

        if payment_tx is None:
            return jsonify(msg='Payment transaction not found for this order'), 404

        order = payment_tx.order
        if order is None or order.buyer_id is None:
            return jsonify(msg='Order or buyer not found for this transaction'), 404

        notify_buyer_refund_declined(
            user_id=order.buyer_id,
            order_id=order.id,
        )

        db.session.commit()

        return jsonify(msg='Refund declined', order_id=order.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/orders/refunds')
@jwt_required()
@admin_required()
def list_refunds_queue():
    """List refunded orders for admin review.

    This shows PaymentTransaction records with status REFUNDED, joined to
    their orders and buyers, so admins have a simple refund history/queue.
    """

    try:
        rows = db.session.execute(
            select(PaymentTransaction)
            .join(PaymentTransaction.order)
            .order_by(PaymentTransaction.created_at.desc())
        ).scalars().all()

        result: list[dict] = []
        for tx in rows:
            if tx.status != PaymentStatus.REFUNDED:
                continue

            order = tx.order
            buyer = order.buyer if order is not None else None

            result.append(
                {
                    "transactionId": tx.id,
                    "orderId": order.id if order else None,
                    "amount": float(tx.amount or 0.0),
                    "status": tx.status.value if hasattr(tx.status, 'value') else str(tx.status),
                    "createdAt": tx.created_at.isoformat() if getattr(tx, 'created_at', None) else None,
                    "buyer": {
                        "id": buyer.id if buyer else None,
                        "email": buyer.email if buyer else None,
                    },
                }
            )

        return jsonify(refunds=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/categories')
@jwt_required()
@admin_required()
def list_categories():
    """Return all categories with product counts for admin management UI."""

    rows = db.session.execute(
        select(
            Category.id,
            Category.name,
            func.count(ProductCategory.product_id).label('product_count'),
        )
        .outerjoin(ProductCategory, ProductCategory.category_id == Category.id)
        .group_by(Category.id, Category.name)
        .order_by(Category.name)
    ).all()

    categories = [
        {"id": row.id, "name": row.name, "productCount": int(row.product_count or 0)}
        for row in rows
    ]

    return jsonify(categories=categories), 200


@admin_bp.get('/stores/<int:store_id>')
@jwt_required()
@admin_required()
def get_store_detail(store_id):
    """Return store + seller basic info for admin inspection."""

    store = db.session.execute(
        select(Store)
        .options(selectinload(Store.seller).selectinload(Seller.registration), selectinload(Store.user))
        .where(Store.id == store_id)
    ).scalar_one_or_none()

    if store is None:
        return jsonify(msg='Store not found'), 404

    seller = store.seller
    user = store.user
    registration = seller.registration if seller is not None else None

    # Parse registered categories (stored as JSON array of category IDs or comma-separated string)
    categories: list[str] = []
    if registration and registration.categories_json:
        raw = registration.categories_json
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                categories = [str(c) for c in parsed]
            elif isinstance(parsed, str) and parsed:
                categories = [part.strip() for part in parsed.split(",") if part.strip()]
        except Exception:
            # Fallback: treat raw value as comma-separated IDs
            categories = [part.strip() for part in str(raw).split(",") if part.strip()]

    data = {
        "id": store.id,
        "name": store.store_name,
        "email": store.store_email,
        "description": store.description,
        "country": store.country,
        "address": store.address,
        "phone": store.store_phone_number,
        "user": {
            "id": user.id if user else None,
            "email": user.email if user else None,
            "givenName": user.given_name if user else None,
            "surname": user.surname if user else None,
        },
        "seller": {
            "id": seller.id if seller else None,
            "fullName": seller.full_name if seller else None,
            "country": seller.country if seller else None,
            "province": seller.province if seller else None,
            "city": seller.city if seller else None,
        },
        "registration": {
            "id": registration.id if registration else None,
            "purpose": registration.store_purpose if registration else None,
            "tagline": registration.tagline if registration else None,
            "categories": categories,
            "requestedAt": registration.created_at.isoformat() if getattr(registration, "created_at", None) else None,
            "documents": {
                "dti": registration.dti_path if registration else None,
                "birTin": registration.bir_tin_path if registration else None,
                "businessPermit": registration.business_permit_path if registration else None,
            } if registration else None,
        },
    }

    return jsonify(store=data), 200


@admin_bp.get('/stores')
@jwt_required()
@admin_required()
def list_stores():
    """Return all stores for admin, with basic info per store."""

    stores = db.session.execute(
        select(Store).options(selectinload(Store.seller))
    ).scalars().all()

    result = []
    for s in stores:
        seller = s.seller
        result.append(
            {
                "id": s.id,
                "name": s.store_name,
                "email": s.store_email,
                "address": s.address,
                "sellerName": seller.full_name if seller else None,
            }
        )

    return jsonify(stores=result), 200


@admin_bp.post('/buyers/<int:user_id>/approve')
@jwt_required()
@admin_required()
def approve_buyer(user_id):
    """Mark a buyer's account as verified (email_verified = True)."""

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg='User not found'), 404

    try:
        user.setVerification(True)

        # Notify buyer about approval
        notify_buyer_account_approved(user_id=user.id)

        db.session.commit()
        return jsonify(msg='Buyer approved', user=user.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/users/<int:user_id>/archive')
@jwt_required()
@admin_required()
def archive_user(user_id: int):
    """Soft-archive an inactive user (account data kept; restored on next login)."""

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg='User not found'), 404

    if user.is_archived:
        return jsonify(msg='User is already archived', user=user.to_json()), 200

    try:
        user.archive_account()
        db.session.commit()
        return jsonify(msg='User archived', user=user.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/buyers/<int:user_id>/reject')
@jwt_required()
@admin_required()
def reject_buyer(user_id):
    """Reject a buyer account (for now just deactivate the user)."""

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg='User not found'), 404

    try:
        user.setActive(False)

        notify_buyer_account_rejected(user_id=user.id)

        db.session.commit()
        return jsonify(msg='Buyer rejected', user=user.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/riders/<int:user_id>/approve')
@jwt_required()
@admin_required()
def approve_rider(user_id):
    """Mark a rider's account as verified (email_verified = True).

    This is analogous to buyer approval and controls access to rider
    dashboards and delivery endpoints.
    """

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg='User not found'), 404

    try:
        user.setVerification(True)
        user.setActive(True)

        notify_rider_account_approved(user_id=user.id)

        db.session.commit()
        return jsonify(msg='Rider approved', user=user.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/riders/<int:user_id>/reject')
@jwt_required()
@admin_required()
def reject_rider(user_id):
    """Reject a rider account (deactivate the user for now)."""

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg='User not found'), 404

    try:
        user.setActive(False)

        notify_rider_account_rejected(user_id=user.id)

        db.session.commit()
        return jsonify(msg='Rider rejected', user=user.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/riders/<int:user_id>')
@jwt_required()
@admin_required()
def get_rider_detail(user_id):
    """Return detailed rider info for admin, including profile and documents.

    This surfaces the same data the rider provided at registration plus
    resolved URLs for uploaded documents where possible.
    """

    user = db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg='User not found'), 404

    rider_profile = getattr(user, 'rider_profile', None)
    if rider_profile is None:
        return jsonify(msg='Rider profile not found'), 404

    from app.utils.upload import public_url_for_stored_path

    def build_doc_url(path: str | None) -> str | None:
        if not path:
            return None
        url = public_url_for_stored_path(path, allow_private=True)
        return url or None

    data = {
        "user": user.to_json(),
        "profile": {
            "vehicleType": rider_profile.vehicle_type,
            "licenseNumber": rider_profile.license_number,
            "address": {
                "regionCode": rider_profile.region_code,
                "regionName": rider_profile.region_name,
                "provinceCode": rider_profile.province_code,
                "provinceName": rider_profile.province_name,
                "municipalityCode": rider_profile.municipality_code,
                "municipalityName": rider_profile.municipality_name,
                "barangayCode": rider_profile.barangay_code,
                "barangayName": rider_profile.barangay_name,
                "streetAddress": rider_profile.street_address,
                "postalCode": rider_profile.postal_code,
            },
            "documents": {
                "licensePath": rider_profile.license_path,
                "licenseUrl": build_doc_url(rider_profile.license_path),
                "orcrPath": rider_profile.orcr_path,
                "orcrUrl": build_doc_url(rider_profile.orcr_path),
            },
        },
    }

    return jsonify(rider=data), 200

@admin_bp.get('/get-store-registrations')
@jwt_required()
@admin_required()
def getStoreRegistrations():
    from flask import current_app

    try:
        pending = StoreRequestStatus.PENDING
        storeRegistrations = db.session.execute(
            select(StoreRegistration)
            .where(StoreRegistration.request_status == pending)
            .options(
                selectinload(StoreRegistration.user),
                noload(StoreRegistration.seller),
            )
            .order_by(StoreRegistration.id.desc())
        ).scalars().all()
        storeRegistrationsJSON = []
        for registration in storeRegistrations:
            try:
                storeRegistrationsJSON.append(
                    _serialize_store_registration_for_admin(registration)
                )
            except Exception:
                continue
        return jsonify(StoreRegistrations=storeRegistrationsJSON), 200
    except Exception as exc:
        current_app.logger.exception("[admin/get-store-registrations] failed: %s", exc)
        db.session.rollback()
        return (
            jsonify(
                msg="Error loading store registrations. Run flask db upgrade on Railway.",
                detail=str(exc)[:300],
            ),
            500,
        )
    
@admin_bp.post('/accept-store-registration/<int:registration_id>')
@jwt_required()
@admin_required()
def acceptStoreRegistrationRequest(registration_id):
    from flask import current_app
    
    current_app.logger.info(f"[accept-store-registration] Processing registration_id={registration_id}")
    
    storeRegistration = db.session.execute(
        select(StoreRegistration).where(StoreRegistration.id == registration_id)
    ).scalar_one_or_none()

    if storeRegistration is None:
        current_app.logger.error(f"[accept-store-registration] Registration {registration_id} not found")
        return jsonify(msg='Store registration not found'), 404

    try:
        current_app.logger.info(f"[accept-store-registration] Found registration: user_id={storeRegistration.user_id}, seller_id={storeRegistration.seller_id}")
        current_app.logger.info(f"[accept-store-registration] shop_name={storeRegistration.shop_name}, store_purpose={storeRegistration.store_purpose}")
        
        if storeRegistration.request_status.name == StoreRequestStatus.REJECTED.name:
            return jsonify(msg='Request already rejected!')
        if storeRegistration.request_status.name == StoreRequestStatus.ACCEPTED.name:
            return jsonify(msg='Request already accepted!')

        # Mark registration as accepted
        storeRegistration.acceptStoreRegistration()

        # Auto-create Store if one doesn't already exist for this user
        existing_store = db.session.execute(
            select(Store).where(Store.user_id == storeRegistration.user_id)
        ).scalar_one_or_none()

        store_obj = existing_store

        if existing_store is None:
            current_app.logger.info(f"[accept-store-registration] No existing store, creating new one")
            
            # Check if seller_id exists
            if storeRegistration.seller_id is None:
                current_app.logger.error(f"[accept-store-registration] seller_id is None for registration {registration_id}")
                db.session.rollback()
                return jsonify(msg='Registration has no associated seller'), 400
            
            seller = db.session.execute(
                select(Seller).where(Seller.id == storeRegistration.seller_id)
            ).scalar_one_or_none()

            if seller is None:
                current_app.logger.error(f"[accept-store-registration] Seller {storeRegistration.seller_id} not found")
                db.session.rollback()
                return jsonify(msg='Associated seller profile not found'), 400

            store_name = storeRegistration.shop_name or storeRegistration.store_purpose
            if not store_name:
                store_name = f"Store #{registration_id}"
                current_app.logger.warning(f"[accept-store-registration] No shop_name or store_purpose, using default: {store_name}")
            
            # Get user email safely
            user_email = None
            if storeRegistration.user is not None:
                user_email = storeRegistration.user.email
            else:
                # Try to fetch user directly
                user = db.session.execute(select(User).where(User.id == storeRegistration.user_id)).scalar_one_or_none()
                if user is not None:
                    user_email = user.email
                else:
                    current_app.logger.error(f"[accept-store-registration] User {storeRegistration.user_id} not found")
                    db.session.rollback()
                    return jsonify(msg='Associated user not found'), 400
            
            store_email = user_email
            description = storeRegistration.store_purpose or store_name

            address_parts = [
                seller.street_address,
                seller.barangay_name,
                seller.municipality_name,
                seller.province_name,
                seller.country,
            ]
            address = ", ".join([p for p in address_parts if p])

            current_app.logger.info(f"[accept-store-registration] Creating store: name={store_name}, email={store_email}")
            
            store = Store(
                store_name=store_name,
                store_email=store_email,
                description=description,
                country=seller.country,
                address=address,
                store_phone_number=seller.personal_phone_number,
                user_id=storeRegistration.user_id,
                seller_id=storeRegistration.seller_id,
            )
            db.session.add(store)
            store_obj = store

        db.session.commit()
        current_app.logger.info(f"[accept-store-registration] Store registration accepted successfully")

        response = {"msg": 'Store registration accepted and store created/confirmed!'}
        if store_obj is not None:
            response["store"] = {
                "id": store_obj.id,
                "name": store_obj.store_name,
                "email": store_obj.store_email,
                "address": store_obj.address,
                "sellerId": store_obj.seller_id,
                "sellerName": store_obj.seller.full_name if store_obj.seller else None,
            }

        # Notify seller about store approval
        user = storeRegistration.user
        if user is not None:
            notify_seller_store_registration_approved(user_id=user.id)

        return jsonify(response), 200
    except Exception as e:
        current_app.logger.exception(f"[accept-store-registration] Error: {e}")
        db.session.rollback()
        return jsonify(msg=f'Error occurred: {str(e)}'), 500
    
@admin_bp.post('/reject-store-registration/<int:registration_id>')
@jwt_required()
@admin_required()
def rejectStoreRegistrationRequest(registration_id):
    storeRegistration = db.session.execute(select(StoreRegistration).where(StoreRegistration.id==registration_id)).scalar_one_or_none()

    try:
        if storeRegistration.request_status.name==StoreRequestStatus.REJECTED.name:
            return jsonify(msg='Request already rejected!')
        elif storeRegistration.request_status.name==StoreRequestStatus.ACCEPTED.name:
            return jsonify(msg='Request already accepted!')

        storeRegistration.rejectStoreRegistration()
        db.session.commit()

        # Notify seller about rejection
        user = storeRegistration.user
        if user is not None:
            notify_seller_store_registration_rejected(user_id=user.id)

        return jsonify(msg='Store registration rejected!'), 200
    except:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/products')
@jwt_required()
@admin_required()
def list_products():
    """Return all products for admin with search, moderation status, store, and category filters."""

    search = (request.args.get('search') or '').strip()
    status = (request.args.get('status') or '').strip().lower()
    store_id = request.args.get('storeId', type=int)
    category_id = request.args.get('categoryId', type=int)

    try:
        existing = _products_table_columns()
        query = select(Product).options(*_admin_product_list_options(existing))

        if search:
            query = query.where(Product.name.ilike(f"%{search}%"))

        status_map = {
            'active': ProductModerationStatus.ACTIVE,
            'under_review': ProductModerationStatus.UNDER_REVIEW,
            'hidden': ProductModerationStatus.HIDDEN,
            'removed': ProductModerationStatus.REMOVED,
            'restricted': ProductModerationStatus.RESTRICTED,
        }
        if status in status_map and "moderation_status" in existing:
            query = query.where(Product.moderation_status == status_map[status])
        elif status == 'hidden_legacy' and "is_live" in existing:
            query = query.where(Product.is_live.is_(False))

        if store_id is not None and "store_id" in existing:
            query = query.where(Product.store_id == store_id)

        if category_id is not None:
            query = query.join(
                ProductCategory,
                ProductCategory.product_id == Product.id,
            ).where(ProductCategory.category_id == category_id)

        products = db.session.execute(query.order_by(Product.id.desc())).scalars().all()

        result = []
        for p in products:
            if "moderation_status" in existing:
                mod_status = (
                    p.moderation_status.value
                    if hasattr(p.moderation_status, 'value')
                    else str(p.moderation_status or 'active')
                )
            else:
                mod_status = 'active'
            edit_at = None
            if "edit_requested_at" in existing and p.edit_requested_at:
                edit_at = p.edit_requested_at.isoformat()
            result.append(
                {
                    "id": p.id,
                    "name": getattr(p, 'name', None),
                    "price": float(getattr(p, 'price', 0) or 0),
                    "isLive": bool(p.is_live) if "is_live" in existing else True,
                    "moderationStatus": mod_status,
                    "moderationReason": p.moderation_reason if "moderation_reason" in existing else None,
                    "status": mod_status.replace('_', ' ').title(),
                    "storeId": getattr(p, 'store_id', None),
                    "storeName": p.store.store_name if getattr(p, 'store', None) else None,
                    "editRequestedAt": edit_at,
                    "editRequestNote": p.edit_request_note if "edit_request_note" in existing else None,
                }
            )

        return jsonify(products=result), 200
    except Exception as exc:
        current_app.logger.exception("[admin/products] failed: %s", exc)
        db.session.rollback()
        return (
            jsonify(
                msg="Error loading products. Run flask db upgrade on Railway.",
                detail=str(exc)[:300],
            ),
            500,
        )


@admin_bp.get('/products/moderation-queue')
@jwt_required()
@admin_required()
def product_moderation_queue():
    """Products flagged for admin review."""

    try:
        products = db.session.execute(
            select(Product)
            .where(Product.moderation_status == ProductModerationStatus.UNDER_REVIEW)
            .options(selectinload(Product.store))
            .order_by(Product.moderation_updated_at.desc())
        ).scalars().all()

        result = []
        for p in products:
            result.append(
                {
                    "id": p.id,
                    "name": p.name,
                    "moderationStatus": ProductModerationStatus.UNDER_REVIEW.value,
                    "moderationReason": p.moderation_reason,
                    "storeId": p.store_id,
                    "storeName": p.store.store_name if p.store else None,
                    "editRequestedAt": p.edit_requested_at.isoformat() if p.edit_requested_at else None,
                    "editRequestNote": p.edit_request_note,
                }
            )
        return jsonify(products=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.patch('/products/<int:product_id>/moderation')
@jwt_required()
@admin_required()
def update_product_moderation(product_id: int):
    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    status_raw = (data.get('status') or '').strip().lower()
    reason = data.get('reason')
    edit_note = data.get('editRequestNote')

    status_map = {
        'active': ProductModerationStatus.ACTIVE,
        'under_review': ProductModerationStatus.UNDER_REVIEW,
        'hidden': ProductModerationStatus.HIDDEN,
        'removed': ProductModerationStatus.REMOVED,
        'restricted': ProductModerationStatus.RESTRICTED,
    }
    if status_raw not in status_map:
        return jsonify(msg='Invalid moderation status'), 400

    try:
        product = db.session.execute(
            select(Product).where(Product.id == product_id)
        ).scalar_one_or_none()
        if product is None:
            return jsonify(msg='Product not found'), 404

        ProductModerationService.set_status(
            product,
            status_map[status_raw],
            admin_id=current_user.id,
            reason=reason,
        )
        if edit_note:
            ProductModerationService.request_edits(product, edit_note, admin_id=current_user.id)

        db.session.commit()
        return jsonify(
            msg='Product moderation updated',
            productId=product.id,
            moderationStatus=status_raw,
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/products/<int:product_id>/request-edits')
@jwt_required()
@admin_required()
def request_product_edits(product_id: int):
    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    note = (data.get('note') or data.get('editRequestNote') or '').strip()
    if not note:
        return jsonify(msg='Edit request note is required'), 400

    try:
        product = db.session.execute(
            select(Product).where(Product.id == product_id)
        ).scalar_one_or_none()
        if product is None:
            return jsonify(msg='Product not found'), 404

        ProductModerationService.request_edits(product, note, admin_id=current_user.id)
        db.session.commit()
        return jsonify(msg='Edit request sent to seller', productId=product.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/products/<int:product_id>/moderation-logs')
@jwt_required()
@admin_required()
def get_product_moderation_logs(product_id: int):
    try:
        logs = db.session.execute(
            select(ProductModerationLog)
            .where(ProductModerationLog.product_id == product_id)
            .order_by(ProductModerationLog.created_at.desc())
        ).scalars().all()

        return jsonify(
            logs=[
                {
                    "id": log.id,
                    "action": log.action,
                    "note": log.note,
                    "adminId": log.admin_id,
                    "createdAt": log.created_at.isoformat() if log.created_at else None,
                }
                for log in logs
            ]
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/refund-requests')
@jwt_required()
@admin_required()
def list_refund_requests():
    """List refund requests for admin — defaults to dispute queue."""

    queue = (request.args.get('queue') or 'disputes').strip().lower()
    show_all = request.args.get('all', '').lower() in {'1', 'true', 'yes'}

    try:
        stmt = (
            select(RefundRequest)
            .options(
                selectinload(RefundRequest.payment_transaction),
                selectinload(RefundRequest.order).selectinload(Order.buyer),
                selectinload(RefundRequest.buyer),
                selectinload(RefundRequest.seller),
            )
            .order_by(RefundRequest.created_at.desc())
        )

        if not show_all and queue == 'disputes':
            stmt = stmt.where(RefundRequest.status.in_(ADMIN_QUEUE_STATUSES))

        refunds = db.session.execute(stmt).scalars().all()
        result = [_serialize_admin_refund(r) for r in refunds]

        return jsonify(refunds=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/refund-requests/<int:refund_id>/approve')
@jwt_required()
@admin_required()
def approve_refund_request(refund_id: int):
    """Approve a disputed refund and perform settlement."""

    try:
        refund, err = RefundService.process_refund(refund_id, actor='admin')
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Refund approved', refundId=refund.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/refund-requests/<int:refund_id>/reject')
@jwt_required()
@admin_required()
def reject_refund_request(refund_id: int):
    """Reject a disputed refund without changing settlement."""

    data = request.get_json(silent=True) or {}
    note = data.get('note') or data.get('reason')

    try:
        refund, err = RefundService.reject_refund(refund_id, actor='admin', note=note)
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Refund rejected', refundId=refund.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/refund-requests/<int:refund_id>/request-evidence')
@jwt_required()
@admin_required()
def request_refund_evidence(refund_id: int):
    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    note = (data.get('note') or data.get('adminNote') or '').strip()
    if not note:
        return jsonify(msg='Admin note is required'), 400

    try:
        refund, err = RefundService.request_evidence(refund_id, note)
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Evidence requested', refundId=refund.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/refund-requests/<int:refund_id>/freeze')
@jwt_required()
@admin_required()
def freeze_refund_transaction(refund_id: int):
    try:
        refund, err = RefundService.freeze_transaction(refund_id)
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Transaction frozen', refundId=refund.id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/products/<int:product_id>/approve')
@jwt_required()
@admin_required()
def approve_product(product_id: int):
    try:
        product = db.session.execute(select(Product).where(Product.id == product_id)).scalar_one_or_none()
        if product is None:
            return jsonify(msg='Product not found'), 404

        if product.moderation_status == ProductModerationStatus.ACTIVE and product.is_live:
            return jsonify(msg='Product is already active', product_id=product.id, already_approved=True), 200

        ProductModerationService.set_status(
            product,
            ProductModerationStatus.ACTIVE,
            admin_id=current_user.id,
            reason='Restored to active by admin',
        )
        db.session.commit()
        return jsonify(msg='Product restored to active', product_id=product.id, already_approved=False), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.post('/products/<int:product_id>/reject')
@jwt_required()
@admin_required()
def reject_product(product_id: int):
    try:
        product = db.session.execute(select(Product).where(Product.id == product_id)).scalar_one_or_none()
        if product is None:
            return jsonify(msg='Product not found'), 404

        if product.moderation_status == ProductModerationStatus.HIDDEN:
            return jsonify(msg='Product is already hidden', product_id=product.id, already_rejected=True), 200

        ProductModerationService.set_status(
            product,
            ProductModerationStatus.HIDDEN,
            admin_id=current_user.id,
            reason='Hidden by admin',
        )
        db.session.commit()
        return jsonify(msg='Product hidden successfully', product_id=product.id, already_rejected=False), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@admin_bp.get('/analytics')
@jwt_required()
@admin_required()
def get_admin_analytics():
    """Get platform-wide analytics for admin dashboard."""
    try:
        days = request.args.get('days', 30, type=int)
        since = datetime.utcnow() - timedelta(days=days)

        # Summary stats
        total_revenue = db.session.execute(
            select(func.sum(Order.total_amount)).where(
                Order.created_at >= since,
                Order.status.in_([OrderStatus.COMPLETED, OrderStatus.DELIVERED])
            )
        ).scalar() or 0

        total_orders = db.session.execute(
            select(func.count(Order.id)).where(
                Order.created_at >= since
            )
        ).scalar() or 0

        total_users = db.session.execute(
            select(func.count(User.id)).where(
                User.created_at >= since
            )
        ).scalar() or 0

        total_sellers = db.session.execute(
            select(func.count(Seller.id)).where(
                Seller.created_at >= since
            )
        ).scalar() or 0

        # Previous period for growth calculation
        prev_since = since - timedelta(days=days)
        prev_revenue = db.session.execute(
            select(func.sum(Order.total_amount)).where(
                Order.created_at >= prev_since,
                Order.created_at < since,
                Order.status.in_([OrderStatus.COMPLETED, OrderStatus.DELIVERED])
            )
        ).scalar() or 0

        prev_orders = db.session.execute(
            select(func.count(Order.id)).where(
                Order.created_at >= prev_since,
                Order.created_at < since
            )
        ).scalar() or 0

        # Calculate growth
        revenue_growth = 0
        if prev_revenue > 0:
            revenue_growth = ((total_revenue - prev_revenue) / prev_revenue) * 100

        orders_growth = 0
        if prev_orders > 0:
            orders_growth = ((total_orders - prev_orders) / prev_orders) * 100

        # Generate sales chart data (daily for last N days)
        sales_chart = []
        for i in range(days):
            day_start = since + timedelta(days=i)
            day_end = day_start + timedelta(days=1)
            
            day_revenue = db.session.execute(
                select(func.sum(Order.total_amount)).where(
                    Order.created_at >= day_start,
                    Order.created_at < day_end,
                    Order.status.in_([OrderStatus.COMPLETED, OrderStatus.DELIVERED])
                )
            ).scalar() or 0
            
            day_orders = db.session.execute(
                select(func.count(Order.id)).where(
                    Order.created_at >= day_start,
                    Order.created_at < day_end
                )
            ).scalar() or 0
            
            sales_chart.append({
                "name": day_start.strftime("%m/%d"),
                "revenue": float(day_revenue),
                "orders": day_orders
            })

        # Generate user growth data (weekly aggregation for longer periods)
        user_growth = []
        if days <= 30:
            # Daily
            for i in range(days):
                day_start = since + timedelta(days=i)
                day_end = day_start + timedelta(days=1)
                
                day_users = db.session.execute(
                    select(func.count(User.id)).where(
                        User.created_at >= day_start,
                        User.created_at < day_end
                    )
                ).scalar() or 0
                
                day_sellers = db.session.execute(
                    select(func.count(Seller.id)).where(
                        Seller.created_at >= day_start,
                        Seller.created_at < day_end
                    )
                ).scalar() or 0
                
                user_growth.append({
                    "name": day_start.strftime("%m/%d"),
                    "users": day_users,
                    "sellers": day_sellers
                })
        else:
            # Weekly
            weeks = days // 7
            for i in range(weeks):
                week_start = since + timedelta(weeks=i)
                week_end = week_start + timedelta(weeks=1)
                
                week_users = db.session.execute(
                    select(func.count(User.id)).where(
                        User.created_at >= week_start,
                        User.created_at < week_end
                    )
                ).scalar() or 0
                
                week_sellers = db.session.execute(
                    select(func.count(Seller.id)).where(
                        Seller.created_at >= week_start,
                        Seller.created_at < week_end
                    )
                ).scalar() or 0
                
                user_growth.append({
                    "name": f"Week {i+1}",
                    "users": week_users,
                    "sellers": week_sellers
                })

        return jsonify({
            "period": f"last_{days}_days",
            "summary": {
                "totalRevenue": float(total_revenue),
                "totalOrders": total_orders,
                "totalUsers": total_users,
                "totalSellers": total_sellers,
                "revenueGrowth": round(revenue_growth, 1),
                "ordersGrowth": round(orders_growth, 1)
            },
            "salesChart": sales_chart,
            "userGrowth": user_growth
        }), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify(msg='Error fetching analytics'), 500


@admin_bp.get('/analytics/download')
@jwt_required()
@admin_required()
def download_analytics_report():
    """Download analytics report as PDF."""
    try:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import letter, A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import inch
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
        from reportlab.lib.enums import TA_CENTER, TA_LEFT
        import io
        import matplotlib.pyplot as plt
        import matplotlib
        matplotlib.use('Agg')

        days = request.args.get('days', 30, type=int)
        format_type = request.args.get('format', 'pdf')
        
        # Get analytics data
        since = datetime.utcnow() - timedelta(days=days)
        
        # Summary stats
        total_revenue = db.session.execute(
            select(func.sum(Order.total_amount)).where(
                Order.created_at >= since,
                Order.status.in_([OrderStatus.COMPLETED, OrderStatus.DELIVERED])
            )
        ).scalar() or 0

        total_orders = db.session.execute(
            select(func.count(Order.id)).where(
                Order.created_at >= since
            )
        ).scalar() or 0

        total_users = db.session.execute(
            select(func.count(User.id)).where(
                User.created_at >= since
            )
        ).scalar() or 0

        total_sellers = db.session.execute(
            select(func.count(Seller.id)).where(
                Seller.created_at >= since
            )
        ).scalar() or 0

        # Create PDF
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=18)
        elements = []
        styles = getSampleStyleSheet()

        # Title
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#1B365D'),
            spaceAfter=30,
            alignment=TA_CENTER
        )
        elements.append(Paragraph("Yamada E-Commerce Analytics Report", title_style))
        elements.append(Spacer(1, 20))

        # Period
        period_style = ParagraphStyle(
            'PeriodStyle',
            parent=styles['Normal'],
            fontSize=12,
            textColor=colors.HexColor('#666666'),
            alignment=TA_CENTER
        )
        elements.append(Paragraph(f"Period: Last {days} Days ({since.strftime('%Y-%m-%d')} to {datetime.utcnow().strftime('%Y-%m-%d')})", period_style))
        elements.append(Spacer(1, 30))

        # Summary Section Title
        elements.append(Paragraph("Summary Statistics", styles['Heading2']))
        elements.append(Spacer(1, 12))

        # Summary Table
        summary_data = [
            ['Metric', 'Value'],
            ['Total Revenue', f"PHP {total_revenue:,.2f}"],
            ['Total Orders', f"{total_orders:,}"],
            ['Total Users', f"{total_users:,}"],
            ['Total Sellers', f"{total_sellers:,}"],
        ]

        summary_table = Table(summary_data, colWidths=[3*inch, 3*inch])
        summary_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1B365D')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#F5F5F5')),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 10),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#E8E8E8')]),
        ]))
        elements.append(summary_table)
        elements.append(Spacer(1, 30))

        # Generate sales chart
        sales_chart = []
        chart_days = min(days, 30)  # Limit chart to 30 days for readability
        for i in range(chart_days):
            day_start = since + timedelta(days=i)
            day_end = day_start + timedelta(days=1)
            
            day_revenue = db.session.execute(
                select(func.sum(Order.total_amount)).where(
                    Order.created_at >= day_start,
                    Order.created_at < day_end,
                    Order.status.in_([OrderStatus.COMPLETED, OrderStatus.DELIVERED])
                )
            ).scalar() or 0
            
            day_orders = db.session.execute(
                select(func.count(Order.id)).where(
                    Order.created_at >= day_start,
                    Order.created_at < day_end
                )
            ).scalar() or 0
            
            sales_chart.append({
                "date": day_start.strftime("%m/%d"),
                "revenue": float(day_revenue),
                "orders": day_orders
            })

        # Sales Chart Section
        elements.append(Paragraph("Daily Sales Data", styles['Heading2']))
        elements.append(Spacer(1, 12))

        # Sales Data Table
        sales_data = [['Date', 'Revenue (PHP)', 'Orders']]
        for day in sales_chart:
            sales_data.append([
                day['date'],
                f"PHP {day['revenue']:,.2f}",
                str(day['orders'])
            ])

        # Limit rows for PDF (first 15 and last 15 if too many)
        if len(sales_data) > 32:
            sales_data = sales_data[:16] + [['...', '...', '...']] + sales_data[-16:]

        sales_table = Table(sales_data, colWidths=[1.5*inch, 2.5*inch, 2*inch])
        sales_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F5A3B5')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.black),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 11),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('GRID', (0, 0), (-1, -1), 1, colors.black),
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 9),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#FFF5F7')]),
        ]))
        elements.append(sales_table)
        elements.append(Spacer(1, 30))

        # Footer
        footer_style = ParagraphStyle(
            'Footer',
            parent=styles['Normal'],
            fontSize=8,
            textColor=colors.grey,
            alignment=TA_CENTER
        )
        elements.append(Spacer(1, 20))
        elements.append(Paragraph(f"Generated on {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC", footer_style))
        elements.append(Paragraph("© 2026 Yamada E-Commerce Platform", footer_style))

        # Build PDF
        doc.build(elements)
        buffer.seek(0)
        
        return buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename=analytics-report-{days}d.pdf'
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify(msg='Error generating report'), 500


def _coupon_from_body(data: dict, *, default_scope: str = 'platform', store_id=None) -> Coupon:
    return Coupon(
        code=(data.get('code') or '').strip().upper(),
        title=(data.get('title') or '').strip(),
        description=data.get('description'),
        discount_type=data.get('discountType') or data.get('discount_type') or 'percent',
        discount_value=float(data.get('discountValue') or data.get('discount_value') or 0),
        min_order_amount=float(data.get('minOrderAmount') or data.get('min_order_amount') or 0),
        max_uses=data.get('maxUses') or data.get('max_uses'),
        expires_at=datetime.fromisoformat(data['expiresAt'].replace('Z', '+00:00'))
        if data.get('expiresAt')
        else None,
        is_active=data.get('isActive', data.get('is_active', True)),
        scope=data.get('scope') or default_scope,
        store_id=store_id if store_id is not None else data.get('storeId') or data.get('store_id'),
    )


def _serialize_problem_report(r: ProblemReport, *, include_evidence: bool = False) -> dict:
    evidence_list = []
    evidence_count = 0
    try:
        evidence_count = len(r.evidence)
        if include_evidence:
            for e in r.evidence:
                evidence_list.append({
                    'id': e.id,
                    'filePath': e.file_path,
                    'fileUrl': public_static_url(e.file_path),
                    'fileType': e.file_type,
                    'originalFilename': e.original_filename,
                })
    except Exception:
        pass
    report_type_name = None
    try:
        if r.report_type is not None:
            report_type_name = r.report_type.display_name
    except Exception:
        pass
    return {
        'id': r.id,
        'reporterUserId': r.reporter_user_id,
        'reporterRole': r.reporter_role,
        'reportTypeId': r.report_type_id,
        'reportType': report_type_name,
        'description': r.description,
        'status': r.status.value if hasattr(r.status, 'value') else str(r.status),
        'priority': r.priority or 'medium',
        'targetUserId': r.target_user_id,
        'targetRole': r.target_role,
        'storeId': r.store_id,
        'orderId': r.order_id,
        'adminNotes': r.admin_notes,
        'evidence': evidence_list,
        'evidenceCount': evidence_count,
        'createdAt': r.created_at.isoformat() if r.created_at else None,
        'updatedAt': r.updated_at.isoformat() if r.updated_at else None,
        'resolvedAt': r.resolved_at.isoformat() if r.resolved_at else None,
    }


@admin_bp.get('/coupons')
@jwt_required()
@admin_required()
def admin_list_coupons():
    scope = request.args.get('scope')
    store_id = request.args.get('storeId', type=int)
    stmt = select(Coupon).order_by(Coupon.created_at.desc())
    if scope:
        stmt = stmt.where(Coupon.scope == scope)
    if store_id:
        stmt = stmt.where(Coupon.store_id == store_id)
    coupons = db.session.execute(stmt).scalars().all()
    return jsonify(coupons=[serialize_coupon(c) for c in coupons]), 200


@admin_bp.post('/coupons')
@jwt_required()
@admin_required()
def admin_create_coupon():
    data = request.get_json() or {}
    if not data.get('code') or not data.get('title'):
        return jsonify(msg='code and title are required'), 400
    coupon = _coupon_from_body(data)
    try:
        db.session.add(coupon)
        db.session.commit()
        return jsonify(coupon=serialize_coupon(coupon)), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg='Failed to create coupon'), 500


@admin_bp.put('/coupons/<int:coupon_id>')
@jwt_required()
@admin_required()
def admin_update_coupon(coupon_id: int):
    coupon = db.session.get(Coupon, coupon_id)
    if coupon is None:
        return jsonify(msg='Coupon not found'), 404
    data = request.get_json() or {}
    for field, key in [
        ('title', 'title'),
        ('description', 'description'),
        ('discount_type', 'discountType'),
        ('discount_value', 'discountValue'),
        ('min_order_amount', 'minOrderAmount'),
        ('max_uses', 'maxUses'),
        ('is_active', 'isActive'),
        ('scope', 'scope'),
    ]:
        if data.get(key) is not None or data.get(field) is not None:
            setattr(coupon, field, data.get(key) or data.get(field))
    if data.get('code'):
        coupon.code = str(data['code']).strip().upper()
    if data.get('expiresAt'):
        coupon.expires_at = datetime.fromisoformat(data['expiresAt'].replace('Z', '+00:00'))
    if data.get('storeId') is not None:
        coupon.store_id = data.get('storeId')
    db.session.commit()
    return jsonify(coupon=serialize_coupon(coupon)), 200


@admin_bp.delete('/coupons/<int:coupon_id>')
@jwt_required()
@admin_required()
def admin_delete_coupon(coupon_id: int):
    coupon = db.session.get(Coupon, coupon_id)
    if coupon is None:
        return jsonify(msg='Coupon not found'), 404
    db.session.delete(coupon)
    db.session.commit()
    return jsonify(msg='Coupon deleted'), 200


@admin_bp.get('/problem-reports')
@jwt_required()
@admin_required()
def admin_list_problem_reports():
    status = request.args.get('status')
    reporter_role = request.args.get('reporterRole')
    target_role = request.args.get('targetRole')
    stmt = (
        select(ProblemReport)
        .options(
            selectinload(ProblemReport.report_type),
            selectinload(ProblemReport.evidence),
        )
        .order_by(ProblemReport.created_at.desc())
    )
    if status:
        stmt = stmt.where(ProblemReport.status == ReportStatus(status))
    if reporter_role:
        stmt = stmt.where(ProblemReport.reporter_role == reporter_role)
    if target_role:
        stmt = stmt.where(ProblemReport.target_role == target_role)
    reports = db.session.execute(stmt).scalars().all()
    return jsonify(reports=[_serialize_problem_report(r) for r in reports]), 200


@admin_bp.patch('/problem-reports/<int:report_id>')
@jwt_required()
@admin_required()
def admin_update_problem_report(report_id: int):
    report = db.session.execute(
        select(ProblemReport)
        .where(ProblemReport.id == report_id)
        .options(
            selectinload(ProblemReport.report_type),
            selectinload(ProblemReport.evidence),
        )
    ).scalar_one_or_none()
    if report is None:
        return jsonify(msg='Report not found'), 404
    data = request.get_json() or {}
    new_status = data.get('status')
    if new_status:
        report.status = ReportStatus(new_status)
        if new_status in ('resolved', 'dismissed'):
            report.resolved_at = datetime.now()
            sub = get_jwt().get('sub')
            report.resolved_by = int(sub) if sub is not None else None
    if 'adminNotes' in data:
        report.admin_notes = data['adminNotes']
    db.session.commit()
    return jsonify(report=_serialize_problem_report(report, include_evidence=True)), 200


@admin_bp.get("/deliveries/active")
@jwt_required()
@admin_required()
def admin_active_deliveries():
    """Return all active deliveries with rider location for the admin map."""
    try:
        active_statuses = [
            DeliveryStatus.PENDING,
            DeliveryStatus.PICKUP,
            DeliveryStatus.TRANSIT,
        ]
        deliveries = db.session.execute(
            select(RiderDelivery)
            .options(
                selectinload(RiderDelivery.rider),
                selectinload(RiderDelivery.order).selectinload(Order.buyer),
            )
            .where(RiderDelivery.status.in_(active_statuses))
            .order_by(RiderDelivery.updated_at.desc().nullslast())
        ).scalars().all()

        result = []
        for d in deliveries:
            rider = d.rider
            order = d.order

            rider_name = None
            if rider:
                given = getattr(rider, "given_name", None) or ""
                surname = getattr(rider, "surname", None) or ""
                rider_name = f"{given} {surname}".strip() or getattr(rider, "email", None)

            buyer_name = None
            buyer_lat = None
            buyer_lng = None
            if order:
                buyer = order.buyer
                if buyer:
                    given = getattr(buyer, "given_name", None) or ""
                    surname = getattr(buyer, "surname", None) or ""
                    buyer_name = f"{given} {surname}".strip() or getattr(buyer, "email", None)

            # Latest rider location
            latest_loc = db.session.execute(
                select(RiderLocation)
                .where(RiderLocation.order_id == d.order_id)
                .order_by(RiderLocation.timestamp.desc())
                .limit(1)
            ).scalar_one_or_none()

            rider_lat = float(latest_loc.latitude) if latest_loc else None
            rider_lng = float(latest_loc.longitude) if latest_loc else None

            # Destination lat/lng from shipping address or buyer profile
            dest_lat = None
            dest_lng = None
            if order and order.shipping_address:
                try:
                    addr = json.loads(order.shipping_address)
                    if isinstance(addr, dict):
                        dest_lat = addr.get("latitude") or addr.get("lat")
                        dest_lng = addr.get("longitude") or addr.get("lng")
                except (json.JSONDecodeError, TypeError):
                    pass

            status_value = d.status.value if isinstance(d.status, DeliveryStatus) else str(d.status)

            result.append({
                "deliveryId": d.id,
                "orderId": d.order_id,
                "status": status_value,
                "distanceKm": float(d.distance_km or 0),
                "fee": float(d.fee or 0),
                "createdAt": d.created_at.isoformat() if d.created_at else None,
                "updatedAt": d.updated_at.isoformat() if d.updated_at else None,
                "rider": {
                    "id": rider.id if rider else None,
                    "name": rider_name,
                } if rider else None,
                "buyer": {
                    "id": order.buyer_id if order else None,
                    "name": buyer_name,
                } if order else None,
                "riderLocation": {
                    "latitude": rider_lat,
                    "longitude": rider_lng,
                } if rider_lat and rider_lng else None,
                "destination": {
                    "latitude": dest_lat,
                    "longitude": dest_lng,
                } if dest_lat and dest_lng else None,
            })

        return jsonify(deliveries=result), 200

    except Exception as e:
        current_app.logger.error(f"Failed to fetch active deliveries: {e}")
        return jsonify(deliveries=[], error="Internal error"), 500