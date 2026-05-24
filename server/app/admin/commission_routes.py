"""Admin commission and shipping settings routes."""

from flask import Blueprint, jsonify, request, abort
from flask_jwt_extended import jwt_required, current_user
from sqlalchemy import select, func
from app.models import (
    db,
    CommissionSettings,
    OrderStatus,
    ShippingSettings,
    Store,
    Order,
    OrderItem,
    RiderEarnings,
    PaymentTransaction,
    PaymentStatus,
    User,
    UserRole,
    Role,
    Category,
    Product,
    ProductCategory
)
from app.services.commission_service import CommissionService
from app.decorators import admin_required

commission_bp = Blueprint('commission', __name__)


@commission_bp.get("/settings")
@jwt_required()
@admin_required()
def get_commission_settings():
    """Get current commission settings."""
    try:
        settings = db.session.execute(
            select(CommissionSettings)
            .where(CommissionSettings.is_active == True)
            .order_by(CommissionSettings.created_at.desc())
        ).scalar_one_or_none()
        
        if not settings:
            # Create default settings if none exist
            settings = CommissionSettings(
                commission_rate=0.10,
                applies_to_product_price_only=True,
                is_active=True
            )
            db.session.add(settings)
            db.session.commit()
        
        return jsonify(settings=settings.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching commission settings"), 500


@commission_bp.post("/settings")
@jwt_required()
@admin_required()
def update_commission_settings():
    """Update commission settings."""
    if not request.is_json:
        abort(400)
    
    data = request.get_json()
    commission_rate = data.get("commissionRate", 0.10)
    applies_to_product_price_only = data.get("appliesToProductPriceOnly", True)
    
    try:
        # Deactivate existing settings
        db.session.execute(
            select(CommissionSettings)
            .where(CommissionSettings.is_active == True)
        ).scalar_one_or_none()
        
        existing = db.session.execute(
            select(CommissionSettings)
            .where(CommissionSettings.is_active == True)
        ).scalar_one_or_none()
        
        if existing:
            existing.is_active = False
        
        # Create new settings
        new_settings = CommissionSettings(
            commission_rate=float(commission_rate),
            applies_to_product_price_only=bool(applies_to_product_price_only),
            is_active=True
        )
        db.session.add(new_settings)
        db.session.commit()
        
        return jsonify(settings=new_settings.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error updating commission settings"), 500


@commission_bp.get("/shipping-settings")
@jwt_required()
@admin_required()
def get_shipping_settings():
    """Get all shipping settings."""
    try:
        settings = db.session.execute(
            select(ShippingSettings)
            .where(ShippingSettings.is_active == True)
            .order_by(ShippingSettings.region_name, ShippingSettings.province_name, ShippingSettings.city_name)
        ).scalars().all()
        
        return jsonify(settings=[s.to_json() for s in settings]), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching shipping settings"), 500


@commission_bp.post("/shipping-settings")
@jwt_required()
@admin_required()
def create_shipping_setting():
    """Create or update shipping setting for a location."""
    if not request.is_json:
        abort(400)
    
    data = request.get_json()
    region_name = data.get("regionName")
    province_name = data.get("provinceName")
    city_name = data.get("cityName")
    shipping_fee = data.get("shippingFee", 0.0)
    store_id = data.get("storeId")
    
    if not region_name:
        return jsonify(msg="Region name is required"), 400

    if not store_id:
        return jsonify(
            msg="storeId is required. Shipping rates are configured per store (seller settings).",
        ), 400
    
    try:
        # Check if setting already exists
        existing = None
        if store_id:
            existing = db.session.execute(
                select(ShippingSettings)
                .where(
                    ShippingSettings.store_id == store_id,
                    ShippingSettings.region_name == region_name,
                    ShippingSettings.province_name == province_name,
                    ShippingSettings.city_name == city_name
                )
            ).scalar_one_or_none()
        
        if existing:
            existing.shipping_fee = float(shipping_fee)
            existing.is_active = True
            setting = existing
        else:
            setting = ShippingSettings(
                region_name=region_name,
                province_name=province_name or "",
                city_name=city_name or "",
                shipping_fee=float(shipping_fee),
                store_id=store_id,
                is_active=True
            )
            db.session.add(setting)
        
        db.session.commit()
        return jsonify(setting=setting.to_json()), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error creating shipping setting"), 500


@commission_bp.get("/analytics")
@jwt_required()
@admin_required()
def get_commission_analytics():
    """Commission-focused metrics for the admin commission settings page."""
    try:
        active_settings = db.session.execute(
            select(CommissionSettings)
            .where(CommissionSettings.is_active.is_(True))
            .order_by(CommissionSettings.created_at.desc())
        ).scalar_one_or_none()
        commission_rate = float(active_settings.commission_rate) if active_settings else 0.10

        total_orders = db.session.execute(
            select(Order).where(Order.admin_commission > 0)
        ).scalars().all()

        total_commission = sum(float(order.admin_commission or 0) for order in total_orders)

        rider_earnings = db.session.execute(select(RiderEarnings)).scalars().all()
        total_admin_from_shipping = sum(float(e.admin_earnings or 0) for e in rider_earnings)

        commission_breakdown = {
            "fromProducts": total_commission,
            "fromShipping": total_admin_from_shipping,
            "total": total_commission + total_admin_from_shipping,
            "rate": commission_rate,
        }

        order_stats: dict[str, int] = {}
        status_enum_map = {
            'pending': OrderStatus.PENDING,
            'confirmed': OrderStatus.CONFIRMED,
            'processing': OrderStatus.PROCESSING,
            'shipped': OrderStatus.SHIPPED,
            'delivered': OrderStatus.DELIVERED,
            'completed': OrderStatus.COMPLETED,
            'cancelled': OrderStatus.CANCELLED,
        }
        for label, enum_val in status_enum_map.items():
            order_stats[label] = int(
                db.session.scalar(
                    select(func.count()).select_from(Order).where(Order.status == enum_val)
                )
                or 0
            )

        return jsonify({
            "totalCommissionEarned": total_commission,
            "totalAdminRevenueFromShipping": total_admin_from_shipping,
            "commissionBreakdown": commission_breakdown,
            "orderStats": order_stats,
            "totalOrdersWithCommission": len(total_orders),
        }), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error fetching analytics: {e}")
        return jsonify(msg="Error fetching analytics"), 500


@commission_bp.get("/rider-earnings")
@jwt_required()
@admin_required()
def get_rider_earnings():
    """Get all rider earnings records."""
    try:
        earnings = db.session.execute(
            select(RiderEarnings)
            .order_by(RiderEarnings.created_at.desc())
        ).scalars().all()
        
        result = []
        for earning in earnings:
            rider = db.session.execute(
                select(User).where(User.id == earning.rider_id)
            ).scalar_one_or_none()
            
            delivery = earning.delivery
            order = delivery.order if delivery else None
            
            result.append({
                **earning.to_json(),
                "riderName": rider.username if rider else "Unknown",
                "orderId": order.id if order else None,
                "orderStatus": order.status.value if order and hasattr(order.status, 'value') else str(order.status) if order else None
            })
        
        return jsonify(earnings=result), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error fetching rider earnings"), 500


@commission_bp.post("/rider-earnings/<int:earning_id>/pay")
@jwt_required()
@admin_required()
def pay_rider_earnings(earning_id: int):
    """Mark rider earnings as paid."""
    try:
        earning = db.session.execute(
            select(RiderEarnings).where(RiderEarnings.id == earning_id)
        ).scalar_one_or_none()
        
        if not earning:
            return jsonify(msg="Earnings record not found"), 404
        
        if earning.is_paid:
            return jsonify(msg="Earnings already paid"), 400
        
        earning.is_paid = True
        earning.paid_at = db.func.now()
        db.session.commit()
        
        return jsonify(earning=earning.to_json()), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error marking earnings as paid"), 500


@commission_bp.get("/calculate-shipping")
@jwt_required()
@admin_required()
def calculate_shipping():
    """Calculate shipping fee for a given address."""
    if not request.is_json:
        abort(400)
    
    data = request.get_json()
    address = data.get("address", "")
    store_id = data.get("storeId")
    
    try:
        region_name = CommissionService.get_region_from_address(address)
        shipping_fee = CommissionService.calculate_shipping_fee(
            region_name=region_name,
            store_id=store_id
        )
        
        return jsonify({
            "region": region_name,
            "shippingFee": shipping_fee
        }), 200
    except Exception:
        return jsonify(msg="Error calculating shipping fee"), 500
