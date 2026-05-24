from . import (
    orders as orders_bp,
)
from app.models import (
    db,
    Order,
    OrderItem,
    Product,
    Store,
    User,
    BuyerProfile,
    OrderStatus,
    RiderDelivery,
    RiderProfile,
    DeliveryStatus,
    PaymentTransaction,
    PaymentStatus,
    SellerWallet,
    RefundRequest,
    RefundStatus,
    Review,
    RoleTypes,
    Seller,
    StoreRequestStatus,
)
from app.services.commission_service import CommissionService
from app.services.shipping_service import ShippingService
from app.notifications.service import (
    create_notification,
    notify_buyer_order_status,
    notify_buyer_refund_requested,
    notify_buyer_refund_approved,
    notify_buyer_refund_declined,
    notify_seller_new_order,
    notify_seller_payout_released,
    notify_rider_new_delivery_assignment,
    notify_seller_low_stock_alert,
    notify_seller_stock_depleted,
    notify_seller_refund_requested,
)
from flask import jsonify, abort, request, current_app
from app.utils.static_urls import public_static_url as _public_image_url
from flask_jwt_extended import jwt_required, current_user
from sqlalchemy import select, func, exists
from sqlalchemy.orm import selectinload
from app.models import Order
from sqlalchemy.exc import IntegrityError
import datetime as dt
import ast
import os
from werkzeug.utils import secure_filename

ADMIN_COMMISSION_RATE = 0.10
RIDER_FIXED_EARNING = 50.0
RIDER_FEE_ADMIN_SHARE_PERCENT = 50.0
RIDER_FEE_SELLER_SHARE_PERCENT = 50.0


def _compute_order_financials(order: Order) -> dict:
    """Compute a financial breakdown for a single-store order.

    Uses the platform rules:
    - Admin commission: fixed percentage of product subtotal (order.total_amount).
    - Rider earnings: fixed amount applied when a delivery is marked DELIVERED.
    - Rider fee sharing: split between admin and seller according to constants.
    - Seller payout: subtotal minus admin commission minus seller share of rider fee.
    """

    subtotal = float(order.total_amount or 0.0)
    admin_commission = subtotal * ADMIN_COMMISSION_RATE

    rider_fee = 0.0
    deliveries = getattr(order, "deliveries", None) or []
    if deliveries:
        deliveries_sorted = sorted(
            deliveries,
            key=lambda d: getattr(d, "created_at", None) or dt.datetime.min,
            reverse=True,
        )
        d = deliveries_sorted[0]
        status_value = d.status.value if hasattr(d.status, "value") else str(d.status)
        # After pickup: rider earns the fixed amount once the delivery has
        # progressed beyond PENDING, i.e. PICKUP, TRANSIT, or DELIVERED.
        if status_value in {
            DeliveryStatus.PICKUP.value,
            DeliveryStatus.TRANSIT.value,
            DeliveryStatus.DELIVERED.value,
        }:
            rider_fee = RIDER_FIXED_EARNING

    admin_share_rider_fee = rider_fee * (RIDER_FEE_ADMIN_SHARE_PERCENT / 100.0)
    seller_share_rider_fee = rider_fee * (RIDER_FEE_SELLER_SHARE_PERCENT / 100.0)

    seller_payout = float(subtotal - admin_commission - seller_share_rider_fee)
    if seller_payout < 0.0:
        seller_payout = 0.0

    platform_fee = float(admin_commission + admin_share_rider_fee)

    phase = "after_pickup" if rider_fee > 0.0 else "before_pickup"

    return {
        "subtotal": subtotal,
        "adminCommission": admin_commission,
        "riderFeeTotal": rider_fee,
        "adminShareOfRiderFee": admin_share_rider_fee,
        "sellerShareOfRiderFee": seller_share_rider_fee,
        "sellerPayout": seller_payout,
        "platformFee": platform_fee,
        "phase": phase,
    }

def _product_main_image_url(product: Product | None) -> str | None:
    """Return a normalized main image URL for a product.

    Prefers the product.image_url field; if it's missing, falls back to the
    first image-type ProductMedia.path if available. The final value is
    normalized through _public_image_url so the frontend always receives a
    URL that points at the Flask static origin.
    """

    if product is None:
        return None

    rel = getattr(product, "image_url", None)

    # Fallback: use first image media path
    if not rel:
        media_list = getattr(product, "media", None)
        if media_list:
            for m in media_list:
                if getattr(m, "media_type", None) == "image" and getattr(m, "path", None):
                    rel = m.path
                    break

    return _public_image_url(rel)


def _order_status_value(status) -> str:
    """Return lowercase order status string for API responses."""
    if isinstance(status, OrderStatus):
        return status.value
    if status is None:
        return ""
    return str(status).strip().lower()


def _delivery_status_value(status) -> str:
    if isinstance(status, DeliveryStatus):
        return status.value
    if status is None:
        return ""
    return str(status).strip().lower()


def _proof_photo_url(rel_path: str | None) -> str | None:
    """Build a public URL for a stored proof-of-delivery image path."""
    if not rel_path:
        return None
    rel = str(rel_path).replace("\\", "/").lstrip("/")
    if rel.startswith("http://") or rel.startswith("https://"):
        return rel
    return _public_image_url(rel)


def _has_proof_photo(rel_path: str | None) -> bool:
    return bool(rel_path and str(rel_path).strip())


def _latest_rider_delivery(order: Order) -> RiderDelivery | None:
    deliveries = getattr(order, "deliveries", None) or []
    if not deliveries:
        return None
    return sorted(
        deliveries,
        key=lambda d: getattr(d, "created_at", None) or dt.datetime.min,
        reverse=True,
    )[0]


def _current_order_status(order: Order) -> OrderStatus | None:
    if isinstance(order.status, OrderStatus):
        return order.status
    try:
        return OrderStatus(_order_status_value(order.status))
    except ValueError:
        return None


def _sync_order_status_from_rider_delivery(order: Order) -> None:
    """Align orders.status when rider delivery is completed but order row is stale."""
    delivery = _latest_rider_delivery(order)
    if delivery is None:
        return

    delivery_status = _delivery_status_value(delivery.status)
    has_proof = _has_proof_photo(getattr(delivery, "proof_photo_path", None))
    if delivery_status != "delivered" and not has_proof:
        return

    current = _current_order_status(order)
    if current is None:
        return
    if current in {
        OrderStatus.DELIVERED,
        OrderStatus.COMPLETED,
        OrderStatus.CANCELLED,
        OrderStatus.RETURNED,
    }:
        return

    order.status = OrderStatus.DELIVERED
    order.updated_at = dt.datetime.utcnow()
    if delivery_status != "delivered":
        delivery.status = DeliveryStatus.DELIVERED
        delivery.updated_at = dt.datetime.utcnow()


def _buyer_can_confirm_receipt(order: Order) -> bool:
    """Buyer may confirm receipt before the order is marked completed."""
    current = _current_order_status(order)
    if current is None:
        return False
    if current in {
        OrderStatus.COMPLETED,
        OrderStatus.CANCELLED,
        OrderStatus.RETURNED,
        OrderStatus.PENDING,
    }:
        return False
    if current in {OrderStatus.DELIVERED, OrderStatus.OUT_FOR_DELIVERY}:
        return True

    delivery = _latest_rider_delivery(order)
    if delivery is None:
        return False

    delivery_status = _delivery_status_value(delivery.status)
    has_proof = _has_proof_photo(getattr(delivery, "proof_photo_path", None))
    return delivery_status == "delivered" or has_proof


def _prepare_order_for_buyer_confirm(order: Order) -> None:
    """Promote in-transit rows to delivered before buyer completion."""
    _sync_order_status_from_rider_delivery(order)
    current = _current_order_status(order)
    if current in {OrderStatus.COMPLETED, OrderStatus.CANCELLED, OrderStatus.RETURNED}:
        return
    if _buyer_can_confirm_receipt(order) and current != OrderStatus.DELIVERED:
        order.status = OrderStatus.DELIVERED
        order.updated_at = dt.datetime.utcnow()
        delivery = _latest_rider_delivery(order)
        if delivery is not None and _delivery_status_value(delivery.status) != "delivered":
            delivery.status = DeliveryStatus.DELIVERED
            delivery.updated_at = dt.datetime.utcnow()


