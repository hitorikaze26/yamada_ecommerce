from . import (
    seller as seller_bp,
    db,
    User,
    UserRole,
    Role,
    RoleTypes,
    Product,
    Seller,
    StoreRegistration,
    Store,
    RiderDelivery,
    RiderProfile,
)
from app.models import (
    SellerWallet,
    PaymentTransaction,
    PaymentStatus,
    OrderStatus,
    Order,
    OrderItem,
    RefundRequest,
    RefundStatus,
    ShippingSettings,
    PaymentSettings,
    OrderSettings,
    ShopCustomization,
    ChatSettings,
    Category,
    ProductCategory,
    Coupon,
)
from app.coupon_helpers import serialize_coupon
from app.services.product_moderation_service import ProductModerationService
from app.services.refund_service import RefundService
from flask import (
    jsonify,
    abort,
    request,
    current_app,
)
from app.decorators import (
    seller_required
)
from app.utils.shipping_address import format_shipping_address
from flask_jwt_extended import (
    jwt_required,
    current_user
)
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload
import datetime
import traceback
from app.utils.static_urls import public_static_url as _public_image_url

# Paid / fulfilled orders included in revenue, charts, and PDF reports.
# Excludes pending (unpaid), cancelled, and returned.
_ANALYTICS_REVENUE_STATUSES = (
    OrderStatus.CONFIRMED,
    OrderStatus.PROCESSING,
    OrderStatus.SHIPPED,
    OrderStatus.OUT_FOR_DELIVERY,
    OrderStatus.DELIVERED,
    OrderStatus.COMPLETED,
)


@seller_bp.post('/create-profile')
@jwt_required()
def createSellerProfile():
    if not request.is_json:
        abort(400)

    try:
        data = request.get_json()
        
        seller=Seller(
            full_name=data['full_name'],
            residential_address=data['residential_address'],
            personal_phone_number=data['personal_phone_number'],
            country=data['country'],
            province=data['province'],
            city=data['city'],
            user_id=current_user.id
        )

        user=db.session.execute(select(User).where(User.id==current_user.id)).scalar_one_or_none()
        role=db.session.execute(select(Role).where(Role.id==RoleTypes.SELLER.value)).scalar_one_or_none()
        user.roles.append(UserRole(user=user, role=role))

        db.session.add(seller)
        db.session.add(user)
        db.session.commit()

        return jsonify(msg='Successfully created seller profile!'), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg='Seller profile already exists!'), 400
    except:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500

@seller_bp.get('/profile')
@jwt_required()
@seller_required()
def getSellerProfile():
    seller=db.session.execute(select(Seller).where(Seller.user_id==current_user.id)).scalar_one_or_none()

    if seller is None:
        seller_profile=None
    else:
        seller_profile = {
            'id': seller.id,
            'full_name': seller.full_name,
            'email': seller.user.email,
            'residential_address': seller.residential_address,
            'personal_phone_number': seller.personal_phone_number,
            'country': seller.country,
            'province': seller.province,
            'city': seller.city,
        }

    try:
        return jsonify(seller_profile=seller_profile), 200
    except:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500

