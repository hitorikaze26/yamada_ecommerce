"""User Addresses API
Handles CRUD operations for user's saved addresses
"""
from flask import Blueprint, request, jsonify, g, current_app
from flask_jwt_extended import jwt_required, current_user
from sqlalchemy import select
from sqlalchemy.orm import joinedload
from ..models import db, UserAddress, User

user_bp = Blueprint('user', __name__)

# MySQL schema requires non-null lat/lng even though coordinates are optional in the app.
_DEFAULT_LAT = 0.0
_DEFAULT_LNG = 0.0


def _coords_from_payload(data: dict | None = None) -> tuple[float, float]:
    data = data or {}
    lat = data.get('latitude')
    lng = data.get('longitude')
    try:
        lat_f = float(lat) if lat is not None else _DEFAULT_LAT
    except (TypeError, ValueError):
        lat_f = _DEFAULT_LAT
    try:
        lng_f = float(lng) if lng is not None else _DEFAULT_LNG
    except (TypeError, ValueError):
        lng_f = _DEFAULT_LNG
    return lat_f, lng_f


def _profile_address_json(bp) -> dict:
    """Serialize buyer profile address for API responses (no DB row required)."""
    return {
        'id': 'profile',
        'userId': bp.user_id,
        'label': 'Home',
        'streetAddress': bp.street_address or '',
        'barangayName': bp.barangay_name or '',
        'municipalityName': bp.municipality_name or '',
        'provinceName': bp.province_name or '',
        'regionName': bp.region_name or '',
        'postalCode': bp.postal_code or '',
        'regionCode': bp.region_code or '',
        'provinceCode': bp.province_code or '',
        'municipalityCode': bp.municipality_code or '',
        'barangayCode': bp.barangay_code or '',
        'latitude': _DEFAULT_LAT,
        'longitude': _DEFAULT_LNG,
        'isDefault': True,
        'createdAt': None,
    }


def _sync_profile_address_to_saved(user_id: int) -> None:
    """Import registration address from BuyerProfile into user_addresses once."""
    existing = db.session.execute(
        select(UserAddress).where(UserAddress.user_id == user_id)
    ).scalars().all()
    if existing:
        return

    user = db.session.execute(
        select(User)
        .options(joinedload(User.buyer_profile))
        .where(User.id == user_id)
    ).scalar_one_or_none()
    if user is None or user.buyer_profile is None:
        return

    bp = user.buyer_profile
    if not (bp.municipality_name or bp.barangay_name or bp.region_name):
        return

    lat, lng = _coords_from_payload()
    profile_address = UserAddress(
        user_id=user_id,
        label='Home',
        street_address=bp.street_address or '',
        barangay_name=bp.barangay_name or '',
        municipality_name=bp.municipality_name or '',
        province_name=bp.province_name or '',
        region_name=bp.region_name or '',
        postal_code=bp.postal_code or '',
        region_code=bp.region_code or '',
        province_code=bp.province_code or '',
        municipality_code=bp.municipality_code or '',
        barangay_code=bp.barangay_code or '',
        latitude=lat,
        longitude=lng,
        is_default=True,
    )
    db.session.add(profile_address)
    db.session.commit()


@user_bp.route('/user/addresses', methods=['GET'])
@jwt_required()
def get_addresses():
    """Get all saved addresses for current user"""
    user_id = current_user.id
    try:
        _sync_profile_address_to_saved(user_id)
    except Exception as exc:
        db.session.rollback()
        current_app.logger.warning(
            'Profile address sync failed for user %s: %s', user_id, exc
        )

    try:
        stmt = select(UserAddress).where(UserAddress.user_id == user_id)
        addresses = db.session.execute(stmt).scalars().all()

        payload = [addr.to_json() for addr in addresses]
        if not payload:
            user = db.session.execute(
                select(User)
                .options(joinedload(User.buyer_profile))
                .where(User.id == user_id)
            ).scalar_one_or_none()
            bp = user.buyer_profile if user else None
            if bp and (bp.municipality_name or bp.barangay_name or bp.region_name):
                payload = [_profile_address_json(bp)]

        return jsonify({
            'addresses': payload,
            'count': len(payload)
        }), 200
    except Exception as exc:
        db.session.rollback()
        current_app.logger.error(
            'Failed to fetch addresses for user %s: %s', user_id, exc
        )
        return jsonify({'error': 'Failed to fetch addresses'}), 500