def _serialize_order(order: Order) -> dict:
    prev_status = _order_status_value(order.status)
    _sync_order_status_from_rider_delivery(order)
    if _order_status_value(order.status) != prev_status:
        try:
            db.session.commit()
        except Exception:
            db.session.rollback()

    raw_address = order.shipping_address

    pretty_address: str | None = None
    address_parts: dict | None = None

    try:
        if isinstance(raw_address, str):
            text = raw_address.strip()
            if text.startswith("{") and "barangay" in text:
                data = ast.literal_eval(text)
                if isinstance(data, dict):
                    address_parts = {
                        "streetAddress": data.get("streetAddress") or data.get("street_address"),
                        "barangayName": data.get("barangayName") or data.get("barangay_name"),
                        "municipalityName": data.get("municipalityName") or data.get("municipality_name"),
                        "provinceName": data.get("provinceName") or data.get("province_name"),
                        "regionName": data.get("regionName") or data.get("region_name"),
                        "postalCode": data.get("postalCode") or data.get("postal_code"),
                    }

                    pretty_address = ", ".join(
                        [
                            part
                            for part in [
                                address_parts.get("streetAddress"),
                                address_parts.get("barangayName"),
                                address_parts.get("municipalityName"),
                                address_parts.get("provinceName"),
                                address_parts.get("regionName"),
                                address_parts.get("postalCode"),
                            ]
                            if part
                        ]
                    ) or None
    except Exception:
        pretty_address = None
        address_parts = None

    store = getattr(order, "store", None)
    store_payload = None
    if store is not None:
        try:
            store_payload = {
                "id": store.id,
                "name": getattr(store, "store_name", None),
                "email": getattr(store, "store_email", None),
            }
        except Exception:
            store_payload = None

    rider_delivery = None
    try:
        d = _latest_rider_delivery(order)
        if d is not None:
            rider = getattr(d, "rider", None)
            rider_info = None
            if rider is not None:
                try:
                    full_name = " ".join(
                        [
                            (getattr(rider, "given_name", None) or "").strip(),
                            (getattr(rider, "surname", None) or "").strip(),
                        ]
                    ).strip()
                    # Pull vehicle info from rider_profile if loaded
                    vehicle_type = None
                    license_number = None
                    rider_profile = getattr(rider, "rider_profile", None)
                    if rider_profile is not None:
                        vehicle_type = getattr(rider_profile, "vehicle_type", None)
                        license_number = getattr(rider_profile, "license_number", None)
                    rider_info = {
                        "id": rider.id,
                        "email": getattr(rider, "email", None),
                        "name": full_name or getattr(rider, "email", None),
                        "contactNumber": getattr(rider, "contact_number", None) or "",
                        "vehicleType": vehicle_type,
                        "licenseNumber": license_number,
                    }
                except Exception:
                    rider_info = None

            proof_path = getattr(d, "proof_photo_path", None)
            rider_delivery = {
                "id": d.id,
                "status": _delivery_status_value(d.status),
                "rider": rider_info,
                "hasProofPhoto": _has_proof_photo(proof_path),
                "proofPhotoUrl": _proof_photo_url(proof_path),
                "proofNote": getattr(d, "proof_note", None),
            }
    except Exception:
        rider_delivery = None

    # Calculate financial breakdown
    financials = CommissionService.calculate_order_financials(order)
    
    # Calculate grand total for client compatibility
    subtotal = float(order.total_amount or 0.0)
    shipping = float(order.shipping_fee or 0.0)
    grand_total = subtotal + shipping
    
    return {
        "id": order.id,
        "orderNumber": str(order.id),  # String for web/mobile compatibility
        "status": _order_status_value(order.status),
        "subtotal": subtotal,  # Product subtotal only
        "shipping": shipping,  # Shipping fee
        "shippingFee": shipping,  # Alias for internal use
        "total": grand_total,  # Grand total (subtotal + shipping) - web client expects this
        "grandTotal": grand_total,  # Alias for mobile compatibility
        "adminCommission": order.admin_commission,
        "paymentMethod": order.payment_method,
        "shippingAddress": pretty_address or raw_address,
        "shippingAddressParts": address_parts,
        "createdAt": order.created_at.isoformat() if order.created_at else None,
        "updatedAt": order.updated_at.isoformat() if order.updated_at else None,
        "buyer": {
            "id": order.buyer.id if order.buyer else None,
            "email": order.buyer.email if order.buyer else None,
        },
        "store": store_payload,
        "riderDelivery": rider_delivery,
        "financialBreakdown": financials,
        "items": [
            {
                "id": item.id,
                "productId": item.product_id,
                "quantity": item.quantity,
                "unitPrice": item.unit_price,
                "variation": item.variation,
                "sellerId": item.product.store.id if item.product and item.product.store else None,
                "sellerName": item.product.store.store_name if item.product and item.product.store else "Unknown Seller",
                "product": (
                    {
                        "id": item.product.id,
                        "name": item.product.name,
                        "price": float(item.product.price),
                        "imageUrl": _product_main_image_url(item.product),
                    }
                    if item.product is not None
                    else None
                ),
            }
            for item in order.items
        ],
    }


def _serialize_rider_delivery(delivery: RiderDelivery) -> dict:
    order = delivery.order
    buyer = order.buyer if order else None
    store = getattr(order, "store", None) if order is not None else None

    # Try to derive municipality from the buyer profile when available so riders
    # can see a more specific dropoff area.
    buyer_profile = getattr(buyer, "buyer_profile", None) if buyer is not None else None
    municipality_name = getattr(buyer_profile, "municipality_name", None) if buyer_profile else None

    buyer_name = None
    buyer_initials = None
    buyer_contact = None
    try:
        if buyer is not None:
            given = getattr(buyer, "given_name", None) or ""
            surname = getattr(buyer, "surname", None) or ""
            full = f"{given} {surname}".strip()
            buyer_name = full or buyer.email

            initials_src = full or buyer.email or ""
            initials = "".join([part[0].upper() for part in initials_src.split() if part])[:2]
            buyer_initials = initials or None

            buyer_contact = getattr(buyer, "contact_number", None)
    except Exception:
        pass

    items_summary: list[dict] = []
    first_product_store_name = None
    try:
        if order is not None:
            for item in getattr(order, "items", []) or []:
                product = getattr(item, "product", None)
                if product is not None and first_product_store_name is None:
                    # Best-effort fallback: try to read the store name from the product
                    product_store = getattr(product, "store", None)
                    if product_store is not None:
                        # Admin flow uses Store.store_name; mirror that here
                        first_product_store_name = getattr(product_store, "store_name", None)

                items_summary.append(
                    {
                        "id": item.id,
                        "name": getattr(product, "name", None),
                        "quantity": item.quantity,
                    }
                )
    except Exception:
        items_summary = []

    return {
        "id": delivery.id,
        "deliveryId": delivery.id,
        "displayLabel": f"DEL-{delivery.id}",
        "orderId": order.id if order else None,
        "status": delivery.status.value if isinstance(delivery.status, DeliveryStatus) else delivery.status,
        "fee": float(delivery.fee or 0.0),
        "distanceKm": float(delivery.distance_km or 0.0),
        "createdAt": delivery.created_at.isoformat() if delivery.created_at else None,
        "updatedAt": delivery.updated_at.isoformat() if delivery.updated_at else None,
        "storeId": getattr(store, "id", None) if store is not None else None,
        "store": {
            "id": getattr(store, "id", None) if store is not None else None,
            # Use Store.store_name just like _serialize_order / admin flow
            "name": (
                getattr(store, "store_name", None)
                if store is not None and getattr(store, "store_name", None) is not None
                else first_product_store_name
            ),
        },
        "buyer": {
            "id": buyer.id if buyer else None,
            "email": buyer.email if buyer else None,
            "name": buyer_name,
            "initials": buyer_initials,
            "contact": buyer_contact,
        },
        # Reuse order.shipping_address as a human-readable address string, and
        # also include a structured municipality when we can.
        "shippingAddress": order.shipping_address if order else None,
        "municipalityName": municipality_name,
        "deliveryNotes": getattr(order, "delivery_notes", None) if order else None,
        "items": items_summary,
        "isAutoMatched": False,
        "hasProofPhoto": _has_proof_photo(getattr(delivery, "proof_photo_path", None)),
        "proofPhotoUrl": _proof_photo_url(getattr(delivery, "proof_photo_path", None)),
        "proofNote": getattr(delivery, "proof_note", None),
    }