@seller_bp.get('/<int:seller_id>/products')
@jwt_required()
@seller_required()
def get_seller_products(seller_id: int):
    """Return products for the store owned by the given seller_id.

    The URL seller_id must match the logged-in seller to avoid leaking data
    across sellers. Products are serialized into plain dicts so they are
    JSON-safe for the frontend.
    """

    try:
        seller = db.session.execute(select(Seller).where(Seller.id == seller_id)).scalar_one_or_none()
        if seller is None or seller.user_id != current_user.id:
            return jsonify(msg='Unauthorized request!'), 403

        store = db.session.execute(select(Store).where(Store.seller_id == seller.id)).scalar_one_or_none()
        if store is None:
            return jsonify(products=[]), 200

        products = db.session.execute(
            select(Product)
            .where(Product.store_id == store.id)
            .options(selectinload(Product.variations))
        ).scalars().all()

        serialized = []
        for p in products:
            item = {
                "id": p.id,
                "slug": getattr(p, "slug", None),
                "name": p.name,
                "subcategory": getattr(p, "subcategory", None),
                "price": p.price,
                "quantity": getattr(p, "quantity", None),
                "description": p.description,
                "image_url": _public_image_url(getattr(p, "image_url", None)),
                # Use is_live flag as visibility if present; default to True
                "visibility": getattr(p, "is_live", True),
                **ProductModerationService.serialize_moderation_brief(p),
                "variations": [
                    {
                        "id": v.id,
                        "size": v.size,
                        "color": v.color,
                        "colorHex": getattr(v, 'color_hex', None),
                        "sku": v.sku,
                        "inventory": getattr(v, "inventory", 0),
                        "price": getattr(v, "price", None),
                    }
                    for v in getattr(p, "variations", [])
                ],
            }
            serialized.append(item)

        return jsonify(products=serialized), 200
    except Exception:
        traceback.print_exc()
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.get('/products')
@jwt_required()
@seller_required()
def get_my_products():
    """Get products for the currently authenticated seller (no seller_id needed)."""
    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()
        if seller is None:
            return jsonify(msg='Seller profile not found'), 404

        store = db.session.execute(
            select(Store).where(Store.seller_id == seller.id)
        ).scalar_one_or_none()
        if store is None:
            return jsonify(products=[]), 200

        products = db.session.execute(
            select(Product)
            .where(Product.store_id == store.id)
            .options(selectinload(Product.variations))
        ).scalars().all()

        # Bulk compute sold counts — replaces N+1 per-product queries
        product_ids = [p.id for p in products]
        sold_rows = db.session.execute(
            select(
                OrderItem.product_id,
                db.func.coalesce(db.func.sum(OrderItem.quantity), 0)
            )
            .join(Order, Order.id == OrderItem.order_id)
            .where(
                OrderItem.product_id.in_(product_ids),
                Order.status.in_([OrderStatus.DELIVERED, OrderStatus.COMPLETED])
            )
            .group_by(OrderItem.product_id)
        ).all()
        sold_map = {row[0]: int(row[1]) for row in sold_rows}

        serialized = []
        for p in products:
            item = {
                "id": p.id,
                "slug": getattr(p, "slug", None),
                "name": p.name,
                "subcategory": getattr(p, "subcategory", None),
                "price": p.price,
                "quantity": getattr(p, "quantity", None),
                "description": p.description,
                "image_url": _public_image_url(getattr(p, "image_url", None)),
                "visibility": getattr(p, "is_live", True),
                "sold": sold_map.get(p.id, 0),
                **ProductModerationService.serialize_moderation_brief(p),
                "variations": [
                    {
                        "id": v.id,
                        "size": v.size,
                        "color": v.color,
                        "colorHex": getattr(v, 'color_hex', None),
                        "sku": v.sku,
                        "inventory": getattr(v, "inventory", 0),
                        "price": getattr(v, "price", None),
                    }
                    for v in getattr(p, "variations", [])
                ],
            }
            serialized.append(item)

        return jsonify(products=serialized), 200
    except Exception:
        traceback.print_exc()
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.get('/orders')
@jwt_required()
@seller_required()
def get_seller_orders():
    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()
        if seller is None:
            return jsonify(msg='Seller profile not found'), 404

        store = db.session.execute(
            select(Store).where(Store.seller_id == seller.id)
        ).scalar_one_or_none()
        if store is None:
            return jsonify(orders=[]), 200

        orders = db.session.execute(
            select(Order)
            .where(Order.store_id == store.id)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product),
                selectinload(Order.buyer),
                selectinload(Order.deliveries).selectinload(RiderDelivery.rider),
            )
            .order_by(Order.created_at.desc())
        ).scalars().all()

        result: list[dict] = []
        for o in orders:
            buyer = o.buyer
            if buyer is not None:
                buyer_name_parts = [buyer.given_name or "", buyer.surname or ""]
                buyer_full_name = " ".join(p for p in buyer_name_parts if p).strip()
                buyer_name = buyer_full_name or buyer.username or buyer.email
                buyer_payload = {
                    "id": buyer.id,
                    "name": buyer_name,
                    "email": buyer.email,
                }
            else:
                buyer_payload = None

            items_payload: list[dict] = []
            for item in o.items:
                product = item.product
                product_payload = None
                if product is not None:
                    product_payload = {
                        "id": product.id,
                        "name": product.name,
                        "price": float(product.price or 0.0),
                        "costPrice": float(getattr(product, "cost_price", None) or 0.0),
                        "imageUrl": _public_image_url(getattr(product, "image_url", None)),
                    }

                items_payload.append(
                    {
                        "id": item.id,
                        "productId": item.product_id,
                        "quantity": item.quantity,
                        "unitPrice": float(item.unit_price or 0.0),
                        "discountAmount": float(item.discount_amount or 0.0),
                        "variation": item.variation,
                        "product": product_payload,
                    }
                )

            # Build rider delivery payload from the most recent delivery record
            rider_delivery_payload = None
            if o.deliveries:
                latest = sorted(o.deliveries, key=lambda d: d.id, reverse=True)[0]
                rider = latest.rider
                rider_payload = None
                if rider is not None:
                    rider_name_parts = [rider.given_name or "", rider.surname or ""]
                    rider_full_name = " ".join(p for p in rider_name_parts if p).strip()
                    rider_name = rider_full_name or rider.username or rider.email
                    # Get vehicle info from rider_profile if available
                    vehicle_type = None
                    license_number = None
                    if hasattr(rider, 'rider_profile') and rider.rider_profile:
                        vehicle_type = rider.rider_profile.vehicle_type
                        license_number = rider.rider_profile.license_number
                    rider_payload = {
                        "id": rider.id,
                        "name": rider_name,
                        "email": rider.email,
                        "contactNumber": rider.contact_number or "",
                        "vehicleType": vehicle_type,
                        "licenseNumber": license_number,
                    }
                rider_delivery_payload = {
                    "id": latest.id,
                    "status": latest.status.value if hasattr(latest.status, 'value') else str(latest.status),
                    "fee": float(latest.fee or 0.0),
                    "distanceKm": float(latest.distance_km) if latest.distance_km else None,
                    "proofPhotoUrl": _public_image_url(latest.proof_photo_path),
                    "proofNote": latest.proof_note,
                    "rider": rider_payload,
                }

            result.append(
                {
                    "id": o.id,
                    "status": o.status.value if isinstance(o.status, OrderStatus) else str(o.status),
                    "total": float(o.total_amount or 0.0),
                    "shippingFee": float(o.shipping_fee or 0.0),
                    "adminCommission": float(o.admin_commission or 0.0),
                    "paymentMethod": o.payment_method,
                    "shippingAddress": format_shipping_address(o.shipping_address)
                        or o.shipping_address,
                    "createdAt": o.created_at.isoformat() if o.created_at else None,
                    "updatedAt": o.updated_at.isoformat() if o.updated_at else None,
                    "buyer": buyer_payload,
                    "items": items_payload,
                    "riderDelivery": rider_delivery_payload,
                }
            )

        return jsonify(orders=result), 200
    except Exception:
        traceback.print_exc()
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


def _buyer_display_name(buyer: User | None) -> str | None:
    if buyer is None:
        return None
    parts = [buyer.given_name, buyer.surname]
    name = " ".join(p for p in parts if p).strip()
    return name or buyer.username or buyer.email