@user_bp.route('/user/addresses', methods=['POST'])
@jwt_required()
def add_address():
    """Add a new address for current user"""
    user_id = current_user.id
    
    data = request.get_json()
    is_default = data.get('isDefault', False)
    
    # If setting as default, remove default from others
    if is_default:
        stmt = select(UserAddress).where(UserAddress.user_id == user_id, UserAddress.is_default == True)
        for addr in db.session.execute(stmt).scalars().all():
            addr.is_default = False
    
    # Check if this is the first address
    stmt = select(UserAddress).where(UserAddress.user_id == user_id)
    existing_count = len(db.session.execute(stmt).scalars().all())
    if existing_count == 0:
        is_default = True
    
    lat, lng = _coords_from_payload(data)
    # Create new address
    new_address = UserAddress(
        user_id=user_id,
        label=data.get('label', 'Address'),
        street_address=data.get('streetAddress', ''),
        barangay_name=data.get('barangayName', ''),
        municipality_name=data.get('municipalityName', ''),
        province_name=data.get('provinceName', ''),
        region_name=data.get('regionName', ''),
        postal_code=data.get('postalCode', ''),
        region_code=data.get('regionCode', ''),
        province_code=data.get('provinceCode', ''),
        municipality_code=data.get('municipalityCode', ''),
        barangay_code=data.get('barangayCode', ''),
        latitude=lat,
        longitude=lng,
        is_default=is_default,
    )
    
    db.session.add(new_address)
    db.session.commit()
    
    return jsonify(new_address.to_json()), 201

@user_bp.route('/user/addresses/<address_id>', methods=['PUT'])
@jwt_required()
def update_address(address_id):
    """Update an existing address"""
    user_id = current_user.id
    
    stmt = select(UserAddress).where(
        UserAddress.id == int(address_id),
        UserAddress.user_id == user_id,
    )
    address = db.session.execute(stmt).scalar_one_or_none()
    
    if not address:
        return jsonify({'error': 'Address not found'}), 404
    
    data = request.get_json()
    
    # Update fields
    if 'label' in data:
        address.label = data['label']
    if 'streetAddress' in data:
        address.street_address = data['streetAddress']
    if 'barangayName' in data:
        address.barangay_name = data['barangayName']
    if 'municipalityName' in data:
        address.municipality_name = data['municipalityName']
    if 'provinceName' in data:
        address.province_name = data['provinceName']
    if 'regionName' in data:
        address.region_name = data['regionName']
    if 'postalCode' in data:
        address.postal_code = data['postalCode']
    if 'regionCode' in data:
        address.region_code = data['regionCode']
    if 'provinceCode' in data:
        address.province_code = data['provinceCode']
    if 'municipalityCode' in data:
        address.municipality_code = data['municipalityCode']
    if 'barangayCode' in data:
        address.barangay_code = data['barangayCode']
    if 'isDefault' in data and data['isDefault']:
        # Remove default from others
        stmt = select(UserAddress).where(UserAddress.user_id == user_id, UserAddress.is_default == True)
        for addr in db.session.execute(stmt).scalars().all():
            addr.is_default = False
        address.is_default = True
    
    db.session.commit()
    
    return jsonify(address.to_json()), 200

@user_bp.route('/user/addresses/<address_id>', methods=['DELETE'])
@jwt_required()
def delete_address(address_id):
    """Delete an address"""
    user_id = current_user.id
    
    stmt = select(UserAddress).where(
        UserAddress.id == int(address_id),
        UserAddress.user_id == user_id,
    )
    address = db.session.execute(stmt).scalar_one_or_none()
    
    if not address:
        return jsonify({'error': 'Address not found'}), 404
    
    was_default = address.is_default
    db.session.delete(address)
    
    # If we deleted the default, set another as default
    if was_default:
        stmt = select(UserAddress).where(UserAddress.user_id == user_id)
        remaining = db.session.execute(stmt).scalars().first()
        if remaining:
            remaining.is_default = True
    
    db.session.commit()
    
    return jsonify({'message': 'Address deleted'}), 200

@user_bp.route('/user/addresses/<address_id>/default', methods=['PATCH'])
@jwt_required()
def set_default_address(address_id):
    """Set an address as default"""
    user_id = current_user.id
    
    # Remove default from all addresses
    stmt = select(UserAddress).where(UserAddress.user_id == user_id, UserAddress.is_default == True)
    for addr in db.session.execute(stmt).scalars().all():
        addr.is_default = False
    
    # Set the specified address as default
    stmt = select(UserAddress).where(
        UserAddress.id == int(address_id),
        UserAddress.user_id == user_id,
    )
    address = db.session.execute(stmt).scalar_one_or_none()
    if not address:
        return jsonify({'error': 'Address not found'}), 404
    
    address.is_default = True
    db.session.commit()
    
    return jsonify({'message': 'Default address updated'}), 200