def _serialize_available_order_for_rider(order: Order) -> dict:
	"""Serialize an order as a rider-available delivery based on municipality.

	These are orders that match the rider's area (municipality) and have
	order.status in {SHIPPED, OUT_FOR_DELIVERY}. They are not yet tied to a
	specific RiderDelivery row, but we expose them using the same shape as
	RiderDelivery so the rider UI can list them.

	For UI consistency, we surface status as "pending" so that the rider
	Deliveries page shows the label "Shipped" (mapped client-side).
	"""

	buyer = order.buyer
	buyer_profile = getattr(buyer, "buyer_profile", None) if buyer is not None else None
	municipality_name = getattr(buyer_profile, "municipality_name", None) if buyer_profile else None

	buyer_name = None
	buyer_initials = None
	buyer_contact = None
	try:
		if buyer is not None:
			given = getattr(buyer, "given_name", None) or ""
			surname = getattr(buyer, "surname", None) or ""
			full = f"{given} {surname}".strip()
			buyer_name = full or buyer.email

			initials_src = full or buyer.email or ""
			initials = "".join([part[0].upper() for part in initials_src.split() if part])[:2]
			buyer_initials = initials or None

			buyer_contact = getattr(buyer, "contact_number", None)
	except Exception:
		pass

	items_summary: list[dict] = []
	try:
		for item in getattr(order, "items", []) or []:
			product = getattr(item, "product", None)
			items_summary.append(
				{
					"id": item.id,
					"name": getattr(product, "name", None),
					"quantity": item.quantity,
				}
			)
	except Exception:
		items_summary = []

	return {
		"id": order.id,
		"deliveryId": None,
		"displayLabel": f"ORD-{order.id}",
		"orderId": order.id,
		"status": DeliveryStatus.PENDING.value,
		"fee": float(order.total_amount or 0.0),
		"distanceKm": float(0.0),
		"createdAt": order.created_at.isoformat() if order.created_at else None,
		"updatedAt": order.updated_at.isoformat() if order.updated_at else None,
		"buyer": {
			"id": buyer.id if buyer else None,
			"email": buyer.email if buyer else None,
			"name": buyer_name,
			"initials": buyer_initials,
			"contact": buyer_contact,
		},
		"shippingAddress": order.shipping_address,
		"municipalityName": municipality_name,
		"deliveryNotes": getattr(order, "delivery_notes", None),
		"items": items_summary,
		"isAutoMatched": True,
	}


@orders_bp.post("/orders/checkout")
@jwt_required()
def checkout():
    """Create a new order from the provided cart-like payload.

    Expected JSON body (aligned with CheckoutData on the client):
    {
      "shippingAddress": { ... },
      "paymentMethod": "string",
      "items": [
        { "productId": "1", "quantity": 2, "variant": { ... } }
      ]
    }
    """

    if not request.is_json:
        abort(400)

    from app.services.punishment_service import PunishmentService, ACTION_ORDERING

    blocked = PunishmentService.enforce(current_user.id, ACTION_ORDERING)
    if blocked:
        return blocked

    data = request.get_json()
    items_data = data.get("items", [])
    if not items_data:
        return jsonify(msg="No items to checkout"), 400

    idempotency_key = (data.get("idempotencyKey") or data.get("idempotency_key") or "").strip()
    if idempotency_key:
        if len(idempotency_key) > 64:
            return jsonify(msg="Invalid idempotency key"), 400
        existing_order = db.session.execute(
            select(Order).where(
                Order.buyer_id == current_user.id,
                Order.idempotency_key == idempotency_key,
            )
        ).scalar_one_or_none()
        if existing_order is not None:
            return jsonify(order=_serialize_order(existing_order)), 200

    # Mirror login is_verified: buyers need email_verified; sellers need store ACCEPTED
    from flask_jwt_extended import get_jwt

    is_verified = getattr(current_user, "email_verified", False)
    user_roles = [
        ur.role_id for ur in (getattr(current_user, "roles", None) or [])
    ]
    claims = get_jwt()
    if RoleTypes.SELLER.value in user_roles or claims.get("is_seller"):
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == current_user.id)
        ).scalar_one_or_none()
        if seller and seller.registration:
            is_verified = (
                seller.registration.request_status
                == StoreRequestStatus.ACCEPTED
            )
    if not is_verified:
        return (
            jsonify(
                msg="Your account is not yet verified. Please wait for admin approval before placing orders."
            ),
            403,
        )

    try:
        # For now we assume all products in the order belong to the same store
        first_product_id = int(items_data[0]["productId"])
        first_product = db.session.execute(
            select(Product).where(Product.id == first_product_id)
        ).scalar_one_or_none()
        if first_product is None:
            return jsonify(msg="Invalid product in order"), 400

        store_id = first_product.store_id

        # Fetch store early — needed for stock notifications inside the items loop below.
        store = db.session.execute(
            select(Store).where(Store.id == store_id)
        ).scalar_one_or_none()

        # Sellers cannot purchase from their own store.
        own_store = db.session.execute(
            select(Store).where(Store.user_id == current_user.id)
        ).scalar_one_or_none()
        if own_store is not None and own_store.id == store_id:
            return jsonify(msg="You cannot purchase products from your own store"), 400

        shipping_address = data.get("shippingAddress")
        import json as _json_addr
        if isinstance(shipping_address, dict):
            shipping_address_str = _json_addr.dumps(shipping_address)
        elif isinstance(shipping_address, str):
            shipping_address_str = shipping_address
        else:
            shipping_address_str = str(shipping_address)

        payment_method = data.get("paymentMethod")

        # Derive initial status based on payment method
        # COD behaves as "To Pay / To Ship" (PENDING), while prepaid
        # methods like gcash/card move directly to PROCESSING.
        initial_status = OrderStatus.PENDING
        if isinstance(payment_method, str):
            pm_lower = payment_method.lower()
            if pm_lower in {"gcash", "card"}:
                initial_status = OrderStatus.PROCESSING

        delivery_notes_raw = data.get("notes")
        delivery_notes = None
        if delivery_notes_raw is not None:
            delivery_notes = str(delivery_notes_raw).strip() or None

        order = Order(
            buyer_id=current_user.id,
            store_id=store_id,
            status=initial_status,
            payment_method=payment_method,
            shipping_address=shipping_address_str,
            delivery_notes=delivery_notes,
            idempotency_key=idempotency_key or None,
        )

        total = 0.0
        db.session.add(order)
        db.session.flush()  # ensure order.id is available

        for item in items_data:
            product_id = int(item["productId"])
            quantity = int(item.get("quantity", 1))

            # Use FOR UPDATE to prevent concurrent overselling
            product = db.session.execute(
                select(Product)
                .options(selectinload(Product.variations))
                .where(Product.id == product_id)
                .with_for_update()
            ).scalar_one_or_none()
            if product is None:
                raise ValueError("Product not found")

            # Use sale_price if active, otherwise regular price
            regular_price = float(product.price)
            sale_price = float(product.sale_price) if product.sale_price else None
            unit_price = sale_price if sale_price is not None else regular_price
            discount_amount = round((regular_price - unit_price) * quantity, 2) if sale_price is not None else 0.0
            line_total = unit_price * quantity
            total += line_total

            # Handle stock deduction for variations if present
            variant_data = item.get("variant")
            variation_stock_depleted = False
            matched_variation = None

            if variant_data:
                variant_size = variant_data.get("size")
                variant_color = variant_data.get("color")

                for variation in getattr(product, "variations", []):
                    if (
                        variation.size == variant_size
                        and variation.color == variant_color
                    ):
                        matched_variation = variation
                        try:
                            previous_var_qty = int(
                                getattr(variation, "inventory", 0) or 0
                            )
                        except (TypeError, ValueError):
                            previous_var_qty = 0

                        if previous_var_qty < quantity:
                            raise ValueError(
                                f"Insufficient stock for {product.name} "
                                f"({variant_size}/{variant_color})"
                            )

                        new_var_qty = previous_var_qty - quantity
                        variation.inventory = new_var_qty
                        if previous_var_qty > 0 and new_var_qty == 0:
                            variation_stock_depleted = True
                        break

                if matched_variation is None and variant_size:
                    raise ValueError(
                        f"Selected variant not found for {product.name}"
                    )

            # Decrement product-level quantity only when no variant line was used
            try:
                previous_qty = int(getattr(product, "quantity", 0) or 0)
            except (TypeError, ValueError):
                previous_qty = 0

            if matched_variation is None:
                if previous_qty < quantity:
                    raise ValueError(f"Insufficient stock for {product.name}")
                new_qty = previous_qty - quantity
                product.quantity = new_qty
            else:
                new_qty = previous_qty

            threshold = getattr(product, "low_stock_threshold", None)
            # Only notify when we cross from above threshold to at/below threshold.
            if (
                threshold is not None
                and isinstance(threshold, int)
                and previous_qty > threshold >= new_qty
                and store is not None
                and store.user_id is not None
            ):
                notify_seller_low_stock_alert(
                    user_id=store.user_id,
                    product_name=product.name,
                    stock_level=new_qty,
                )

            # Separate notification when stock is fully depleted.
            if (
                ((previous_qty > 0 and new_qty == 0) or variation_stock_depleted)
                and store is not None
                and store.user_id is not None
            ):
                notify_seller_stock_depleted(
                    user_id=store.user_id,
                    product_name=product.name,
                )

            order_item = OrderItem(
                order_id=order.id,
                product_id=product.id,
                quantity=quantity,
                unit_price=unit_price,
                discount_amount=discount_amount,
                variation=str(item.get("variant") or {}),
            )
            db.session.add(order_item)

        # Get shipping fee from frontend (pre-calculated in cart) or calculate here
        frontend_shipping_fee = data.get('shippingFee')
        
        if frontend_shipping_fee is not None and isinstance(frontend_shipping_fee, (int, float)):
            shipping_fee = float(frontend_shipping_fee)
            current_app.logger.info(f"[checkout] Using frontend shipping fee: {shipping_fee}")
        else:
            # Calculate shipping fee using ShippingService
            # shipping_address is already a dict from the JSON body — use it directly.
            addr_data = shipping_address if isinstance(shipping_address, dict) else {}
            if not addr_data and isinstance(shipping_address_str, str):
                # Fallback: try JSON parse if we only have the string
                import json as _json
                try:
                    addr_data = _json.loads(shipping_address_str)
                except Exception:
                    addr_data = {}

            buyer_region = addr_data.get('regionName')
            buyer_province = addr_data.get('provinceName')
            buyer_municipality = addr_data.get('municipalityName')

            current_app.logger.info(
                f"[checkout] Calculating shipping: shop_id={store_id}, "
                f"buyer_region={buyer_region!r}, buyer_province={buyer_province!r}, "
                f"buyer_municipality={buyer_municipality!r}, order_total={total}"
            )

            # Use ShippingService with textual location fields (region/province/municipality)
            shipping_result = ShippingService.calculate_shipping_fee(
                shop_id=store_id,
                order_total=total,
                buyer_region=buyer_region,
                buyer_province=buyer_province,
                buyer_municipality=buyer_municipality
            )

            current_app.logger.info(f"[checkout] Shipping result: {shipping_result}")

            if shipping_result.get('error'):
                current_app.logger.warning(
                    f"[checkout] Shipping calc error for store {store_id}: "
                    f"{shipping_result['error']}. Falling back to 130."
                )
            shipping_fee = (
                shipping_result.get('shipping_fee', 130.0)
                if not shipping_result.get('error')
                else 130.0
            )
        
        coupon_code = data.get('couponCode')
        coupon_discount = 0.0
        if coupon_code:
            from app.coupon_helpers import validate_coupon
            from app.models import CouponRedemption

            coupon, coupon_discount, coupon_msg = validate_coupon(
                code=coupon_code,
                user_id=current_user.id,
                store_id=store_id,
                subtotal=total,
            )
            if coupon is None:
                db.session.rollback()
                return jsonify(msg=coupon_msg), 400
            order.coupon_id = coupon.id
            order.coupon_discount = coupon_discount
            coupon.used_count = (coupon.used_count or 0) + 1
            db.session.add(
                CouponRedemption(
                    coupon_id=coupon.id,
                    user_id=current_user.id,
                    order_id=order.id,
                )
            )
            total = max(0.0, total - coupon_discount)

        # Calculate admin commission (10% of product price only)
        commission_rate = CommissionService.get_commission_rate()
        admin_commission = total * commission_rate
        
        order.total_amount = total  # Product subtotal only
        order.shipping_fee = shipping_fee
        order.admin_commission = admin_commission

        # Create a held payment transaction for this order/seller pair
        seller_id = store.seller_id if store is not None else None
        
        # Grand total includes shipping (what customer actually pays)
        grand_total = total + shipping_fee

        payment_tx = PaymentTransaction(
            order_id=order.id,
            seller_id=seller_id,
            amount=grand_total,  # Total amount including shipping
            platform_fee=admin_commission,  # Admin commission only
        )
        db.session.add(payment_tx)

        # Notify buyer and seller about the new order
        create_notification(
            user_id=current_user.id,
            title="Order placed",
            message=f"Your order #{order.id} has been placed.",
            role="buyer",
            page="/orders",
        )
        if store is not None and store.user_id is not None:
            notify_seller_new_order(user_id=store.user_id, order_id=order.id)

        db.session.commit()

        return jsonify(order=_serialize_order(order)), 201
    except IntegrityError as e:
        db.session.rollback()
        if idempotency_key:
            existing_order = db.session.execute(
                select(Order).where(
                    Order.buyer_id == current_user.id,
                    Order.idempotency_key == idempotency_key,
                )
            ).scalar_one_or_none()
            if existing_order is not None:
                return jsonify(order=_serialize_order(existing_order)), 200
        current_app.logger.error(f"Order creation IntegrityError: {e}")
        return jsonify(msg="Database error creating order. Please try again."), 500
    except ValueError as e:
        db.session.rollback()
        current_app.logger.warning(f"Order creation ValueError: {e}")
        return jsonify(msg=str(e)), 400
    except Exception as e:
        db.session.rollback()
        current_app.logger.error(f"Order creation error: {e}", exc_info=True)
        return jsonify(msg=f"Error creating order: {str(e)}"), 500