def _serialize_seller_refund_request(r: RefundRequest) -> dict:
    tx: PaymentTransaction | None = r.payment_transaction
    order: Order | None = r.order
    buyer: User | None = r.buyer or (order.buyer if order is not None else None)
    amount = float(tx.amount or 0.0) if tx is not None else 0.0
    platform_fee = float(tx.platform_fee or 0.0) if tx is not None else 0.0

    order_items: list[dict] = []
    if order is not None:
        for item in order.items or []:
            product = item.product
            order_items.append(
                {
                    "productName": product.name if product is not None else "Unknown product",
                    "quantity": int(item.quantity or 1),
                    "unitPrice": float(item.unit_price or 0.0),
                    "variation": item.variation,
                }
            )

    order_payload = None
    if order is not None:
        status_val = order.status.value if isinstance(order.status, OrderStatus) else str(order.status)
        order_payload = {
            "id": order.id,
            "displayId": f"ORD-{int(order.id):06d}",
            "status": status_val,
            "totalAmount": float(order.total_amount or 0.0),
            "shippingFee": float(order.shipping_fee or 0.0),
            "grandTotal": float(order.grand_total),
            "paymentMethod": order.payment_method,
            "createdAt": order.created_at.isoformat() if order.created_at else None,
            "items": order_items,
        }

    payment_status = None
    if tx is not None:
        payment_status = tx.status.value if isinstance(tx.status, PaymentStatus) else str(tx.status)

    buyer_payload = None
    if buyer is not None:
        buyer_payload = {
            "id": buyer.id,
            "name": _buyer_display_name(buyer),
            "email": buyer.email,
            "contactNumber": buyer.contact_number,
        }

    return {
        "id": r.id,
        "transactionId": tx.id if tx is not None else None,
        "orderId": order.id if order is not None else None,
        "amount": amount,
        "platformFee": platform_fee,
        "netAmount": amount - platform_fee,
        "status": r.status.value if isinstance(r.status, RefundStatus) else str(r.status),
        "reason": r.reason,
        "createdAt": r.created_at.isoformat() if r.created_at else None,
        "updatedAt": r.updated_at.isoformat() if r.updated_at else None,
        "paymentStatus": payment_status,
        "buyer": buyer_payload,
        "order": order_payload,
    }


