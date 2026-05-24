import datetime
import traceback
import os
from . import (
    cart as cart_bp,
    db
)
from flask import (
    jsonify,
    request,
    current_app
)
from flask_jwt_extended import (
    jwt_required,
    current_user
)
from sqlalchemy import select
from app.models import (
    Cart,
    CartItem,
    Product,
    ProductVariation
)

from app.utils.static_urls import public_static_url as _public_image_url

def ensure_cart_tables_exist():
    """Ensure cart tables exist, create if missing"""
    try:
        # Try to query the cart table to see if it exists
        db.session.execute(select(Cart)).first()
    except Exception as e:
        print(f"Cart tables don't exist, creating them...")
        try:
            db.create_all()
            print("Cart tables created successfully")
        except Exception as create_error:
            print(f"Error creating tables: {create_error}")
            traceback.print_exc()

@cart_bp.get('/get-cart')
@jwt_required()
def getCart():
    """Get the current user's cart"""
    try:
        ensure_cart_tables_exist()
        
        # Use SQLAlchemy 2.0 syntax
        cart = db.session.execute(
            select(Cart).where(Cart.user_id == current_user.id)
        ).scalars().first()
        
        if not cart:
            # Create empty cart if doesn't exist
            cart = Cart(user_id=current_user.id)
            db.session.add(cart)
            db.session.commit()
        
        return jsonify({
            'success': True,
            'cart': cart.to_json()
        }), 200
    except Exception as e:
        print(f"Error in getCart: {str(e)}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@cart_bp.post('/add-to-cart')
@jwt_required()
def addToCart():
    """Add an item to the cart"""
    try:
        ensure_cart_tables_exist()
        
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': 'No data provided'
            }), 400
        
        product_id = data.get('productId')
        variation_id = data.get('variationId')
        quantity = data.get('quantity', 1)
        
        if not product_id or not variation_id:
            return jsonify({
                'success': False,
                'error': 'productId and variationId are required'
            }), 400
        
        # Validate product and variation exist using SQLAlchemy 2.0 syntax
        product = db.session.execute(
            select(Product).where(Product.id == product_id)
        ).scalars().first()
        
        variation = db.session.execute(
            select(ProductVariation).where(ProductVariation.id == variation_id)
        ).scalars().first()
        
        if not product or not variation:
            return jsonify({
                'success': False,
                'error': 'Product or variation not found'
            }), 404

        from app.models import Store
        own_store = db.session.execute(
            select(Store).where(Store.user_id == current_user.id)
        ).scalars().first()
        if own_store is not None and product.store_id == own_store.id:
            return jsonify({
                'success': False,
                'error': 'You cannot add your own products to the cart',
            }), 400
        
        # Get or create cart
        cart = db.session.execute(
            select(Cart).where(Cart.user_id == current_user.id)
        ).scalars().first()
        
        if not cart:
            cart = Cart(user_id=current_user.id)
            db.session.add(cart)
            db.session.flush()
        
        # Check if item already in cart
        existing_item = db.session.execute(
            select(CartItem).where(
                (CartItem.cart_id == cart.id) &
                (CartItem.product_id == product_id) &
                (CartItem.variation_id == variation_id)
            )
        ).scalars().first()
        
        if existing_item:
            # Update quantity
            existing_item.quantity += quantity
            existing_item.updated_at = datetime.datetime.now()
        else:
            # Add new item
            price_at_add = variation.price or product.sale_price or product.price
            cart_item = CartItem(
                cart_id=cart.id,
                product_id=product_id,
                variation_id=variation_id,
                quantity=quantity,
                price_at_add=price_at_add
            )
            db.session.add(cart_item)
        
        cart.updated_at = datetime.datetime.now()
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Item added to cart',
            'cart': cart.to_json()
        }), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error in addToCart: {str(e)}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@cart_bp.put('/update-cart-item/<int:item_id>')
@jwt_required()
def updateCartItem(item_id):
    """Update quantity of a cart item"""
    try:
        ensure_cart_tables_exist()
        
        data = request.get_json()
        quantity = data.get('quantity')
        
        if quantity is None:
            return jsonify({
                'success': False,
                'error': 'quantity is required'
            }), 400
        
        if quantity < 1:
            return jsonify({
                'success': False,
                'error': 'quantity must be at least 1'
            }), 400
        
        # Get cart item and verify it belongs to current user
        cart_item = db.session.execute(
            select(CartItem).where(CartItem.id == item_id)
        ).scalars().first()
        
        if not cart_item:
            return jsonify({
                'success': False,
                'error': 'Cart item not found'
            }), 404
        
        # Verify cart belongs to current user
        if cart_item.cart.user_id != current_user.id:
            return jsonify({
                'success': False,
                'error': 'Unauthorized'
            }), 403
        
        cart_item.quantity = quantity
        cart_item.updated_at = datetime.datetime.now()
        cart_item.cart.updated_at = datetime.datetime.now()
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Cart item updated',
            'cart': cart_item.cart.to_json()
        }), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error in updateCartItem: {str(e)}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@cart_bp.delete('/remove-from-cart/<int:item_id>')
@jwt_required()
def removeFromCart(item_id):
    """Remove an item from the cart"""
    try:
        ensure_cart_tables_exist()
        
        cart_item = db.session.execute(
            select(CartItem).where(CartItem.id == item_id)
        ).scalars().first()
        
        if not cart_item:
            return jsonify({
                'success': False,
                'error': 'Cart item not found'
            }), 404
        
        # Verify cart belongs to current user
        if cart_item.cart.user_id != current_user.id:
            return jsonify({
                'success': False,
                'error': 'Unauthorized'
            }), 403
        
        cart = cart_item.cart
        db.session.delete(cart_item)
        cart.updated_at = datetime.datetime.now()
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Item removed from cart',
            'cart': cart.to_json()
        }), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error in removeFromCart: {str(e)}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@cart_bp.delete('/clear-cart')
@jwt_required()
def clearCart():
    """Clear all items from the cart"""
    try:
        ensure_cart_tables_exist()
        
        cart = db.session.execute(
            select(Cart).where(Cart.user_id == current_user.id)
        ).scalars().first()
        
        if not cart:
            return jsonify({
                'success': True,
                'message': 'Cart is already empty'
            }), 200
        
        # Delete all items in cart
        items_to_delete = db.session.execute(
            select(CartItem).where(CartItem.cart_id == cart.id)
        ).scalars().all()
        for item in items_to_delete:
            db.session.delete(item)
        cart.updated_at = datetime.datetime.now()
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Cart cleared',
            'cart': cart.to_json()
        }), 200
    except Exception as e:
        db.session.rollback()
        print(f"Error in clearCart: {str(e)}")
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