@orders_bp.get("/orders")
@jwt_required()
def list_orders():
    """List orders for the current buyer.

    Later this can be extended with filters (status, date range, etc.).
    """

    try:
        orders = db.session.execute(
            select(Order)
            .where(Order.buyer_id == current_user.id)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.store),
                selectinload(Order.buyer),
                selectinload(Order.store),
                selectinload(Order.deliveries).selectinload(RiderDelivery.rider).selectinload(User.rider_profile),
            )
        ).scalars().all()

        return jsonify(orders=[_serialize_order(o) for o in orders]), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching orders"), 500


@orders_bp.get("/orders/<int:order_id>")
@jwt_required()
def get_order(order_id: int):
    try:
        order = db.session.execute(
            select(Order)
            .where(Order.id == order_id, Order.buyer_id == current_user.id)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.store),
                selectinload(Order.buyer),
                selectinload(Order.store),
                selectinload(Order.deliveries).selectinload(RiderDelivery.rider).selectinload(User.rider_profile),
            )
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        return jsonify(order=_serialize_order(order)), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching order"), 500


def _parse_order_item_variant(raw) -> dict | None:
    if not raw:
        return None
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        import json

        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else None
        except Exception:
            try:
                parsed = ast.literal_eval(raw)
                return parsed if isinstance(parsed, dict) else None
            except Exception:
                return None
    return None


def _restore_order_inventory(order: Order) -> None:
    """Return product and variation stock when a pending/processing order is cancelled."""
    for item in order.items:
        if item.product_id is None:
            continue

        product = item.product
        if product is None:
            product = db.session.get(Product, item.product_id)
        if product is None:
            continue

        qty = int(item.quantity or 1)
        variant_data = _parse_order_item_variant(item.variation)

        if variant_data:
            variant_size = variant_data.get("size")
            variant_color = variant_data.get("color")
            for variation in getattr(product, "variations", []):
                if variation.size == variant_size and variation.color == variant_color:
                    try:
                        previous_var_qty = int(
                            getattr(variation, "inventory", 0) or 0
                        )
                    except (TypeError, ValueError):
                        previous_var_qty = 0
                    variation.inventory = previous_var_qty + qty
                    break
        else:
            try:
                product.quantity = int(getattr(product, "quantity", 0) or 0) + qty
            except (TypeError, ValueError):
                product.quantity = qty