@seller_bp.get('/refund-requests')
@jwt_required()
@seller_required()
def get_seller_refund_requests():
    """Return refund requests for the current seller's store(s)."""

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(refunds=[]), 200

        refunds = db.session.execute(
            select(RefundRequest)
            .options(
                selectinload(RefundRequest.payment_transaction),
                selectinload(RefundRequest.order).selectinload(Order.items).selectinload(OrderItem.product),
                selectinload(RefundRequest.buyer),
            )
            .where(RefundRequest.seller_id == seller.id)
            .order_by(RefundRequest.created_at.desc())
        ).scalars().all()

        result = [_serialize_seller_refund_request(r) for r in refunds]

        return jsonify(refunds=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.post('/refund-requests/<int:refund_id>/approve')
@jwt_required()
@seller_required()
def approve_seller_refund(refund_id: int):
    """Allow a seller to mark a refund request as approved from their side."""

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(msg='Seller profile not found'), 404

        refund = db.session.execute(
            select(RefundRequest).where(
                RefundRequest.id == refund_id,
                RefundRequest.seller_id == seller.id,
            )
        ).scalar_one_or_none()

        if refund is None:
            return jsonify(msg='Refund request not found'), 404

        if refund.status in {RefundStatus.APPROVED, RefundStatus.APPROVED_BY_SELLER}:
            return jsonify(msg='Refund already approved'), 400

        refund, err = RefundService.process_refund(refund_id, actor="seller")
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Refund approved and processed'), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.post('/refund-requests/<int:refund_id>/reject')
@jwt_required()
@seller_required()
def reject_seller_refund(refund_id: int):
    """Allow a seller to reject a refund request from their side."""

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(msg='Seller profile not found'), 404

        refund = db.session.execute(
            select(RefundRequest).where(
                RefundRequest.id == refund_id,
                RefundRequest.seller_id == seller.id,
            )
        ).scalar_one_or_none()

        if refund is None:
            return jsonify(msg='Refund request not found'), 404

        if refund.status in {RefundStatus.APPROVED, RefundStatus.REJECTED, RefundStatus.REJECTED_BY_SELLER}:
            return jsonify(msg='Refund already finalized'), 400

        data = request.get_json(silent=True) or {}
        note = data.get("note") or data.get("reason")

        refund, err = RefundService.reject_refund(refund_id, actor="seller", note=note)
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(msg='Refund rejected by seller'), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.get('/wallet/refunds')
@jwt_required()
@seller_required()
def get_seller_refunds():
    """Return refunded payment transactions for the current seller.

    This filters PaymentTransaction records for the logged-in seller to
    those with status REFUNDED so sellers can see their refund history.
    """

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(refunds=[]), 200

        txs = db.session.execute(
            select(PaymentTransaction)
            .where(PaymentTransaction.seller_id == seller.id)
            .order_by(PaymentTransaction.created_at.desc())
        ).scalars().all()

        refunds: list[dict] = []
        for tx in txs:
            if tx.status != PaymentStatus.REFUNDED:
                continue

            order = tx.order
            refunds.append(
                {
                    "transactionId": tx.id,
                    "orderId": order.id if isinstance(order, Order) else None,
                    "amount": float(tx.amount or 0.0),
                    "platformFee": float(tx.platform_fee or 0.0),
                    "netAmount": float((tx.amount or 0.0) - (tx.platform_fee or 0.0)),
                    "status": tx.status.value if isinstance(tx.status, PaymentStatus) else str(tx.status),
                    "createdAt": tx.created_at.isoformat() if tx.created_at else None,
                }
            )

        return jsonify(refunds=refunds), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.get('/wallet')
@jwt_required()
@seller_required()
def get_seller_wallet():
    """Return the current seller's wallet balance and basic info."""

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(msg='Seller profile not found'), 404

        wallet = db.session.execute(
            select(SellerWallet).where(SellerWallet.seller_id == seller.id)
        ).scalar_one_or_none()

        balance = float(wallet.balance) if wallet is not None else 0.0

        return jsonify(
            wallet={
                "sellerId": seller.id,
                "balance": balance,
                "updatedAt": wallet.updated_at.isoformat() if wallet and wallet.updated_at else None,
            }
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


@seller_bp.get('/wallet/transactions')
@jwt_required()
@seller_required()
def get_seller_wallet_transactions():
    """Return payment transactions for the current seller, newest first."""

    try:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()

        if seller is None:
            return jsonify(transactions=[]), 200

        txs = db.session.execute(
            select(PaymentTransaction)
            .where(PaymentTransaction.seller_id == seller.id)
            .order_by(PaymentTransaction.created_at.desc())
        ).scalars().all()

        transactions = []
        for tx in txs:
            # Optionally fetch order number / id
            order = tx.order
            transactions.append(
                {
                    "id": tx.id,
                    "orderId": order.id if isinstance(order, Order) else None,
                    "amount": float(tx.amount or 0.0),
                    "platformFee": float(tx.platform_fee or 0.0),
                    "netAmount": float((tx.amount or 0.0) - (tx.platform_fee or 0.0)),
                    "status": tx.status.value if isinstance(tx.status, PaymentStatus) else str(tx.status),
                    "createdAt": tx.created_at.isoformat() if tx.created_at else None,
                    "updatedAt": tx.updated_at.isoformat() if tx.updated_at else None,
                }
            )

        return jsonify(transactions=transactions), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg='Error occurred!'), 500


# =============================================================================
# SHOP SETTINGS ROUTES
# =============================================================================

def _get_seller_store(user_id: int) -> Store | None:
    """Helper to get the store for the current seller."""
    return db.session.execute(
        select(Store).where(Store.user_id == user_id)
    ).scalar_one_or_none()


# -----------------------------------------------------------------------------
# SHIPPING SETTINGS (Per Location)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/shipping')
@jwt_required()
@seller_required()
def get_shipping_settings():
    """Get all shipping settings for the seller's store."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        settings = db.session.execute(
            select(ShippingSettings).where(ShippingSettings.store_id == store.id)
        ).scalars().all()

        return jsonify(shippingSettings=[s.to_json() for s in settings]), 200
    except Exception as e:
        current_app.logger.exception(f"[get_shipping_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.post('/settings/shipping')
@jwt_required()
@seller_required()
def create_shipping_setting():
    """Add a new shipping location with fee."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        region_name = data.get('regionName', '').strip()
        province_name = data.get('provinceName', '').strip()
        city_name = data.get('cityName', '').strip()
        shipping_fee = float(data.get('shippingFee', 0))

        if not region_name or not province_name or not city_name:
            return jsonify(msg='regionName, provinceName, and cityName are required'), 400

        setting = ShippingSettings(
            region_code=data.get('regionCode'),
            region_name=region_name,
            province_code=data.get('provinceCode'),
            province_name=province_name,
            city_code=data.get('cityCode'),
            city_name=city_name,
            shipping_fee=shipping_fee,
            is_active=data.get('isActive', True),
            store_id=store.id,
        )
        db.session.add(setting)
        db.session.commit()

        return jsonify(shippingSetting=setting.to_json(), msg='Shipping location added'), 201
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[create_shipping_setting] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.put('/settings/shipping/<int:setting_id>')
@jwt_required()
@seller_required()
def update_shipping_setting(setting_id: int):
    """Update a shipping location fee or status."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ShippingSettings).where(
                ShippingSettings.id == setting_id,
                ShippingSettings.store_id == store.id
            )
        ).scalar_one_or_none()

        if not setting:
            return jsonify(msg='Shipping setting not found'), 404

        if 'regionName' in data:
            setting.region_name = data['regionName'].strip()
        if 'provinceName' in data:
            setting.province_name = data['provinceName'].strip()
        if 'cityName' in data:
            setting.city_name = data['cityName'].strip()
        if 'shippingFee' in data:
            setting.shipping_fee = float(data['shippingFee'])
        if 'isActive' in data:
            setting.is_active = bool(data['isActive'])

        db.session.commit()
        return jsonify(shippingSetting=setting.to_json(), msg='Shipping location updated'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[update_shipping_setting] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.delete('/settings/shipping/<int:setting_id>')
@jwt_required()
@seller_required()
def delete_shipping_setting(setting_id: int):
    """Delete a shipping location."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ShippingSettings).where(
                ShippingSettings.id == setting_id,
                ShippingSettings.store_id == store.id
            )
        ).scalar_one_or_none()

        if not setting:
            return jsonify(msg='Shipping setting not found'), 404

        db.session.delete(setting)
        db.session.commit()
        return jsonify(msg='Shipping location deleted'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[delete_shipping_setting] Error: {e}")
        return jsonify(msg='Error occurred'), 500


# -----------------------------------------------------------------------------
# PAYMENT SETTINGS (COD Toggle)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/payment')
@jwt_required()
@seller_required()
def get_payment_settings():
    """Get payment settings (COD toggle)."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(PaymentSettings).where(PaymentSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            # Create default
            setting = PaymentSettings(cod_enabled=True, store_id=store.id)
            db.session.add(setting)
            db.session.commit()

        return jsonify(paymentSettings=setting.to_json()), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[get_payment_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.put('/settings/payment')
@jwt_required()
@seller_required()
def update_payment_settings():
    """Update payment settings (enable/disable COD)."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(PaymentSettings).where(PaymentSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            setting = PaymentSettings(store_id=store.id)
            db.session.add(setting)

        if 'codEnabled' in data:
            setting.cod_enabled = bool(data['codEnabled'])

        db.session.commit()
        return jsonify(paymentSettings=setting.to_json(), msg='Payment settings updated'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[update_payment_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


# -----------------------------------------------------------------------------
# ORDER SETTINGS (Cancellation & Returns)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/order')
@jwt_required()
@seller_required()
def get_order_settings():
    """Get order settings (cancellation & returns)."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(OrderSettings).where(OrderSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            # Create default
            setting = OrderSettings(
                allow_cancellation=True,
                max_cancellation_hours=24,
                allow_returns=True,
                return_period_days=7,
                store_id=store.id,
            )
            db.session.add(setting)
            db.session.commit()

        return jsonify(orderSettings=setting.to_json()), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[get_order_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.put('/settings/order')
@jwt_required()
@seller_required()
def update_order_settings():
    """Update order settings (cancellation & returns)."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(OrderSettings).where(OrderSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            setting = OrderSettings(store_id=store.id)
            db.session.add(setting)

        if 'allowCancellation' in data:
            setting.allow_cancellation = bool(data['allowCancellation'])
        if 'maxCancellationHours' in data:
            setting.max_cancellation_hours = int(data['maxCancellationHours'])
        if 'allowReturns' in data:
            setting.allow_returns = bool(data['allowReturns'])
        if 'returnPeriodDays' in data:
            setting.return_period_days = int(data['returnPeriodDays'])

        db.session.commit()
        return jsonify(orderSettings=setting.to_json(), msg='Order settings updated'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[update_order_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


# -----------------------------------------------------------------------------
# SHOP CUSTOMIZATION (Colors, Theme, Announcement)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/customization')
@jwt_required()
@seller_required()
def get_shop_customization():
    """Get shop customization settings."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ShopCustomization).where(ShopCustomization.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            # Create default
            setting = ShopCustomization(
                announcement='',
                primary_color='#3b82f6',
                theme_mode='light',
                store_id=store.id,
            )
            db.session.add(setting)
            db.session.commit()

        return jsonify(customization=setting.to_json()), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[get_shop_customization] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.put('/settings/customization')
@jwt_required()
@seller_required()
def update_shop_customization():
    """Update shop customization (colors, theme, announcement)."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ShopCustomization).where(ShopCustomization.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            setting = ShopCustomization(store_id=store.id)
            db.session.add(setting)

        if 'announcement' in data:
            setting.announcement = data['announcement'].strip() if data['announcement'] else None
        if 'primaryColor' in data:
            setting.primary_color = data['primaryColor'].strip() or '#3b82f6'
        if 'themeMode' in data:
            setting.theme_mode = data['themeMode'].strip() or 'light'

        db.session.commit()
        return jsonify(customization=setting.to_json(), msg='Customization updated'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[update_shop_customization] Error: {e}")
        return jsonify(msg='Error occurred'), 500


# -----------------------------------------------------------------------------
# CHAT SETTINGS (Auto-Reply)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/chat')
@jwt_required()
@seller_required()
def get_chat_settings():
    """Get chat auto-reply settings."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ChatSettings).where(ChatSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            # Create default
            setting = ChatSettings(
                auto_reply_enabled=False,
                auto_reply_message='Thank you for your message! We will get back to you shortly.',
                store_id=store.id,
            )
            db.session.add(setting)
            db.session.commit()

        return jsonify(chatSettings=setting.to_json()), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[get_chat_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.put('/settings/chat')
@jwt_required()
@seller_required()
def update_chat_settings():
    """Update chat auto-reply settings."""
    if not request.is_json:
        return jsonify(msg='JSON required'), 400

    data = request.get_json()

    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        setting = db.session.execute(
            select(ChatSettings).where(ChatSettings.store_id == store.id)
        ).scalar_one_or_none()

        if not setting:
            setting = ChatSettings(store_id=store.id)
            db.session.add(setting)

        if 'autoReplyEnabled' in data:
            setting.auto_reply_enabled = bool(data['autoReplyEnabled'])
        if 'autoReplyMessage' in data:
            setting.auto_reply_message = data['autoReplyMessage'].strip() if data['autoReplyMessage'] else 'Thank you for your message!'

        db.session.commit()
        return jsonify(chatSettings=setting.to_json(), msg='Chat settings updated'), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[update_chat_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


# -----------------------------------------------------------------------------
# GET ALL SETTINGS (Combined)
# -----------------------------------------------------------------------------

@seller_bp.get('/settings/all')
@jwt_required()
@seller_required()
def get_all_shop_settings():
    """Get all shop settings in one request."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(settings={
                'shipping': [],
                'payment': {'codEnabled': True},
                'order': {
                    'allowCancellation': True,
                    'maxCancellationHours': 24,
                    'allowReturns': True,
                    'returnPeriodDays': 7,
                },
                'customization': {
                    'announcement': '',
                    'primaryColor': '#3b82f6',
                    'themeMode': 'light',
                },
                'chat': {
                    'autoReplyEnabled': False,
                    'autoReplyMessage': 'Thank you for your message! We will get back to you shortly.',
                },
            }), 200

        # Get or create defaults for each settings type
        shipping = db.session.execute(
            select(ShippingSettings).where(ShippingSettings.store_id == store.id)
        ).scalars().all()

        payment = db.session.execute(
            select(PaymentSettings).where(PaymentSettings.store_id == store.id)
        ).scalar_one_or_none()
        if not payment:
            payment = PaymentSettings(cod_enabled=True, store_id=store.id)
            db.session.add(payment)

        order = db.session.execute(
            select(OrderSettings).where(OrderSettings.store_id == store.id)
        ).scalar_one_or_none()
        if not order:
            order = OrderSettings(store_id=store.id)
            db.session.add(order)

        customization = db.session.execute(
            select(ShopCustomization).where(ShopCustomization.store_id == store.id)
        ).scalar_one_or_none()
        if not customization:
            customization = ShopCustomization(store_id=store.id)
            db.session.add(customization)

        chat = db.session.execute(
            select(ChatSettings).where(ChatSettings.store_id == store.id)
        ).scalar_one_or_none()
        if not chat:
            chat = ChatSettings(store_id=store.id)
            db.session.add(chat)

        db.session.commit()

        return jsonify(settings={
            'shipping': [s.to_json() for s in shipping],
            'payment': payment.to_json() if payment else None,
            'order': order.to_json() if order else None,
            'customization': customization.to_json() if customization else None,
            'chat': chat.to_json() if chat else None,
        }), 200
    except Exception as e:
        db.session.rollback()
        current_app.logger.exception(f"[get_all_shop_settings] Error: {e}")
        return jsonify(msg='Error occurred'), 500


@seller_bp.get('/analytics')
@jwt_required()
@seller_required()
def get_seller_analytics():
    """Get seller analytics data including sales, orders, and top products."""
    try:
        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        # Get query parameters for time range
        days = request.args.get('days', '30', type=int)
        if days not in [7, 30, 90, 365]:
            days = 30

        # Calculate date range
        end_date = datetime.datetime.utcnow()
        start_date = end_date - datetime.timedelta(days=days)

        # Get total revenue and orders for the period
        revenue_result = db.session.execute(
            select(func.coalesce(func.sum(Order.total_amount), 0))
            .where(
                Order.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
        ).scalar()

        orders_count = db.session.execute(
            select(func.count(Order.id))
            .where(
                Order.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES),
            )
        ).scalar()

        # Get previous period for comparison
        prev_start = start_date - datetime.timedelta(days=days)
        prev_end = start_date

        prev_revenue = db.session.execute(
            select(func.coalesce(func.sum(Order.total_amount), 0))
            .where(
                Order.store_id == store.id,
                Order.created_at >= prev_start,
                Order.created_at <= prev_end,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
        ).scalar()

        prev_orders = db.session.execute(
            select(func.count(Order.id))
            .where(
                Order.store_id == store.id,
                Order.created_at >= prev_start,
                Order.created_at <= prev_end,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES),
            )
        ).scalar()

        # Calculate growth percentages
        revenue_growth = ((revenue_result - prev_revenue) / prev_revenue * 100) if prev_revenue > 0 else 0
        orders_growth = ((orders_count - prev_orders) / prev_orders * 100) if prev_orders > 0 else 0

        # Get daily sales data for charts
        daily_sales = db.session.execute(
            select(
                func.date(Order.created_at).label('date'),
                func.coalesce(func.sum(Order.total_amount), 0).label('sales'),
                func.count(Order.id).label('orders')
            )
            .where(
                Order.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
            .group_by(func.date(Order.created_at))
            .order_by(func.date(Order.created_at))
        ).all()

        # Format sales data for chart
        sales_chart_data = [
            {'name': str(row.date)[:10] if row.date else '', 'sales': float(row.sales), 'orders': row.orders}
            for row in daily_sales
        ]

        # Get top products by revenue
        top_products = db.session.execute(
            select(
                Product.name,
                func.sum(OrderItem.quantity * OrderItem.unit_price).label('revenue'),
                func.sum(OrderItem.quantity).label('quantity_sold')
            )
            .join(OrderItem, OrderItem.product_id == Product.id)
            .join(Order, Order.id == OrderItem.order_id)
            .where(
                Product.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
            .group_by(Product.id, Product.name)
            .order_by(func.sum(OrderItem.quantity * OrderItem.unit_price).desc())
            .limit(5)
        ).all()

        # Get category breakdown
        category_sales = db.session.execute(
            select(
                Category.name,
                func.sum(OrderItem.quantity * OrderItem.unit_price).label('sales')
            )
            .join(ProductCategory, ProductCategory.category_id == Category.id)
            .join(Product, Product.id == ProductCategory.product_id)
            .join(OrderItem, OrderItem.product_id == Product.id)
            .join(Order, Order.id == OrderItem.order_id)
            .where(
                Product.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
            .group_by(Category.id, Category.name)
            .order_by(func.sum(OrderItem.quantity * OrderItem.unit_price).desc())
        ).all()

        total_category_sales = sum(c.sales for c in category_sales) or 1  # Avoid division by zero
        category_data = [
            {'name': c.name, 'value': round(float(c.sales) / total_category_sales * 100, 1)}
            for c in category_sales
        ]

        # Get unique customers count
        customers_count = db.session.execute(
            select(func.count(func.distinct(Order.buyer_id)))
            .where(
                Order.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES),
            )
        ).scalar()

        # Calculate average order value
        avg_order_value = (revenue_result / orders_count) if orders_count > 0 else 0

        return jsonify({
            'period': f'{days}d',
            'summary': {
                'totalRevenue': float(revenue_result),
                'totalOrders': orders_count,
                'totalCustomers': customers_count,
                'avgOrderValue': float(avg_order_value),
                'revenueGrowth': round(revenue_growth, 1),
                'ordersGrowth': round(orders_growth, 1),
            },
            'salesChart': sales_chart_data,
            'topProducts': [
                {
                    'name': p.name,
                    'revenue': float(p.revenue),
                    'quantitySold': p.quantity_sold,
                    'growth': 0  # Would need historical data for accurate growth
                }
                for p in top_products
            ],
            'categoryData': category_data,
        }), 200

    except Exception as e:
        current_app.logger.exception(f"[get_seller_analytics] Error: {e}")
        return jsonify(msg='Error fetching analytics'), 500


@seller_bp.get('/analytics/download')
@jwt_required()
@seller_required()
def download_seller_analytics_report():
    """Download seller analytics report as PDF with per-line-item sales breakdown."""
    try:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import landscape, A4
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import inch
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.enums import TA_CENTER, TA_LEFT
        import io
        import datetime as dt

        store = _get_seller_store(current_user.id)
        if not store:
            return jsonify(msg='Store not found'), 404

        days = request.args.get('days', 30, type=int)
        if days not in [7, 30, 90, 365]:
            days = 30

        end_date = dt.datetime.utcnow()
        start_date = end_date - dt.timedelta(days=days)

        # --- Fetch all order items for this store in the period ---
        rows = db.session.execute(
            select(
                OrderItem.id,
                Product.name.label('product_name'),
                OrderItem.unit_price,
                OrderItem.quantity,
                OrderItem.discount_amount,
                Product.cost_price,
                Order.shipping_fee,
                Order.admin_commission,
                Order.created_at,
            )
            .join(Order, Order.id == OrderItem.order_id)
            .join(Product, Product.id == OrderItem.product_id)
            .where(
                Order.store_id == store.id,
                Order.created_at >= start_date,
                Order.created_at <= end_date,
                Order.status.in_(_ANALYTICS_REVENUE_STATUSES)
            )
            .order_by(Order.created_at.asc(), OrderItem.id.asc())
        ).all()

        # --- Summary totals ---
        total_net_sales   = sum((float(r.unit_price or 0) * int(r.quantity or 0)) - float(r.discount_amount or 0) for r in rows)
        total_commission  = sum(float(r.admin_commission or 0) for r in rows)
        total_cogs        = sum(float(r.cost_price or 0) * int(r.quantity or 0) for r in rows)
        total_gross_profit = total_net_sales - total_commission - total_cogs
        total_items = len(rows)

        # --- Build PDF (landscape A4 for wide table) ---
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=landscape(A4),
            rightMargin=36, leftMargin=36,
            topMargin=48, bottomMargin=36,
        )
        elements = []
        styles = getSampleStyleSheet()

        title_style = ParagraphStyle(
            'Title', parent=styles['Heading1'],
            fontSize=18, textColor=colors.HexColor('#1B365D'),
            spaceAfter=6, alignment=TA_CENTER,
        )
        sub_style = ParagraphStyle(
            'Sub', parent=styles['Normal'],
            fontSize=10, textColor=colors.HexColor('#555555'),
            alignment=TA_CENTER,
        )
        footer_style = ParagraphStyle(
            'Footer', parent=styles['Normal'],
            fontSize=7, textColor=colors.grey,
            alignment=TA_CENTER,
        )

        elements.append(Paragraph("Yamada E-Commerce — Sales Report", title_style))
        elements.append(Paragraph(f"Shop: {store.store_name}", sub_style))
        elements.append(Spacer(1, 4))
        elements.append(Paragraph(
            f"Period: Last {days} Days  "
            f"({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')})",
            sub_style,
        ))
        elements.append(Spacer(1, 16))

        # --- Summary strip ---
        summary_data = [
            ['Total Line Items', 'Total Net Sales', 'Total COGS', 'Total Platform Fee', 'Total Gross Profit'],
            [
                f"{total_items:,}",
                f"PHP {total_net_sales:,.2f}",
                f"PHP {total_cogs:,.2f}",
                f"PHP {total_commission:,.2f}",
                f"PHP {total_gross_profit:,.2f}",
            ],
        ]
        summary_table = Table(summary_data, colWidths=[1.5 * inch] * 5)
        summary_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1B365D')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 9),
            ('FONTNAME', (0, 1), (-1, 1), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 1), (-1, 1), 10),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CCCCCC')),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
            ('TOPPADDING', (0, 0), (-1, -1), 6),
            ('BACKGROUND', (0, 1), (-1, 1), colors.HexColor('#F0F4FF')),
        ]))
        elements.append(summary_table)
        elements.append(Spacer(1, 20))

        # --- Per-line-item sales table ---
        elements.append(Paragraph("Sales Breakdown", styles['Heading2']))
        elements.append(Spacer(1, 8))

        # Column widths (landscape A4 usable ≈ 10.7 inch)
        col_widths = [
            0.45 * inch,   # ID
            2.10 * inch,   # Product Name
            0.75 * inch,   # Unit Price
            0.55 * inch,   # Qty
            0.80 * inch,   # Subtotal
            0.65 * inch,   # Discount
            0.80 * inch,   # Net Sales
            0.80 * inch,   # Shipping Fee
            0.85 * inch,   # Platform Fee
            0.65 * inch,   # COGS
            0.85 * inch,   # Gross Profit
            0.95 * inch,   # Date of Sale
        ]

        header = [
            'ID', 'Product Name', 'Unit Price', 'Qty', 'Subtotal',
            'Discount', 'Net Sales', 'Shipping Fee', 'Platform Fee',
            'COGS', 'Gross Profit', 'Date of Sale',
        ]
        table_data = [header]

        for r in rows:
            unit_price   = float(r.unit_price or 0)
            quantity     = int(r.quantity or 0)
            subtotal     = unit_price * quantity
            discount     = float(r.discount_amount or 0)
            net_sales    = subtotal - discount
            platform_fee = float(r.admin_commission or 0)
            cogs         = float(r.cost_price or 0) * quantity
            gross_profit = net_sales - platform_fee - cogs
            date_str     = r.created_at.strftime('%Y-%m-%d') if r.created_at else ''

            table_data.append([
                str(r.id),
                (r.product_name or '')[:30] + ('…' if len(r.product_name or '') > 30 else ''),
                f"{unit_price:,.2f}",
                str(quantity),
                f"{subtotal:,.2f}",
                f"{discount:,.2f}",
                f"{net_sales:,.2f}",
                f"{float(r.shipping_fee or 0):,.2f}",
                f"{platform_fee:,.2f}",
                f"{cogs:,.2f}",
                f"{gross_profit:,.2f}",
                date_str,
            ])

        if len(table_data) == 1:
            table_data.append(['—'] * 12)

        sales_table = Table(table_data, colWidths=col_widths, repeatRows=1)
        sales_table.setStyle(TableStyle([
            # Header row
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#F5A3B5')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor('#1B365D')),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 7),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 6),
            ('TOPPADDING', (0, 0), (-1, 0), 6),
            # Data rows
            ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, -1), 7),
            ('BOTTOMPADDING', (0, 1), (-1, -1), 4),
            ('TOPPADDING', (0, 1), (-1, -1), 4),
            # Alignment
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('ALIGN', (1, 1), (1, -1), 'LEFT'),   # Product Name left-aligned
            # Grid
            ('GRID', (0, 0), (-1, -1), 0.4, colors.HexColor('#CCCCCC')),
            # Alternating row colours
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#FFF5F7')]),
            # Highlight gross profit column
            ('TEXTCOLOR', (10, 1), (10, -1), colors.HexColor('#1B7A3E')),
            ('FONTNAME', (10, 1), (10, -1), 'Helvetica-Bold'),
        ]))
        elements.append(sales_table)
        elements.append(Spacer(1, 24))

        # Footer
        elements.append(Paragraph(
            f"Generated on {end_date.strftime('%Y-%m-%d %H:%M:%S')} UTC",
            footer_style,
        ))
        elements.append(Paragraph("© 2026 Yamada E-Commerce Platform", footer_style))

        doc.build(elements)
        buffer.seek(0)

        safe_name = store.store_name.replace(' ', '_')
        return buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': (
                f'attachment; filename=sales-report-{safe_name}-{days}d.pdf'
            ),
        }

    except Exception as e:
        current_app.logger.exception(f"[download_seller_analytics_report] Error: {e}")
        return jsonify(msg='Error generating report'), 500


