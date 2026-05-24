"""Commission and shipping fee calculation service."""

from typing import Dict, Optional, Tuple
from sqlalchemy import select
from app.models import (
    Order, 
    ShippingSettings, 
    CommissionSettings, 
    RiderEarnings,
    RiderDelivery,
    DeliveryStatus,
    SellerWallet,
    PaymentTransaction,
    PaymentStatus,
    db
)
import datetime as dt


class CommissionService:
    """Service for handling commission calculations and shipping fees."""
    
    # Standard shipping rates by region
    SHIPPING_RATES = {
        'Metro Manila': 30.0,
        'Luzon': 60.0,
        'Visayas': 100.0,
        'Mindanao': 130.0
    }
    
    # Rider fee distribution percentages
    RIDER_SHARE_PERCENTAGE = 0.80  # 80% to rider
    ADMIN_SHARE_PERCENTAGE = 0.10  # 10% to admin
    SELLER_SHARE_PERCENTAGE = 0.10  # 10% to seller
    
    @classmethod
    def get_commission_rate(cls) -> float:
        """Get the current admin commission rate."""
        commission_setting = db.session.execute(
            select(CommissionSettings)
            .where(CommissionSettings.is_active == True)
            .order_by(CommissionSettings.created_at.desc())
        ).scalar_one_or_none()
        
        return commission_setting.commission_rate if commission_setting else 0.10
    
    @classmethod
    def calculate_shipping_fee(cls, region_name: str, province_name: str = None, city_name: str = None, store_id: int = None) -> float:
        """Calculate shipping fee based on location."""
        
        # Try to get store-specific shipping settings first
        if store_id:
            shipping_setting = db.session.execute(
                select(ShippingSettings)
                .where(
                    ShippingSettings.store_id == store_id,
                    ShippingSettings.is_active == True
                )
                .order_by(ShippingSettings.created_at.desc())
            ).scalar_one_or_none()
            
            if shipping_setting:
                return float(shipping_setting.shipping_fee)
        
        # Fall back to standard regional rates
        for region, rate in cls.SHIPPING_RATES.items():
            if region_name and region.lower() in region_name.lower():
                return rate
        
        # Default to highest rate if region not found
        return cls.SHIPPING_RATES['Mindanao']
    
    @classmethod
    def calculate_order_financials(cls, order: Order) -> Dict:
        """Calculate complete financial breakdown for an order."""
        
        # Get commission rate
        commission_rate = cls.get_commission_rate()
        
        # Product subtotal (excluding shipping)
        product_subtotal = float(order.total_amount or 0.0)
        
        # Admin commission (10% of product price only)
        admin_commission = product_subtotal * commission_rate
        
        # Shipping fee (separate from commission calculation)
        shipping_fee = float(order.shipping_fee or 0.0)
        
        # Rider fee distribution (only from shipping fee)
        rider_earnings = shipping_fee * cls.RIDER_SHARE_PERCENTAGE
        admin_share_from_shipping = shipping_fee * cls.ADMIN_SHARE_PERCENTAGE
        seller_share_from_shipping = shipping_fee * cls.SELLER_SHARE_PERCENTAGE
        
        # Total admin earnings
        total_admin_earnings = admin_commission + admin_share_from_shipping
        
        # Seller payout (product price - commission + seller share of shipping)
        seller_payout = product_subtotal - admin_commission + seller_share_from_shipping
        
        # Grand total (what customer pays)
        grand_total = product_subtotal + shipping_fee
        
        return {
            "productSubtotal": product_subtotal,
            "shippingFee": shipping_fee,
            "adminCommission": admin_commission,
            "adminCommissionRate": commission_rate,
            "riderEarnings": rider_earnings,
            "adminShareFromShipping": admin_share_from_shipping,
            "sellerShareFromShipping": seller_share_from_shipping,
            "totalAdminEarnings": total_admin_earnings,
            "sellerPayout": seller_payout,
            "grandTotal": grand_total,
            "riderSharePercentage": cls.RIDER_SHARE_PERCENTAGE,
            "adminSharePercentage": cls.ADMIN_SHARE_PERCENTAGE,
            "sellerSharePercentage": cls.SELLER_SHARE_PERCENTAGE
        }
    
    @classmethod
    def create_rider_earnings_record(cls, delivery: RiderDelivery) -> Optional[RiderEarnings]:
        """Create rider earnings record when delivery is completed."""
        
        if delivery.status != DeliveryStatus.DELIVERED:
            return None
        
        order = delivery.order
        if not order:
            return None
        
        financials = cls.calculate_order_financials(order)
        
        # Check if earnings record already exists
        existing_earnings = db.session.execute(
            select(RiderEarnings)
            .where(RiderEarnings.delivery_id == delivery.id)
        ).scalar_one_or_none()
        
        if existing_earnings:
            return existing_earnings
        
        # Create new earnings record
        earnings = RiderEarnings(
            delivery_id=delivery.id,
            rider_id=delivery.rider_id,
            shipping_fee_total=financials["shippingFee"],
            rider_share_percentage=cls.RIDER_SHARE_PERCENTAGE,
            admin_share_percentage=cls.ADMIN_SHARE_PERCENTAGE,
            seller_share_percentage=cls.SELLER_SHARE_PERCENTAGE,
            rider_earnings=financials["riderEarnings"],
            admin_earnings=financials["adminShareFromShipping"],
            seller_earnings=financials["sellerShareFromShipping"],
            is_paid=False  # Mark as unpaid until processed
        )
        
        db.session.add(earnings)
        return earnings
    
    @classmethod
    def settle_order_payment(cls, order: Order) -> bool:
        """Settle payment and distribute funds when order is completed."""
        
        try:
            # Get or create payment transaction
            payment_tx = db.session.execute(
                select(PaymentTransaction)
                .where(PaymentTransaction.order_id == order.id)
            ).scalar_one_or_none()
            
            if not payment_tx:
                return False
            
            if payment_tx.status == PaymentStatus.SETTLED:
                return True

            if payment_tx.status != PaymentStatus.HELD:
                return False
            
            # Calculate financials
            financials = cls.calculate_order_financials(order)
            
            # Update payment transaction
            payment_tx.status = PaymentStatus.SETTLED
            payment_tx.platform_fee = financials["totalAdminEarnings"]
            payment_tx.updated_at = dt.datetime.utcnow()
            
            # Credit seller wallet
            if payment_tx.seller_id:
                wallet = db.session.execute(
                    select(SellerWallet)
                    .where(SellerWallet.seller_id == payment_tx.seller_id)
                ).scalar_one_or_none()
                
                if not wallet:
                    wallet = SellerWallet(
                        seller_id=payment_tx.seller_id,
                        balance=0.0
                    )
                    db.session.add(wallet)
                
                wallet.balance += financials["sellerPayout"]
                wallet.updated_at = dt.datetime.utcnow()
            
            # Update order with commission
            order.admin_commission = financials["adminCommission"]
            order.updated_at = dt.datetime.utcnow()
            
            # Create rider earnings record if delivery exists
            deliveries = getattr(order, "deliveries", [])
            for delivery in deliveries:
                if delivery.status == DeliveryStatus.DELIVERED:
                    cls.create_rider_earnings_record(delivery)
            
            return True
            
        except Exception as e:
            print(f"Error settling order payment: {e}")
            return False
    
    @classmethod
    def get_region_from_address(cls, address: str) -> str:
        """Extract region name from address string."""
        if not address:
            return "Mindanao"  # Default to highest rate
        
        address_lower = address.lower()
        
        # Check for Metro Manila
        if any(keyword in address_lower for keyword in ['metro manila', 'ncr', 'manila']):
            return "Metro Manila"
        
        # Check for Luzon regions
        if any(keyword in address_lower for keyword in ['luzon', 'quezon', 'bulacan', 'cavite', 'laguna', 'batangas', 'rizal']):
            return "Luzon"
        
        # Check for Visayas regions
        if any(keyword in address_lower for keyword in ['visayas', 'cebu', 'negros', 'panay', 'bohol', 'leyte', 'samar']):
            return "Visayas"
        
        # Check for Mindanao regions
        if any(keyword in address_lower for keyword in ['mindanao', 'davao', 'cagayan', 'cotabato', 'zamboanga', 'general santos']):
            return "Mindanao"
        
        # Default to Mindanao (highest rate)
        return "Mindanao"