@orders_bp.put("/orders/<int:order_id>/cancel")
@jwt_required()
def buyer_cancel_order(order_id: int):
    """Allow the buyer to cancel their own order while it is still pending or processing."""
    try:
        order = db.session.execute(
            select(Order)
            .options(
                selectinload(Order.items)
                .selectinload(OrderItem.product)
                .selectinload(Product.variations),
                selectinload(Order.deliveries),
            )
            .where(Order.id == order_id, Order.buyer_id == current_user.id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        current_status = (
            order.status
            if isinstance(order.status, OrderStatus)
            else OrderStatus(str(order.status))
        )

        if current_status not in {OrderStatus.PENDING, OrderStatus.PROCESSING}:
            return jsonify(
                msg="Only pending or processing orders can be cancelled"
            ), 400

        if current_status != OrderStatus.CANCELLED:
            _restore_order_inventory(order)

        order.status = OrderStatus.CANCELLED
        order.updated_at = dt.datetime.utcnow()

        for delivery in getattr(order, "deliveries", []) or []:
            if delivery.status != DeliveryStatus.CANCELLED:
                delivery.status = DeliveryStatus.CANCELLED
                delivery.updated_at = dt.datetime.utcnow()

        store = db.session.execute(
            select(Store).where(Store.id == order.store_id)
        ).scalar_one_or_none()

        if order.buyer_id is not None:
            notify_buyer_order_status(
                user_id=order.buyer_id,
                order_id=order.id,
                status_label=OrderStatus.CANCELLED.value,
            )

        if store is not None and store.user_id is not None:
            create_notification(
                user_id=store.user_id,
                role="seller",
                title="Order cancelled",
                message=f"Order #{order.id} was cancelled by the buyer.",
                page="/seller",
                category="orders",
                ntype="in_app",
                data={"orderId": order.id, "status": OrderStatus.CANCELLED.value},
            )

        db.session.commit()
        return jsonify(order=_serialize_order(order)), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error cancelling order"), 500


@orders_bp.post("/orders/<int:order_id>/confirm-received")
@jwt_required()
def confirm_order_received(order_id: int):
    """Allow the buyer to confirm that an order has been received.

    This moves the order status to COMPLETED when the current user is the
    buyer for the order and the order has already been delivered or marked
    out for delivery.
    """

    try:
        order = db.session.execute(
            select(Order)
            .where(Order.id == order_id, Order.buyer_id == current_user.id)
            .options(selectinload(Order.deliveries))
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        _prepare_order_for_buyer_confirm(order)
        current_status = _current_order_status(order)

        if current_status == OrderStatus.COMPLETED:
            return jsonify(order=_serialize_order(order)), 200

        if current_status != OrderStatus.DELIVERED:
            return (
                jsonify(
                    msg=(
                        "Order is not yet eligible for completion. "
                        "Wait until delivery is marked complete or proof of delivery is uploaded."
                    )
                ),
                400,
            )

        # Settle payment while order is still DELIVERED (avoids flushing invalid status).
        if not CommissionService.settle_order_payment(order):
            return jsonify(msg="Error settling payment"), 500

        order.status = OrderStatus.COMPLETED
        order.updated_at = dt.datetime.utcnow()

        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order.id)
        ).scalar_one_or_none()

        # Notify buyer and seller that the order is completed
        create_notification(
            user_id=current_user.id,
            title="Order completed",
            message=f"Your order #{order.id} has been completed.",
            role="buyer",
            page="/orders",
        )
        create_notification(
            user_id=current_user.id,
            title="Rate your order",
            message=f"You can now leave a review for order #{order.id}.",
            role="buyer",
            page=f"/orders/{order.id}",
            category="reviews",
            ntype="in_app",
            data={"orderId": order.id},
        )
        if order.store_id is not None:
            store = db.session.execute(select(Store).where(Store.id == order.store_id)).scalar_one_or_none()
            if store is not None and store.user_id is not None:
                create_notification(
                    user_id=store.user_id,
                    title="Order completed",
                    message=f"Order #{order.id} has been completed.",
                    role="seller",
                    page="/seller",
                )

                # Notify seller about wallet payout/credit
                if payment_tx is not None and payment_tx.status == PaymentStatus.SETTLED:
                    financials = _compute_order_financials(order)
                    seller_payout = float(financials["sellerPayout"])

                    notify_seller_payout_released(
                        user_id=store.user_id,
                        order_id=order.id,
                        amount=seller_payout,
                    )

        db.session.commit()

        return jsonify(order=_serialize_order(order)), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error confirming order receipt"), 500


@orders_bp.post("/orders/<int:order_id>/refund-request")
@jwt_required()
def request_refund(order_id: int):
    """Allow the buyer to request a refund for an order.

    This now persists a RefundRequest row tied to the order/payment
    transaction and notifies the buyer. Actual settlement remains an
    admin decision.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    reason = data.get("reason")

    from app.services.punishment_service import PunishmentService, ACTION_REFUND_REQUEST

    blocked = PunishmentService.enforce(current_user.id, ACTION_REFUND_REQUEST)
    if blocked:
        return blocked

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id, Order.buyer_id == current_user.id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order.id)
        ).scalar_one_or_none()

        if payment_tx is None:
            return jsonify(msg="No payment transaction found for this order"), 400

        if payment_tx.status == PaymentStatus.REFUNDED:
            return jsonify(msg="Refund has already been processed for this order"), 400

        # Prevent duplicate open refund requests for the same order
        existing_refunds = db.session.execute(
            select(RefundRequest).where(RefundRequest.order_id == order.id)
        ).scalars().all()

        for r in existing_refunds:
            if r.status not in {RefundStatus.REJECTED, RefundStatus.REJECTED_BY_SELLER}:
                return jsonify(msg="Refund already requested for this order"), 400

        store = order.store
        seller_id = store.seller_id if store is not None else None

        refund = RefundRequest(
            order_id=order.id,
            buyer_id=current_user.id,
            seller_id=seller_id,
            payment_transaction_id=payment_tx.id,
            reason=reason,
        )
        db.session.add(refund)

        notify_buyer_refund_requested(
            user_id=current_user.id,
            order_id=order.id,
        )

        if store is not None and store.user_id is not None:
            notify_seller_refund_requested(user_id=store.user_id, order_id=order.id)

        db.session.commit()

        return jsonify(msg="Refund request submitted"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error submitting refund request"), 500


@orders_bp.get("/orders/refunds")
@jwt_required()
def list_refunds():
    """List refunded orders for the current buyer.

    This uses PaymentTransaction records with status REFUNDED joined to
    their associated orders, filtered by the current user's buyer id.
    """

    try:
        rows = db.session.execute(
            select(PaymentTransaction)
            .join(Order, PaymentTransaction.order_id == Order.id)
            .where(
                PaymentTransaction.status == PaymentStatus.REFUNDED,
                Order.buyer_id == current_user.id,
            )
        ).scalars().all()

        result: list[dict] = []
        for tx in rows:
            order = tx.order
            result.append(
                {
                    "transactionId": tx.id,
                    "orderId": order.id if order else None,
                    "amount": float(tx.amount or 0.0),
                    "status": tx.status.value if hasattr(tx.status, "value") else str(tx.status),
                    "createdAt": tx.created_at.isoformat() if getattr(tx, "created_at", None) else None,
                }
            )

        return jsonify(refunds=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching refunds"), 500


@orders_bp.get("/orders/<int:order_id>/financials")
@jwt_required()
def get_order_financials(order_id: int):
    """Return the financial breakdown for a single order.

    This exposes the same calculations used when the buyer confirms receipt,
    so admin/seller UIs can show admin commission, rider fee sharing, and
    seller payout for the order.
    """

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id, Order.buyer_id == current_user.id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        financials = CommissionService.calculate_order_financials(order)

        # Also surface the current payment transaction status when available.
        payment_tx = db.session.execute(
            select(PaymentTransaction).where(PaymentTransaction.order_id == order.id)
        ).scalar_one_or_none()

        tx_payload = None
        if payment_tx is not None:
            tx_payload = {
                "id": payment_tx.id,
                "amount": float(payment_tx.amount or 0.0),
                "platformFee": float(payment_tx.platform_fee or 0.0),
                "status": payment_tx.status.value if hasattr(payment_tx.status, "value") else str(payment_tx.status),
            }

        return jsonify(orderId=order.id, financials=financials, paymentTransaction=tx_payload), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching order financials"), 500


def _serialize_buyer_refund_request(r: RefundRequest) -> dict:
    """Serialize a refund request for the buyer UI with order and store context."""
    tx: PaymentTransaction | None = r.payment_transaction
    order: Order | None = r.order
    amount = float(tx.amount or 0.0) if tx is not None else 0.0

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
                    "imageUrl": _product_main_image_url(product),
                }
            )

    order_payload = None
    if order is not None:
        status_val = _order_status_value(order.status)
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

    store_payload = None
    store = order.store if order is not None else None
    if store is not None:
        store_payload = {
            "id": store.id,
            "name": getattr(store, "store_name", None),
        }

    evidence_paths = []
    if r.evidence_paths_json:
        try:
            import json as _json
            parsed = _json.loads(r.evidence_paths_json)
            if isinstance(parsed, list):
                evidence_paths = parsed
        except Exception:
            pass

    timeline = [
        {"event": "requested", "at": r.created_at.isoformat() if r.created_at else None},
    ]
    if r.updated_at and r.status != RefundStatus.REQUESTED:
        timeline.append(
            {
                "event": r.status.value if hasattr(r.status, "value") else str(r.status),
                "at": r.updated_at.isoformat() if r.updated_at else None,
            }
        )
    if r.disputed_at:
        timeline.append({"event": "disputed", "at": r.disputed_at.isoformat()})
    if r.evidence_requested_at:
        timeline.append({"event": "evidence_requested", "at": r.evidence_requested_at.isoformat()})

    return {
        "id": r.id,
        "transactionId": tx.id if tx is not None else None,
        "orderId": order.id if order is not None else None,
        "amount": amount,
        "reason": r.reason,
        "status": r.status.value if isinstance(r.status, RefundStatus) else str(r.status),
        "createdAt": r.created_at.isoformat() if r.created_at else None,
        "updatedAt": r.updated_at.isoformat() if r.updated_at else None,
        "paymentStatus": payment_status,
        "store": store_payload,
        "order": order_payload,
        "buyerEvidenceNote": r.buyer_evidence_note,
        "sellerResponseNote": r.seller_response_note,
        "adminNote": r.admin_note,
        "evidencePaths": evidence_paths,
        "disputedAt": r.disputed_at.isoformat() if r.disputed_at else None,
        "isTransactionFrozen": bool(r.is_transaction_frozen),
        "canDispute": (
            r.status == RefundStatus.REJECTED_BY_SELLER if hasattr(r, "status") else False
        ),
        "timeline": timeline,
    }


@orders_bp.get("/buyer/refund-requests")
@jwt_required()
def list_buyer_refund_requests():
    """List refund requests created by the current buyer.

    This reflects the RefundRequest domain model and surfaces status
    across the buyer UI, separate from the final refunded transactions
    exposed via /orders/refunds.
    """

    try:
        refunds = db.session.execute(
            select(RefundRequest)
            .where(RefundRequest.buyer_id == current_user.id)
            .options(
                selectinload(RefundRequest.payment_transaction),
                selectinload(RefundRequest.order)
                .selectinload(Order.items)
                .selectinload(OrderItem.product),
                selectinload(RefundRequest.order).selectinload(Order.store),
            )
            .order_by(RefundRequest.created_at.desc())
        ).scalars().all()

        result = [_serialize_buyer_refund_request(r) for r in refunds]

        return jsonify(refunds=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching refund requests"), 500


@orders_bp.post("/buyer/refund-requests/<int:refund_id>/dispute")
@jwt_required()
def dispute_refund_request(refund_id: int):
    """Buyer escalates a seller-rejected refund to admin review."""

    data = request.get_json(silent=True) or {}
    note = (data.get("note") or data.get("reason") or "").strip() or None
    evidence_paths = data.get("evidencePaths")

    try:
        from app.services.refund_service import RefundService

        refund, err = RefundService.dispute_refund(
            refund_id,
            current_user.id,
            note=note,
            evidence_paths=evidence_paths if isinstance(evidence_paths, list) else None,
        )
        if err:
            return jsonify(msg=err), 400

        db.session.commit()
        return jsonify(
            msg="Dispute submitted. An admin will review your case.",
            refund=_serialize_buyer_refund_request(refund),
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error submitting dispute"), 500


@orders_bp.post("/orders/<int:order_id>/reviews")
@jwt_required()
def add_order_item_review(order_id: int):
    """Create a review for a single order item on a completed order."""

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    order_item_id = data.get("orderItemId")

    from app.services.punishment_service import PunishmentService, ACTION_REVIEW_POST

    blocked = PunishmentService.enforce(current_user.id, ACTION_REVIEW_POST)
    if blocked:
        return blocked

    try:
        order = db.session.execute(
            select(Order).where(
                Order.id == order_id,
                Order.buyer_id == current_user.id,
                Order.status == OrderStatus.COMPLETED,
            )
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Completed order not found"), 404

        if order_item_id is None:
            return jsonify(msg="Missing orderItemId"), 400

        order_item = db.session.execute(
            select(OrderItem).where(
                OrderItem.id == int(order_item_id),
                OrderItem.order_id == order.id,
            )
        ).scalar_one_or_none()

        if order_item is None:
            return jsonify(msg="Order item not found"), 404

        if order_item.product_id is None:
            return jsonify(msg="Product not found for order item"), 404

        from app.review_utils import (
            review_format_for_product,
            validate_review_payload,
            recompute_product_review_stats,
            DELIVERY_PILL_OPTIONS,
        )

        expected_format = review_format_for_product(order_item.product_id, db.session)
        submitted_format = data.get("reviewFormat") or expected_format
        if submitted_format != expected_format:
            return jsonify(msg="Invalid review format for this product"), 400

        normalized, err = validate_review_payload(data, expected_format)
        if err:
            return jsonify(msg=err), 400

        existing = db.session.execute(
            select(Review).where(Review.order_item_id == order_item.id)
        ).scalar_one_or_none()

        if existing is not None:
            return jsonify(msg="You have already reviewed this item"), 400

        import json as json_mod

        review = Review(
            order_item_id=order_item.id,
            buyer_id=current_user.id,
            product_id=order_item.product_id,
            rating=normalized["rating"],
            review_format=normalized["review_format"],
            ratings_json=json_mod.dumps(normalized["ratings"]),
            delivery_satisfaction=normalized["delivery_satisfaction"],
            delivery_pills_json=json_mod.dumps(normalized["delivery_pills"]),
            comment=normalized["comment"],
        )

        db.session.add(review)
        db.session.flush()

        recompute_product_review_stats(order_item.product_id, db.session)

        if order.store_id is not None:
            store = db.session.execute(
                select(Store).where(Store.id == order.store_id)
            ).scalar_one_or_none()
            if store is not None and store.user_id is not None:
                product = db.session.execute(
                    select(Product).where(Product.id == order_item.product_id)
                ).scalar_one_or_none()
                pname = product.name if product else "your product"
                create_notification(
                    user_id=store.user_id,
                    title="New customer review",
                    message=f"You received a new review on {pname}.",
                    role="seller",
                    page="/seller/feedback",
                    category="reviews",
                    ntype="in_app",
                    data={"reviewId": review.id, "productId": order_item.product_id},
                )

        db.session.commit()

        return jsonify(msg="Review submitted", reviewId=review.id), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error submitting review"), 500


@orders_bp.get("/orders/<int:order_id>/reviews")
@jwt_required()
def get_order_reviews(order_id: int):
    """Return reviews for an order belonging to the current buyer."""

    try:
        from app.review_utils import (
            serialize_review_row,
            review_format_for_product,
            DELIVERY_PILL_OPTIONS,
        )

        order = db.session.execute(
            select(Order).where(
                Order.id == order_id,
                Order.buyer_id == current_user.id,
            )
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        rows = db.session.execute(
            select(Review, Product, OrderItem)
            .outerjoin(Product, Review.product_id == Product.id)
            .join(OrderItem, Review.order_item_id == OrderItem.id)
            .where(OrderItem.order_id == order.id)
        ).all()

        result = [
            serialize_review_row(review, _public_image_url, product, None, order_item)
            for review, product, order_item in rows
        ]

        reviewed_item_ids = {r["orderItemId"] for r in result if r.get("orderItemId")}
        reviewable_items = []
        if order.status == OrderStatus.COMPLETED:
            items = db.session.execute(
                select(OrderItem, Product)
                .outerjoin(Product, OrderItem.product_id == Product.id)
                .where(OrderItem.order_id == order.id)
            ).all()
            for oi, product in items:
                if oi.id in reviewed_item_ids or oi.product_id is None:
                    continue
                reviewable_items.append(
                    {
                        "orderItemId": oi.id,
                        "productId": oi.product_id,
                        "productName": product.name if product else None,
                        "variant": _parse_order_item_variant(oi.variation),
                        "unitPrice": oi.unit_price,
                        "quantity": oi.quantity,
                        "reviewFormat": review_format_for_product(oi.product_id, db.session),
                    }
                )

        return jsonify(
            reviews=result,
            reviewableItems=reviewable_items,
            deliveryPillOptions=DELIVERY_PILL_OPTIONS,
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching reviews"), 500


@orders_bp.get("/products/<int:product_id>/reviews")
@jwt_required(optional=True)
def get_product_reviews(product_id: int):
    """Return public reviews for a given product."""

    try:
        from app.review_utils import (
            public_review_filter,
            serialize_review_row,
            compute_dimension_averages,
            compute_rating_breakdown,
        )

        rows = db.session.execute(
            select(Review, Product, User, OrderItem)
            .join(Product, Review.product_id == Product.id)
            .outerjoin(User, Review.buyer_id == User.id)
            .outerjoin(OrderItem, Review.order_item_id == OrderItem.id)
            .where(Review.product_id == product_id, *public_review_filter())
            .order_by(Review.created_at.desc())
        ).all()

        reviews_list = db.session.execute(
            select(Review).where(Review.product_id == product_id, *public_review_filter())
        ).scalars().all()

        result = [
            serialize_review_row(review, _public_image_url, product, buyer, order_item)
            for review, product, buyer, order_item in rows
        ]

        return jsonify(
            reviews=result,
            dimensionAverages=compute_dimension_averages(reviews_list),
            ratingBreakdown=compute_rating_breakdown(reviews_list),
        ), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching product reviews"), 500


@orders_bp.get("/seller/<int:seller_id>/orders")
@jwt_required()
def list_seller_orders(seller_id: int):
    """List orders for a given seller's store.

    This is intended for seller views; we verify that the seller_id in the
    URL maps to a Store whose user_id matches the current_user, then return
    all orders whose store_id matches that store.
    """

    try:
        # Find the store for this seller
        store = db.session.execute(
            select(Store).where(Store.seller_id == seller_id)
        ).scalar_one_or_none()

        if store is None:
            return jsonify(orders=[]), 200

        # Ensure the current user actually owns this store
        if store.user_id != current_user.id:
            return jsonify(msg="Unauthorized request!"), 403

        orders = db.session.execute(
            select(Order).where(Order.store_id == store.id)
        ).scalars().all()

        return jsonify(orders=[_serialize_order(o) for o in orders]), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching seller orders"), 500


@orders_bp.put("/orders/<int:order_id>/status")
@jwt_required()
def update_order_status(order_id: int):
    """Update the status of an order.

    This endpoint is primarily intended for sellers managing their own store's
    orders. We ensure that the current user owns the store associated with the
    order before allowing the status change.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    new_status = data.get("status")
    if not new_status:
        return jsonify(msg="Missing status"), 400

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        # Ensure the current user owns the store for this order
        store = db.session.execute(
            select(Store).where(Store.id == order.store_id)
        ).scalar_one_or_none()

        if store is None or store.user_id != current_user.id:
            return jsonify(msg="Unauthorized request!"), 403

        try:
            status_enum = OrderStatus[new_status.upper()]
        except KeyError:
            return jsonify(msg="Invalid status"), 400

        # Enforce seller-facing transition rules so sellers cannot mark
        # orders delivered (that is handled by riders / delivery flow).
        current_status = order.status if isinstance(order.status, OrderStatus) else OrderStatus(str(order.status))

        allowed_transitions: dict[OrderStatus, set[OrderStatus]] = {
            OrderStatus.PENDING: {OrderStatus.PROCESSING, OrderStatus.CANCELLED},
            OrderStatus.PROCESSING: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
            OrderStatus.SHIPPED: set(),
            OrderStatus.OUT_FOR_DELIVERY: set(),
            OrderStatus.DELIVERED: set(),
            OrderStatus.RETURNED: set(),
            OrderStatus.CONFIRMED: set(),
            OrderStatus.COMPLETED: set(),
        }

        allowed_targets = allowed_transitions.get(current_status, set())
        if status_enum not in allowed_targets:
            return jsonify(msg="Status transition not allowed for seller"), 400

        order.status = status_enum
        order.updated_at = dt.datetime.utcnow()

        # Notify buyer about status change
        if order.buyer_id is not None:
            notify_buyer_order_status(
                user_id=order.buyer_id,
                order_id=order.id,
                status_label=status_enum.value,
            )

        db.session.commit()

        return jsonify(order=_serialize_order(order)), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error updating order status"), 500


@orders_bp.post("/orders/<int:order_id>/assign-rider")
@jwt_required()
def assign_rider(order_id: int):
    """Assign a rider to an order and create a RiderDelivery record.

    This endpoint is intended for the seller who owns the store for the order
    (or a future logistics role). For now we ensure the current user owns the
    store.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    rider_id = data.get("riderId")
    fee = data.get("fee", 0.0)
    distance_km = data.get("distanceKm")

    try:
        order = db.session.execute(
            select(Order).where(Order.id == order_id)
        ).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        store = db.session.execute(
            select(Store).where(Store.id == order.store_id)
        ).scalar_one_or_none()

        if store is None or store.user_id != current_user.id:
            return jsonify(msg="Unauthorized request!"), 403

        if rider_id is None:
            return jsonify(msg="Missing riderId"), 400

        rider = db.session.execute(
            select(User).where(User.id == int(rider_id))
        ).scalar_one_or_none()

        if rider is None:
            return jsonify(msg="Rider not found"), 404

        delivery = RiderDelivery(
            rider_id=rider.id,
            order_id=order.id,
            status=DeliveryStatus.PENDING,
            fee=float(fee or 0.0),
            distance_km=float(distance_km) if distance_km is not None else None,
        )

        db.session.add(delivery)

        # Notify rider about the new delivery assignment
        notify_rider_new_delivery_assignment(user_id=rider.id, order_id=order.id)

        db.session.commit()

        return jsonify(delivery=_serialize_rider_delivery(delivery)), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error assigning rider"), 500


@orders_bp.post("/rider/orders/<int:order_id>/accept")
@jwt_required()
def rider_accept_order(order_id: int):
    """Allow the current rider to accept an available (auto-matched) order.

    This creates a RiderDelivery row bound to the current rider so that the
    order no longer appears as an available delivery to other riders in the
    same municipality. The order must currently be in status SHIPPED or
    OUT_FOR_DELIVERY and must match the rider's municipality.
    """

    try:
        from app.services.punishment_service import PunishmentService, ACTION_DELIVERY_ASSIGNMENT

        blocked = PunishmentService.enforce(current_user.id, ACTION_DELIVERY_ASSIGNMENT)
        if blocked:
            return blocked

        # Require verified/approved rider account
        if not getattr(current_user, "email_verified", False):
            return jsonify(msg="Rider account is not yet verified/approved"), 403

        rider_profile = getattr(current_user, "rider_profile", None)
        rider_municipality = getattr(rider_profile, "municipality_name", None) if rider_profile else None

        if not rider_municipality:
            return jsonify(msg="Rider municipality not set"), 400

        order = db.session.execute(select(Order).where(Order.id == order_id)).scalar_one_or_none()

        if order is None:
            return jsonify(msg="Order not found"), 404

        if order.status not in {OrderStatus.SHIPPED, OrderStatus.OUT_FOR_DELIVERY}:
            return jsonify(msg="Order is not available for rider acceptance"), 400

        buyer = order.buyer
        if buyer is None:
            return jsonify(msg="Order buyer not found"), 400

        buyer_profile = db.session.execute(
            select(BuyerProfile).where(BuyerProfile.user_id == buyer.id)
        ).scalar_one_or_none()

        if buyer_profile is None or buyer_profile.municipality_name != rider_municipality:
            return jsonify(msg="Order is not in the rider's area"), 403

        # Ensure this order is not already assigned to a rider
        existing_delivery = db.session.execute(
            select(RiderDelivery).where(RiderDelivery.order_id == order.id)
        ).scalar_one_or_none()

        if existing_delivery is not None:
            return jsonify(msg="Order is already assigned to a rider"), 400

        delivery = RiderDelivery(
            rider_id=current_user.id,
            order_id=order.id,
            status=DeliveryStatus.PENDING,
            fee=float(order.total_amount or 0.0),
            distance_km=None,
        )

        db.session.add(delivery)
        db.session.commit()

        return jsonify(delivery=_serialize_rider_delivery(delivery)), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error accepting rider delivery"), 500


@orders_bp.put("/rider/deliveries/<int:delivery_id>/status")
@jwt_required()
def update_rider_delivery_status(delivery_id: int):
    """Allow a rider to update the status of an assigned delivery.

    When the rider marks the delivery as PICKUP or TRANSIT, the related
    order status is moved to OUT_FOR_DELIVERY. When marked DELIVERED, the
    order status is moved to DELIVERED.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    new_status = data.get("status")
    if not new_status:
        return jsonify(msg="Missing status"), 400

    try:
        # Require verified/approved rider account
        if not getattr(current_user, "email_verified", False):
            return jsonify(msg="Rider account is not yet verified/approved"), 403

        delivery = db.session.execute(
            select(RiderDelivery).where(RiderDelivery.id == delivery_id)
        ).scalar_one_or_none()

        if delivery is None:
            return jsonify(msg="Delivery not found"), 404

        if delivery.rider_id != current_user.id:
            return jsonify(msg="Unauthorized request!"), 403

        try:
            status_enum = DeliveryStatus[new_status.upper()]
        except KeyError:
            return jsonify(msg="Invalid status"), 400

        # Enforce simple state machine: PENDING -> PICKUP -> TRANSIT -> DELIVERED
        current_status = (
            delivery.status
            if isinstance(delivery.status, DeliveryStatus)
            else DeliveryStatus(str(delivery.status))
        )

        allowed_transitions: dict[DeliveryStatus, set[DeliveryStatus]] = {
            DeliveryStatus.PENDING: {DeliveryStatus.PICKUP},
            DeliveryStatus.PICKUP: {DeliveryStatus.TRANSIT},
            DeliveryStatus.TRANSIT: {DeliveryStatus.DELIVERED},
            DeliveryStatus.DELIVERED: set(),
        }

        if status_enum not in allowed_transitions.get(current_status, set()):
            return (
                jsonify(
                    msg=f"Invalid status transition from {current_status.value} to {status_enum.value}"
                ),
                400,
            )

        if status_enum == DeliveryStatus.DELIVERED and not delivery.proof_photo_path:
            return (
                jsonify(
                    msg="Upload proof of delivery before marking this delivery as delivered"
                ),
                400,
            )

        delivery.status = status_enum
        delivery.updated_at = dt.datetime.utcnow()

        # Propagate to order status where appropriate and notify buyer/seller
        order = delivery.order
        if order is not None:
            if status_enum in {DeliveryStatus.PICKUP, DeliveryStatus.TRANSIT}:
                order.status = OrderStatus.OUT_FOR_DELIVERY
                order.updated_at = dt.datetime.utcnow()
                if order.buyer_id is not None:
                    create_notification(
                        user_id=order.buyer_id,
                        title="Order out for delivery",
                        message=f"Your order #{order.id} is now out for delivery.",
                        role="buyer",
                        page="/orders",
                    )
                if order.store_id is not None:
                    store = db.session.execute(select(Store).where(Store.id == order.store_id)).scalar_one_or_none()
                    if store is not None and store.user_id is not None:
                        create_notification(
                            user_id=store.user_id,
                            title="Rider assigned",
                            message=f"A rider has been assigned and order #{order.id} is out for delivery.",
                            role="seller",
                            page="/seller",
                        )
            elif status_enum == DeliveryStatus.DELIVERED:
                order.status = OrderStatus.DELIVERED
                order.updated_at = dt.datetime.utcnow()
                if order.buyer_id is not None:
                    create_notification(
                        user_id=order.buyer_id,
                        title="Order delivered",
                        message=f"Your order #{order.id} has been delivered.",
                        role="buyer",
                        page="/orders",
                    )
                if order.store_id is not None:
                    store = db.session.execute(select(Store).where(Store.id == order.store_id)).scalar_one_or_none()
                    if store is not None and store.user_id is not None:
                        create_notification(
                            user_id=store.user_id,
                            title="Order delivered",
                            message=f"Order #{order.id} has been delivered to the buyer.",
                            role="seller",
                            page="/seller",
                        )

        db.session.commit()

        return jsonify(delivery=_serialize_rider_delivery(delivery)), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error updating rider delivery status"), 500


@orders_bp.get("/rider/deliveries")
@jwt_required()
def list_rider_deliveries():
    """List deliveries relevant to the current rider.

    This includes:
    - Deliveries explicitly assigned to the rider (RiderDelivery rows)
    - Orders in the rider's municipality with status SHIPPED or OUT_FOR_DELIVERY,
      exposed as "available" deliveries for all riders in that area.
    """

    try:
        # Require verified/approved rider account
        if not getattr(current_user, "email_verified", False):
            return jsonify(msg="Rider account is not yet verified/approved"), 403

        # 1) Deliveries explicitly assigned to this rider
        assigned_deliveries = db.session.execute(
            select(RiderDelivery).where(RiderDelivery.rider_id == current_user.id)
        ).scalars().all()

        payload: list[dict] = [_serialize_rider_delivery(d) for d in assigned_deliveries]

        # 2) Orders in the rider's municipality with status SHIPPED or OUT_FOR_DELIVERY
        rider_profile = getattr(current_user, "rider_profile", None)
        rider_municipality = getattr(rider_profile, "municipality_name", None) if rider_profile else None

        if rider_municipality:
            # Only include orders that do not yet have a RiderDelivery, so once
            # a rider accepts an order it no longer appears as an
            # auto-matched option for others.
            available_orders = db.session.execute(
                select(Order)
                .join(User, Order.buyer_id == User.id)
                .join(BuyerProfile, BuyerProfile.user_id == User.id)
                .where(
                    BuyerProfile.municipality_name == rider_municipality,
                    Order.status.in_([OrderStatus.SHIPPED, OrderStatus.OUT_FOR_DELIVERY]),
                    ~exists(
                        select(RiderDelivery.id).where(RiderDelivery.order_id == Order.id)
                    ),
                )
            ).scalars().all()

            for order in available_orders:
                payload.append(_serialize_available_order_for_rider(order))

        return jsonify(deliveries=payload), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching rider deliveries"), 500


@orders_bp.post("/rider/deliveries/<int:delivery_id>/proof")
@jwt_required()
def upload_rider_delivery_proof(delivery_id: int):
    """Upload proof of delivery (photo required, note optional) for a rider delivery.

    This associates an uploaded image with the delivery by saving it under the
    app's static folder (rider_docs). For now, the file path is not persisted
    on the RiderDelivery row, but the backend at least validates ownership and
    stores the asset on disk.
    """

    try:
        # Require verified/approved rider account
        if not getattr(current_user, "email_verified", False):
            return jsonify(msg="Rider account is not yet verified/approved"), 403

        delivery = db.session.execute(
            select(RiderDelivery).where(RiderDelivery.id == delivery_id)
        ).scalar_one_or_none()

        if delivery is None:
            return jsonify(msg="Delivery not found"), 404

        if delivery.rider_id != current_user.id:
            return jsonify(msg="Unauthorized request!"), 403

        # Expect multipart/form-data with a required 'photo' field
        if "photo" not in request.files:
            return jsonify(msg="Photo is required as proof of delivery"), 400

        photo = request.files["photo"]
        if photo.filename == "":
            return jsonify(msg="Photo is required as proof of delivery"), 400

        note = request.form.get("note")

        # Save file under static/rider_docs with a safe filename
        static_root = current_app.static_folder or os.path.join(current_app.root_path, "static")
        upload_dir = os.path.join(static_root, "rider_docs")
        os.makedirs(upload_dir, exist_ok=True)

        filename = secure_filename(photo.filename)
        # Prefix with delivery id and timestamp to avoid clashes
        timestamp = dt.datetime.utcnow().strftime("%Y%m%d%H%M%S")
        stored_name = f"delivery_{delivery_id}_{timestamp}_{filename}"
        file_path = os.path.join(upload_dir, stored_name)
        photo.save(file_path)

        # Persist relative path and note on RiderDelivery so it can be surfaced in UIs.
        # Store path relative to the static root so _public_image_url can resolve it.
        delivery.proof_photo_path = f"rider_docs/{stored_name}"
        if note:
            delivery.proof_note = note

        # When proof is uploaded in transit, complete delivery and update the order.
        current_delivery_status = (
            delivery.status
            if isinstance(delivery.status, DeliveryStatus)
            else DeliveryStatus(str(delivery.status))
        )
        if current_delivery_status == DeliveryStatus.TRANSIT:
            delivery.status = DeliveryStatus.DELIVERED
            delivery.updated_at = dt.datetime.utcnow()
            order = delivery.order
            if order is not None:
                order.status = OrderStatus.DELIVERED
                order.updated_at = dt.datetime.utcnow()
                if order.buyer_id is not None:
                    create_notification(
                        user_id=order.buyer_id,
                        title="Order delivered",
                        message=f"Your order #{order.id} has been delivered.",
                        role="buyer",
                        page="/orders",
                    )
                if order.store_id is not None:
                    store = db.session.execute(
                        select(Store).where(Store.id == order.store_id)
                    ).scalar_one_or_none()
                    if store is not None and store.user_id is not None:
                        create_notification(
                            user_id=store.user_id,
                            title="Order delivered",
                            message=f"Order #{order.id} has been delivered to the buyer.",
                            role="seller",
                            page="/seller",
                        )

        db.session.commit()

        return jsonify(msg="Proof of delivery uploaded"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error uploading proof of delivery"), 500


@orders_bp.get("/rider/dashboard")
@jwt_required()
def rider_dashboard():
    """Return simple dashboard stats for the current rider.

    Aggregates counts and earnings from RiderDelivery records.
    """

    try:
        deliveries = db.session.execute(
            select(RiderDelivery).where(RiderDelivery.rider_id == current_user.id)
        ).scalars().all()

        today = dt.date.today()

        total_today = 0
        completed = 0
        pending = 0
        earnings = 0.0
        lifetime_earnings = 0.0

        for d in deliveries:
            status_value = d.status.value if isinstance(d.status, DeliveryStatus) else str(d.status)
            fee = float(d.fee or 0.0)

            if d.created_at and d.created_at.date() == today:
                total_today += 1

            if status_value == DeliveryStatus.DELIVERED.value:
                completed += 1
                lifetime_earnings += fee
                if d.created_at and d.created_at.date() == today:
                    earnings += fee
            elif status_value in {DeliveryStatus.PENDING.value, DeliveryStatus.PICKUP.value, DeliveryStatus.TRANSIT.value}:
                pending += 1

        stats = {
            "todayDeliveries": total_today,
            "completed": completed,
            "pending": pending,
            "earnings": earnings,
            "lifetimeEarnings": lifetime_earnings,
        }

        return jsonify(stats=stats), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching rider dashboard"), 500