def _seller_store_for_user():
    seller = db.session.execute(
        select(Seller).where(Seller.user_id == current_user.id)
    ).scalar_one_or_none()
    if seller is None:
        return None, None
    store = db.session.execute(
        select(Store).where(Store.seller_id == seller.id)
    ).scalar_one_or_none()
    return seller, store


@seller_bp.get('/coupons')
@jwt_required()
@seller_required()
def seller_list_coupons():
    _, store = _seller_store_for_user()
    if store is None:
        return jsonify(msg='Store not found'), 404
    coupons = db.session.execute(
        select(Coupon)
        .where(Coupon.store_id == store.id)
        .order_by(Coupon.created_at.desc())
    ).scalars().all()
    return jsonify(coupons=[serialize_coupon(c) for c in coupons]), 200


@seller_bp.post('/coupons')
@jwt_required()
@seller_required()
def seller_create_coupon():
    _, store = _seller_store_for_user()
    if store is None:
        return jsonify(msg='Store not found'), 404
    data = request.get_json() or {}
    if not data.get('code') or not data.get('title'):
        return jsonify(msg='code and title are required'), 400
    coupon = Coupon(
        code=str(data['code']).strip().upper(),
        title=str(data['title']).strip(),
        description=data.get('description'),
        discount_type=data.get('discountType') or data.get('discount_type') or 'percent',
        discount_value=float(data.get('discountValue') or data.get('discount_value') or 0),
        min_order_amount=float(data.get('minOrderAmount') or data.get('min_order_amount') or 0),
        max_uses=data.get('maxUses') or data.get('max_uses'),
        expires_at=datetime.datetime.fromisoformat(data['expiresAt'].replace('Z', '+00:00'))
        if data.get('expiresAt')
        else None,
        is_active=data.get('isActive', data.get('is_active', True)),
        scope='store',
        store_id=store.id,
    )
    try:
        db.session.add(coupon)
        db.session.commit()
        return jsonify(coupon=serialize_coupon(coupon)), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg='Coupon code already exists for this store'), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg='Failed to create coupon'), 500


