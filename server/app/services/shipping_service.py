"""Shipping service with real-world distance calculation"""

import os
import requests
import math
from typing import Optional, Tuple
from flask import current_app, has_app_context
import logging

_logger = logging.getLogger(__name__)

def _log_info(msg: str):
    if has_app_context():
        current_app.logger.info(msg)
    else:
        _logger.info(msg)

def _log_warning(msg: str):
    if has_app_context():
        current_app.logger.warning(msg)
    else:
        _logger.warning(msg)

def _log_error(msg: str):
    if has_app_context():
        current_app.logger.error(msg)
    else:
        _logger.error(msg)

def _log_debug(msg: str):
    if has_app_context():
        current_app.logger.debug(msg)
    else:
        _logger.debug(msg)
from app.models import Store, DistanceCache, db, Seller
from sqlalchemy import and_, select


class ShippingService:
    """Service for calculating shipping fees using real routing APIs"""
    
    # API endpoints
    GEOCODING_API_URL = "https://nominatim.openstreetmap.org/search"
    ROUTING_API_URL = "https://api.openrouteservice.org/v2/matrix/driving-car"

    @classmethod
    def _openrouteservice_api_key(cls) -> str:
        if has_app_context():
            return current_app.config.get("OPENROUTESERVICE_API_KEY", "") or ""
        return os.environ.get("OPENROUTESERVICE_API_KEY", "")
    
    # Shipping calculation constants
    BASE_FEE = 40.0
    RATE_PER_KM = 5.0
    MAXIMUM_DISTANCE = 50.0  # Maximum delivery distance in km
    MINIMUM_FEE = 30.0
    FREE_SHIPPING_THRESHOLD = 10000.0  # Free shipping for orders over this amount
    
    
    @classmethod
    def geocode_address(cls, address: str) -> Optional[Tuple[float, float]]:
        """
        Convert address to latitude/longitude using Nominatim API
        Returns (latitude, longitude) or None if failed
        """
        try:
            # Clean and format the address
            clean_address = address.strip()
            if not clean_address:
                return None
            
            params = {
                'q': clean_address,
                'format': 'json',
                'limit': 1,
                'countrycodes': 'ph',  # Restrict to Philippines
                'addressdetails': 1,   # Get more detailed address info
            }
            
            # Add user agent as required by Nominatim usage policy
            headers = {
                'User-Agent': 'Yamada-Ecommerce/1.0 (shipping-geocoding; contact@yamada.ph)'
            }
            
            _log_info(f"Geocoding address: {clean_address}")
            response = requests.get(cls.GEOCODING_API_URL, params=params, headers=headers, timeout=15)
            
            _log_info(f"Geocode response status: {response.status_code}")
            
            if response.status_code == 429:
                current_app.logger.error("Rate limited by Nominatim API")
                return None
            
            response.raise_for_status()
            
            data = response.json()
            current_app.logger.info(f"Geocode results count: {len(data) if data else 0}")
            
            if data and len(data) > 0:
                result = data[0]
                lat = float(result['lat'])
                lng = float(result['lon'])
                
                _log_info(f"Geocoded '{clean_address}' to ({lat}, {lng})")
                return lat, lng
            else:
                _log_warning(f"No results found for address: {clean_address}")
                
        except requests.exceptions.Timeout:
            _log_error(f"Geocoding timeout for address '{address}'")
        except requests.exceptions.RequestException as e:
            _log_error(f"Geocoding request failed for address '{address}': {e}")
        except (ValueError, KeyError) as e:
            _log_error(f"Geocoding data parsing failed for address '{address}': {e}")
        except Exception as e:
            _log_error(f"Geocoding failed for address '{address}': {e}")
            
        return None
    
    @classmethod
    def get_distance_from_cache(cls, origin_lat: float, origin_lng: float,
                               dest_lat: float, dest_lng: float) -> Optional[float]:
        """
        Get distance from cache with coordinate tolerance (±0.01)
        Returns distance in kilometers or None if not found
        """
        try:
            # Define tolerance for coordinate matching (±0.01 degrees ≈ ±1km)
            tolerance = 0.01
            
            cache_entry = db.session.query(DistanceCache).filter(
                and_(
                    DistanceCache.origin_lat.between(origin_lat - tolerance, origin_lat + tolerance),
                    DistanceCache.origin_lng.between(origin_lng - tolerance, origin_lng + tolerance),
                    DistanceCache.dest_lat.between(dest_lat - tolerance, dest_lat + tolerance),
                    DistanceCache.dest_lng.between(dest_lng - tolerance, dest_lng + tolerance)
                )
            ).first()
            
            if cache_entry:
                _log_debug(f"Cache hit for distance: {cache_entry.distance_km} km")
                return cache_entry.distance_km
                
        except Exception as e:
            _log_error(f"Failed to get distance from cache: {e}")
            
        return None
    
    @classmethod
    def cache_distance(cls, origin_lat: float, origin_lng: float,
                      dest_lat: float, dest_lng: float, distance_km: float):
        """Cache a calculated distance"""
        try:
            cache_entry = DistanceCache(
                origin_lat=origin_lat,
                origin_lng=origin_lng,
                dest_lat=dest_lat,
                dest_lng=dest_lng,
                distance_km=distance_km
            )
            db.session.add(cache_entry)
            db.session.commit()
            
        except Exception as e:
            _log_error(f"Failed to cache distance: {e}")
            db.session.rollback()
    
    @classmethod
    def validate_coordinates(cls, lat: float, lng: float) -> bool:
        """
        Validate latitude and longitude coordinates
        Returns True if valid, False otherwise
        """
        try:
            # Convert to float to ensure numeric
            lat = float(lat)
            lng = float(lng)
            
            # Validate ranges
            if not (-90.0 <= lat <= 90.0):
                return False
            if not (-180.0 <= lng <= 180.0):
                return False
                
            return True
        except (ValueError, TypeError):
            return False
    
    @classmethod
    def calculate_real_distance(cls, origin_lat: float, origin_lng: float,
                              dest_lat: float, dest_lng: float) -> Optional[float]:
        """
        Calculate real driving distance using OpenRouteService routing API
        Returns distance in kilometers or None if failed
        """
        try:
            # Validate input coordinates
            if not cls.validate_coordinates(origin_lat, origin_lng):
                _log_error(f"Invalid origin coordinates: {origin_lat}, {origin_lng}")
                return None
            if not cls.validate_coordinates(dest_lat, dest_lng):
                _log_error(f"Invalid destination coordinates: {dest_lat}, {dest_lng}")
                return None
            
            # Check cache first
            cached_distance = cls.get_distance_from_cache(origin_lat, origin_lng, dest_lat, dest_lng)
            if cached_distance:
                return cached_distance

            # OpenRouteService API call for real routing distance with simple retry logic
            headers = {
                'Authorization': cls._openrouteservice_api_key(),
                'Content-Type': 'application/json'
            }
            
            # OpenRouteService Matrix API expects coordinates in [longitude, latitude] format
            body = {
                'locations': [
                    [origin_lng, origin_lat],
                    [dest_lng, dest_lat]
                ],
                'metrics': ['distance', 'duration']
            }

            attempts = 2
            for attempt in range(1, attempts + 1):
                try:
                    response = requests.post(cls.ROUTING_API_URL, json=body, headers=headers, timeout=10)
                    response.raise_for_status()
                    data = response.json()

                    # ORS Matrix API response format: {"distances": [[0, distance], [distance, 0]], "durations": [[0, duration], [duration, 0]]}
                    if 'distances' in data and len(data['distances']) >= 2:
                        distances_matrix = data['distances']
                        
                        # Get distance from origin (0) to destination (1)
                        distance_meters = distances_matrix[0][1]
                        
                        if distance_meters is None or distance_meters == 0:
                            raise ValueError('No valid distance found in matrix response')

                        distance_km = float(distance_meters) / 1000.0

                        # Cache the result (store km with 3 decimals)
                        cls.cache_distance(origin_lat, origin_lng, dest_lat, dest_lng, distance_km)
                        return distance_km

                    # If no distances found, raise to attempt fallback
                    raise ValueError('No distance matrix found in response')

                except requests.exceptions.RequestException as re:
                    _log_warning(f"OpenRouteService API request failed (attempt {attempt}): {re}")
                    # small backoff between attempts
                    if attempt < attempts:
                        import time
                        time.sleep(0.5 * attempt)
                    continue
                except Exception as re:
                    _log_warning(f"OpenRouteService API error (attempt {attempt}): {re}")
                    if attempt < attempts:
                        import time
                        time.sleep(0.5 * attempt)
                    continue

        except Exception as e:
            _log_error(f"Distance calculation failed: {e}")

        return None
    
    @classmethod
    def get_shop_coordinates(cls, shop_id: int) -> dict:
        """
        Get shop coordinates for shipping calculation
        
        Args:
            shop_id: Shop ID
            
        Returns:
            dict: {
                'latitude': float,
                'longitude': float,
                'error': str or None
            }
        """
        result = {
            'latitude': None,
            'longitude': None,
            'error': None
        }
        
        try:
            from app.models import db, Store
            
            # Get shop from database
            shop = db.session.query(Store).filter(Store.id == shop_id).first()
            
            if not shop:
                result['error'] = f'Shop with ID {shop_id} not found'
                return result
            
            # Check if shop has coordinates
            if not shop.latitude or not shop.longitude:
                result['error'] = f'Shop coordinates not set for shop ID {shop_id}'
                return result
            
            result['latitude'] = float(shop.latitude)
            result['longitude'] = float(shop.longitude)
            
        except Exception as e:
            _log_error(f"Error getting shop coordinates: {e}")
            result['error'] = 'Internal server error'
            
        return result
    
    @classmethod
    def _normalize_region_name(cls, name: str) -> str:
        """Map any Philippine region name/PSGC name to internal 4-group system."""
        if not name:
            return ""
        n = name.strip().lower()
        # Metro Manila / NCR (also matches PSGC codes like "130000000")
        if n in ("metro manila", "ncr", "national capital region") or (n.isdigit() and n.startswith("13")):
            return "Metro Manila"
        # All other PSGC regions map to Luzon, Visayas, or Mindanao
        luzon_keywords = ("luzon", "ilocos", "cagayan valley", "central luzon",
                          "calabarzon", "mimaropa", "bicol", "cordillera")
        visayas_keywords = ("visayas", "western visayas", "central visayas", "eastern visayas")
        mindanao_keywords = ("mindanao", "zamboanga", "northern mindanao", "davao",
                             "soccsksargen", "caraga", "barmm", "bangsamoro")
        if any(kw in n for kw in luzon_keywords):
            return "Luzon"
        if any(kw in n for kw in visayas_keywords):
            return "Visayas"
        if any(kw in n for kw in mindanao_keywords):
            return "Mindanao"
        return name.strip()  # fallback to original

    @classmethod
    def calculate_shipping_fee(cls, shop_id: int, order_total: float = 0.0,
                               buyer_region: str = None, buyer_province: str = None, buyer_municipality: str = None,
                               buyer_region_code: str = None, buyer_province_code: str = None, buyer_municipality_code: str = None) -> dict:
        """
        Calculate shipping fee based on location codes (PSGC format).

        Rules:
        1) Same region_code + same province_code + same municipality_code = ₱30
        2) Same region_code + same province_code + different municipality_code = ₱35
        3) Same region_code + different province_code = ₱70
        4) Different region_code = ₱100

        Supports both code-based (preferred) and name-based (fallback) comparison.

        Returns:
            {
                'shipping_fee': float,
                'free_shipping': bool,
                'error': str or None,
                'note': str or None
            }
        """
        result = {
            'shipping_fee': None,
            'free_shipping': order_total >= cls.FREE_SHIPPING_THRESHOLD,
            'error': None,
            'note': None
        }

        try:
            # Free shipping check
            if result['free_shipping']:
                result['shipping_fee'] = 0.0
                return result

            # Load shop and seller info
            shop = db.session.execute(select(Store).where(Store.id == shop_id)).scalar_one_or_none()
            if not shop:
                result['error'] = 'Shop not found'
                return result

            seller = getattr(shop, 'seller', None)
            if not seller:
                result['error'] = 'Seller not found for shop'
                return result

            # Normalize strings for comparison
            def _norm(s: str) -> str:
                return (s or '').strip().lower()

            # Try code-based comparison first (preferred)
            seller_region_code = getattr(seller, 'region_code', None)
            seller_province_code = getattr(seller, 'province_code', None)
            seller_municipality_code = getattr(seller, 'municipality_code', None)

            # Use provided codes or fallback to names
            use_codes = False
            if buyer_region_code and buyer_municipality_code and seller_region_code and seller_municipality_code:
                use_codes = True
                b_region = _norm(buyer_region_code)
                b_province = _norm(buyer_province_code) if buyer_province_code else ''
                b_municipality = _norm(buyer_municipality_code)
                s_region = _norm(seller_region_code)
                s_province = _norm(seller_province_code) if seller_province_code else ''
                s_municipality = _norm(seller_municipality_code)
                _log_info(f"Using CODE-based comparison: seller({s_region}/{s_province}/{s_municipality}) vs buyer({b_region}/{b_province}/{b_municipality})")
            else:
                # Fallback to name-based comparison
                if not buyer_region or not buyer_municipality:
                    result['error'] = 'Buyer location fields required: region and municipality/city'
                    return result

                # Normalize region names from PSGC format (e.g. "CALABARZON", "NCR")
                # to internal groups (Luzon, Metro Manila, Visayas, Mindanao) for comparison
                b_region = cls._normalize_region_name(buyer_region)
                b_province = _norm(buyer_province) if buyer_province else ''
                b_municipality = _norm(buyer_municipality)

                seller_region = getattr(seller, 'region_name', None)
                seller_province = getattr(seller, 'province_name', None)
                seller_municipality = getattr(seller, 'municipality_name', None)

                s_region = cls._normalize_region_name(seller_region)
                s_province = _norm(seller_province) if seller_province else ''
                s_municipality = _norm(seller_municipality)
                _log_info(f"Using NAME-based comparison: seller({s_region}/{s_province}/{s_municipality}) vs buyer({b_region}/{b_province}/{b_municipality})")

            # Apply rules
            if s_region and s_region == b_region:
                # Same region
                if s_province and b_province and s_province == b_province:
                    # Same province
                    if s_municipality and s_municipality == b_municipality:
                        result['shipping_fee'] = 30.0
                        result['note'] = 'Same region, same province, same municipality'
                    else:
                        result['shipping_fee'] = 35.0
                        result['note'] = 'Same region, same province, different municipality'
                elif (not s_province and not b_province) and cls._normalize_region_name(s_region) == "Metro Manila":
                    # Both are NCR (no province) — compare municipality only
                    if s_municipality and s_municipality == b_municipality:
                        result['shipping_fee'] = 30.0
                        result['note'] = 'Same NCR region, same municipality'
                    else:
                        result['shipping_fee'] = 35.0
                        result['note'] = 'Same NCR region, different municipality'
                else:
                    result['shipping_fee'] = 70.0
                    result['note'] = 'Same region, different province'
            else:
                result['shipping_fee'] = 100.0
                result['note'] = 'Different region'

            _log_info(f"Shipping fee calculated: ₱{result['shipping_fee']} - {result['note']}")

        except Exception as e:
            _log_error(f"Shipping fee calculation failed: {e}")
            result['error'] = 'Calculation error'

        return result
    
    @classmethod
    def update_shop_coordinates(cls, shop_id: int, address: str) -> bool:
        """Update shop coordinates by geocoding the address"""
        try:
            coords = cls.geocode_address(address)
            if coords:
                lat, lng = coords
                shop = db.session.execute(select(Store).where(Store.id == shop_id)).scalar_one_or_none()
                if shop:
                    shop.latitude = lat
                    shop.longitude = lng
                    db.session.commit()
                    return True
        except Exception as e:
            current_app.logger.error(f"Failed to update shop coordinates: {e}")
            db.session.rollback()
            
        return False
