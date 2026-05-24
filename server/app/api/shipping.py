"""Shipping API endpoints for real-world distance-based shipping"""

from flask import Blueprint, request, jsonify
from app.services.shipping_service import ShippingService
from flask_jwt_extended import jwt_required

shipping_bp = Blueprint('shipping', __name__)


@shipping_bp.route('/shipping/calculate', methods=['GET', 'POST', 'OPTIONS'])
def calculate_shipping():
    """
    Calculate shipping fee based on location codes (PSGC format) or names.
    
    Preferred: Use location codes for accurate comparison
    Fallback: Use location names if codes not available
    
    Request parameters (GET query or POST JSON):
    {
        "shop_id": int (required),
        "order_total": float (optional),
        
        // Preferred: Code-based (PSGC format)
        "buyer_region_code": str,
        "buyer_province_code": str,
        "buyer_municipality_code": str,
        
        // Fallback: Name-based
        "buyer_region": str,
        "buyer_province": str,
        "buyer_municipality": str
    }
    
    Response:
    {
        "shipping_fee": float,
        "free_shipping": bool,
        "note": str or None,
        "error": str or None
    }
    """
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return '', 200
    
    # Require JWT for POST (stateful/client-side sensitive) but allow GET for public lookups
    if request.method == 'POST':
        try:
            from flask_jwt_extended import verify_jwt_in_request
            verify_jwt_in_request()
        except Exception:
            return jsonify({'error': 'Authorization required'}), 401
    
    try:
        # Support GET query params or JSON body for POST
        if request.method == 'GET':
            shop_id = request.args.get('shop_id')
            order_total = request.args.get('order_total', 0.0)
            
            # Code-based parameters (preferred)
            buyer_region_code = request.args.get('buyer_region_code')
            buyer_province_code = request.args.get('buyer_province_code')
            buyer_municipality_code = request.args.get('buyer_municipality_code')
            
            # Name-based parameters (fallback)
            buyer_region = request.args.get('buyer_region')
            buyer_province = request.args.get('buyer_province')
            buyer_municipality = request.args.get('buyer_municipality')
        else:
            data = request.get_json() or {}
            shop_id = data.get('shop_id')
            order_total = data.get('order_total', 0.0)
            
            # Code-based parameters (preferred)
            buyer_region_code = data.get('buyer_region_code')
            buyer_province_code = data.get('buyer_province_code')
            buyer_municipality_code = data.get('buyer_municipality_code')
            
            # Name-based parameters (fallback)
            buyer_region = data.get('buyer_region')
            buyer_province = data.get('buyer_province')
            buyer_municipality = data.get('buyer_municipality')

        # Validate required fields
        if shop_id is None:
            return jsonify({'error': 'Missing required field: shop_id'}), 400

        # Check if we have either codes or names
        has_codes = buyer_region_code and buyer_municipality_code
        has_names = buyer_region and buyer_municipality
        
        if not has_codes and not has_names:
            return jsonify({
                'error': 'Missing required location fields. Provide either: (buyer_region_code, buyer_municipality_code) or (buyer_region, buyer_municipality)'
            }), 400

        try:
            shop_id = int(shop_id)
            order_total = float(order_total)
        except (ValueError, TypeError):
            return jsonify({'error': 'Invalid data types for shop_id or order_total'}), 400

        # Calculate shipping using codes if available, otherwise names
        result = ShippingService.calculate_shipping_fee(
            shop_id, 
            order_total=order_total,
            buyer_region=buyer_region,
            buyer_province=buyer_province,
            buyer_municipality=buyer_municipality,
            buyer_region_code=buyer_region_code,
            buyer_province_code=buyer_province_code,
            buyer_municipality_code=buyer_municipality_code
        )

        if result.get('error'):
            return jsonify(result), 400

        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500




@shipping_bp.route('/shipping/geocode', methods=['POST', 'OPTIONS'])
def geocode_address():
    """
    Convert address to coordinates
    
    Request body:
    {
        "address": str
    }
    
    Response:
    {
        "latitude": float,
        "longitude": float,
        "error": str or None
    }
    """
    # Handle CORS preflight request
    if request.method == 'OPTIONS':
        return '', 200
    
    # JWT protection only for POST requests
    try:
        from flask_jwt_extended import verify_jwt_in_request
        verify_jwt_in_request()
    except Exception as e:
        return jsonify({'error': 'Authorization required'}), 401
    
    try:
        data = request.get_json()
        
        if not data or not data.get('address'):
            return jsonify({'error': 'Address is required'}), 400
        
        address = data['address'].strip()
        if not address:
            return jsonify({'error': 'Address cannot be empty'}), 400
        
        # Geocode address
        coords = ShippingService.geocode_address(address)
        
        if coords:
            lat, lng = coords
            return jsonify({
                'latitude': lat,
                'longitude': lng,
                'error': None
            })
        else:
            return jsonify({
                'latitude': None,
                'longitude': None,
                'error': 'Could not geocode address'
            }), 400
            
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500


@shipping_bp.route('/shipping/shop-coordinates/<int:shop_id>', methods=['GET'])
def get_shop_coordinates(shop_id):
    """Get shop coordinates for shipping calculation"""
    try:
        from app.models import Store
        
        shop = Store.query.get(shop_id)
        if not shop:
            return jsonify({'error': 'Shop not found'}), 404
        
        if not shop.latitude or not shop.longitude:
            return jsonify({'error': 'Shop coordinates not available'}), 404
        
        return jsonify({
            'shop_id': shop_id,
            'shop_name': shop.store_name,
            'latitude': float(shop.latitude),
            'longitude': float(shop.longitude),
            'address': shop.address
        })
        
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500


@shipping_bp.route('/shipping/update-shop-coordinates', methods=['POST'])
@jwt_required()
def update_shop_coordinates():
    """
    Update shop coordinates by geocoding the shop address
    
    Request body:
    {
        "shop_id": int
    }
    """
    try:
        data = request.get_json()
        
        if not data or not data.get('shop_id'):
            return jsonify({'error': 'Shop ID is required'}), 400
        
        shop_id = int(data['shop_id'])
        
        from app.models import Store
        
        shop = Store.query.get(shop_id)
        if not shop:
            return jsonify({'error': 'Shop not found'}), 404
        
        # Update coordinates
        success = ShippingService.update_shop_coordinates(shop_id, shop.address)
        
        if success:
            return jsonify({
                'message': 'Shop coordinates updated successfully',
                'latitude': float(shop.latitude),
                'longitude': float(shop.longitude)
            })
        else:
            return jsonify({'error': 'Failed to update shop coordinates'}), 400
            
    except Exception as e:
        return jsonify({'error': 'Internal server error'}), 500