@seller_bp.put('/coupons/<int:coupon_id>')
@jwt_required()
@seller_required()
def seller_update_coupon(coupon_id: int):
    _, store = _seller_store_for_user()
    if store is None:
        return jsonify(msg='Store not found'), 404
    coupon = db.session.execute(
        select(Coupon).where(Coupon.id == coupon_id, Coupon.store_id == store.id)
    ).scalar_one_or_none()
    if coupon is None:
        return jsonify(msg='Coupon not found'), 404
    data = request.get_json() or {}
    for attr, key in [
        ('title', 'title'),
        ('description', 'description'),
        ('discount_type', 'discountType'),
        ('discount_value', 'discountValue'),
        ('min_order_amount', 'minOrderAmount'),
        ('max_uses', 'maxUses'),
        ('is_active', 'isActive'),
    ]:
        if data.get(key) is not None or data.get(attr) is not None:
            setattr(coupon, attr, data.get(key) or data.get(attr))
    if data.get('code'):
        coupon.code = str(data['code']).strip().upper()
    if data.get('expiresAt'):
        coupon.expires_at = datetime.datetime.fromisoformat(
            data['expiresAt'].replace('Z', '+00:00')
        )
    db.session.commit()
    return jsonify(coupon=serialize_coupon(coupon)), 200


@seller_bp.delete('/coupons/<int:coupon_id>')
@jwt_required()
@seller_required()
def seller_delete_coupon(coupon_id: int):
    _, store = _seller_store_for_user()
    if store is None:
        return jsonify(msg='Store not found'), 404
    coupon = db.session.execute(
        select(Coupon).where(Coupon.id == coupon_id, Coupon.store_id == store.id)
    ).scalar_one_or_none()
    if coupon is None:
        return jsonify(msg='Coupon not found'), 404
    db.session.delete(coupon)
    db.session.commit()
    return jsonify(msg='Coupon deleted'), 200