from datetime import datetime, timezone, timedelta
import os
import json
import secrets
from werkzeug.utils import secure_filename

from . import (
    auth as auth_bp,
    db,
    User,
    RoleTypes,
    Role,
    UserRole,
    Seller,
    StoreRegistration,
    RiderProfile,
    jwt,
)
from app.models import (
    BuyerProfile,
    Review,
    OrderItem,
    Product,
    WishlistItem,
    StoreFollow,
    RecentlyViewedProduct,
    Coupon,
    CouponRedemption,
    ProblemReport,
    ReportStatus,
    Order,
    OrderStatus,
    RiderDelivery,
    Store,
    StoreRequestStatus,
    PasswordResetCode,
)
from app.extensions import mail, bcrypt, limiter
from app.services import sms_service
from app.services.email_service import send_password_reset_email
from app.coupon_helpers import serialize_coupon, validate_coupon
from app.chat.service import get_platform_admin_user
from app.notifications.service import create_notification, notify_admin_order_issue_reported
from app.stores_public.routes import _serialize_store_card
from app.utils.static_urls import public_static_url as _public_image_url
from app.decorators import buyer_required, rider_required, seller_required
from flask import (
    jsonify,
    abort,
    request,
    current_app,
    url_for,
)
from flask_jwt_extended import (
    create_access_token,
    get_csrf_token,
    jwt_required,
    get_jwt,
    get_jwt_identity,
    unset_jwt_cookies,
    set_access_cookies,
    current_user
)
from sqlalchemy import select, or_, delete, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

@auth_bp.after_request
def refresh_expiring_jwts(response):
    try:
        exp_timestamp = get_jwt()["exp"]
        now = datetime.now(timezone.utc)
        target_timestamp = datetime.timestamp(now + timedelta(minutes=30))
        if target_timestamp > exp_timestamp:
            identity = get_jwt_identity()
            claims = {}
            try:
                user_id = int(identity)
                user = db.session.get(User, user_id)
                if user is not None:
                    claims = _build_jwt_claims(user)
            except (TypeError, ValueError):
                pass
            access_token = create_access_token(
                identity=identity,
                additional_claims=claims,
            )
            set_access_cookies(response, access_token)
        return response
    except (RuntimeError, KeyError):
        # Case where there is not a valid JWT. Just return the original response
        return response
    
@jwt.user_identity_loader
def user_identity_lookup(user):
    """Normalize JWT identity.

    If a User object is passed, use its primary key; otherwise, return the
    primitive identity as-is. This avoids AttributeError when identity is
    already a username/email or an ID.
    """
    if isinstance(user, User):
        return str(user.id)
    return str(user)

@jwt.user_lookup_loader
def user_lookup_callback(_jwt_header, jwt_data):
    identity = jwt_data["sub"]
    try:
        user_id = int(identity)
    except (TypeError, ValueError):
        return None
    return db.session.execute(select(User).where(User.id == user_id)).scalar_one_or_none()


ROLE_NAME_BY_ID = {
    RoleTypes.ADMIN.value: "admin",
    RoleTypes.BUYER.value: "buyer",
    RoleTypes.SELLER.value: "seller",
    RoleTypes.RIDER.value: "rider",
}

ROLE_ID_BY_NAME = {v: k for k, v in ROLE_NAME_BY_ID.items()}
VALID_ROLE_NAMES = frozenset(ROLE_NAME_BY_ID.values())


def _user_role_ids(user_id: int) -> list:
    return list(
        db.session.execute(
            select(UserRole.role_id).where(UserRole.user_id == user_id)
        ).scalars().all()
    )


def _roles_for_user(user_id: int) -> tuple[list[int], list[str]]:
    """Resolve role IDs and canonical names from DB (source of truth)."""
    rows = db.session.execute(
        select(UserRole.role_id, Role.name)
        .join(Role, Role.id == UserRole.role_id)
        .where(UserRole.user_id == user_id)
    ).all()
    role_ids: list[int] = []
    names: list[str] = []
    for role_id, role_name in rows:
        role_ids.append(int(role_id))
        canonical = (role_name or "").strip().lower()
        if canonical in VALID_ROLE_NAMES and canonical not in names:
            names.append(canonical)
        elif role_id in ROLE_NAME_BY_ID:
            mapped = ROLE_NAME_BY_ID[role_id]
            if mapped not in names:
                names.append(mapped)
    return role_ids, names


def _user_role_names(role_ids: list | None = None, user_id: int | None = None) -> list:
    if user_id is not None:
        _, names = _roles_for_user(user_id)
        return names
    names: list[str] = []
    missing_ids: list[int] = []
    for role_id in role_ids or []:
        name = ROLE_NAME_BY_ID.get(role_id)
        if name:
            if name not in names:
                names.append(name)
        else:
            missing_ids.append(role_id)
    if missing_ids:
        db_roles = db.session.execute(
            select(Role).where(Role.id.in_(missing_ids))
        ).scalars().all()
        for role_row in db_roles:
            db_name = (role_row.name or "").strip().lower()
            if db_name in VALID_ROLE_NAMES and db_name not in names:
                names.append(db_name)
    return names


def _ensure_role_by_name(role_name: str) -> Role:
    """Attach roles by name so auto-increment role IDs never break login."""
    canonical = role_name.strip().lower()
    role = db.session.execute(
        select(Role).where(func.lower(Role.name) == canonical)
    ).scalar_one_or_none()
    if role is None:
        role = Role(name=canonical)
        db.session.add(role)
        db.session.flush()
    return role


def _user_has_role_name(user_id: int, role_name: str) -> bool:
    _, names = _roles_for_user(user_id)
    return role_name.strip().lower() in names


def _user_is_verified(user: User, role_ids: list | None = None) -> bool:
    is_verified = user.email_verified
    _, role_names = _roles_for_user(user.id)
    if "seller" in role_names:
        seller = db.session.execute(
            select(Seller).where(Seller.user_id == user.id)
        ).scalar_one_or_none()
        if seller and seller.registration:
            is_verified = (
                seller.registration.request_status.name
                == StoreRequestStatus.ACCEPTED.name
            )
    return is_verified


def _build_jwt_claims(user: User) -> dict:
    _, role_names = _roles_for_user(user.id)
    roles = [name for name in role_names if name in VALID_ROLE_NAMES]
    is_admin = "admin" in roles
    claims = {
        "is_buyer": "buyer" in roles,
        "is_seller": "seller" in roles,
        "is_rider": "rider" in roles,
        "is_admin": is_admin,
        "roles": roles,
    }
    if is_admin:
        claims["is_rider"] = False
        claims["is_seller"] = False
        claims["is_buyer"] = False
        claims["roles"] = ["admin"]
    return claims


def _session_snapshot(user: User) -> dict:
    role_ids = _user_role_ids(user.id)
    _, role_names = _roles_for_user(user.id)
    return {
        "user_id": user.id,
        "email": user.email,
        "given_name": user.given_name or "",
        "surname": user.surname or "",
        "contact_number": user.contact_number or "",
        "roles": role_names,
        "is_verified": _user_is_verified(user, role_ids),
    }


@auth_bp.post('/login')
@limiter.limit("10 per minute")
def login():
    if not request.is_json:
        current_app.logger.error("Login failed: Request is not JSON")
        abort(400)

    data = request.get_json()
    current_app.logger.info(f"Login attempt with data keys: {list(data.keys())}")

    username_input = data.get('username', '').strip()
    username_lookup = username_input.lower()
    password = data.get('password', '')
    requested_role = data.get('role', '').lower().strip()
    
    current_app.logger.info(f"Login attempt for username/email: {username_input}, requested role: {requested_role}")

    if username_input == "" or password == "":
        current_app.logger.warning("Login failed: Empty username or password")
        return jsonify(msg="Please input your credentials!"), 401

    # Case-insensitive match only — never rewrite stored email on login
    user = db.session.execute(
        select(User).where(
            or_(
                func.lower(User.username) == username_lookup,
                func.lower(User.email) == username_lookup,
            )
        )
    ).scalar_one_or_none()

    if user is None:
        current_app.logger.warning(f"Login failed: User not found for {username_input}")
        return jsonify(msg="User does not exist!"), 401
    
    current_app.logger.info(f"User found: {user.email}, checking password...")
    
    # Debug password check
    password_valid = user.check_password(password)
    current_app.logger.info(f"Password check result: {password_valid}")
    
    if not password_valid:
        current_app.logger.warning(f"Login failed: Invalid password for user {username_input}")
        return jsonify(msg="Incorrect password!"), 401

    if user.is_archived:
        user.restore_from_archive()
        if user.email_verified:
            user.setActive(True)
        db.session.commit()
    elif not user.active:
        current_app.logger.warning(f"Login denied: inactive account {username_input}")
        return jsonify(msg="This account has been deactivated. Contact support if you need help."), 403
    else:
        user.touch_activity()
        db.session.commit()

    user_roles = _user_role_ids(user.id)
    role_names = _user_role_names(user_id=user.id)

    if "admin" in role_names and requested_role and requested_role != "admin":
        current_app.logger.warning(
            "Login denied for %s: admin account attempted non-admin portal %s",
            username_input,
            requested_role,
        )
        return (
            jsonify(
                msg=(
                    "Admin accounts must sign in through the admin portal. "
                    "Use the admin login link or contact support."
                )
            ),
            403,
        )

    if requested_role:
        if requested_role not in role_names:
            current_app.logger.warning(
                "Login denied for %s: missing %s role (has ids=%s names=%s)",
                username_input,
                requested_role,
                user_roles,
                role_names,
            )
            return (
                jsonify(
                    msg=(
                        f"This account does not have {requested_role} access. "
                        f"Roles on this account: {', '.join(role_names) or 'none'}. "
                        "Use the correct portal or contact support."
                    )
                ),
                403,
            )

    claims = _build_jwt_claims(user)

    is_verified = _user_is_verified(user, user_roles)

    # Use the stable primary key as the JWT identity
    access_token = create_access_token(identity=user.id, additional_claims=claims)
    csrf_token = get_csrf_token(access_token)
    response = jsonify(
        msg="Successfully logged in!",
        access_token=access_token,
        csrf_token=csrf_token,
        is_verified=is_verified,
        roles=role_names,
        user_id=user.id,
        email=user.email,
    )
    set_access_cookies(response, access_token)

    return response

@auth_bp.post('/logout')
def logout():
    response = jsonify(msg="Successfully logged out!")
    unset_jwt_cookies(response)
    return response


@auth_bp.post('/refresh')
@jwt_required()
def refresh_access():
    """Issue a new access token for the current session (cookie + JSON)."""
    user = db.session.execute(
        select(User).where(User.id == current_user.id)
    ).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    claims = _build_jwt_claims(user)
    access_token = create_access_token(identity=user.id, additional_claims=claims)
    csrf_token = get_csrf_token(access_token)
    response = jsonify(access_token=access_token, csrf_token=csrf_token)
    set_access_cookies(response, access_token)
    return response, 200


@auth_bp.put('/change-password')
@jwt_required()
def change_password():
    """Change the current user's password.

    Expects JSON: { currentPassword, newPassword }
    """
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    current_password = data.get('currentPassword', '')
    new_password = data.get('newPassword', '')

    if not current_password or not new_password:
        return jsonify(msg="currentPassword and newPassword are required"), 400

    if len(new_password) < 6:
        return jsonify(msg="New password must be at least 6 characters"), 400

    try:
        user = db.session.execute(
            select(User).where(User.id == current_user.id)
        ).scalar_one_or_none()

        if user is None:
            return jsonify(msg="User not found"), 404

        if not user.check_password(current_password):
            return jsonify(msg="Current password is incorrect"), 400

        user.set_password(new_password)
        db.session.commit()
        return jsonify(msg="Password changed successfully"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to change password"), 500


@auth_bp.put('/change-email')
@jwt_required()
def change_email():
    """Change the current user's email address.

    Expects JSON: { newEmail, password }
    """
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    new_email = (data.get('newEmail') or '').strip()
    password = data.get('password', '')

    if not new_email or not password:
        return jsonify(msg="newEmail and password are required"), 400

    try:
        user = db.session.execute(
            select(User).where(User.id == current_user.id)
        ).scalar_one_or_none()

        if user is None:
            return jsonify(msg="User not found"), 404

        if not user.check_password(password):
            return jsonify(msg="Password is incorrect"), 400

        # Check email not already taken
        existing = db.session.execute(
            select(User).where(func.lower(User.email) == new_email.lower())
        ).scalar_one_or_none()
        if existing is not None and existing.id != user.id:
            return jsonify(msg="Email already in use"), 400

        user.email = new_email
        db.session.commit()
        return jsonify(msg="Email changed successfully"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to change email"), 500


@auth_bp.delete('/delete-account')
@jwt_required()
def delete_account():
    """Permanently delete the current user's account.

    Expects JSON: { password }
    """
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    password = data.get('password', '')

    if not password:
        return jsonify(msg="Password is required to confirm deletion"), 400

    try:
        user = db.session.execute(
            select(User).where(User.id == current_user.id)
        ).scalar_one_or_none()

        if user is None:
            return jsonify(msg="User not found"), 404

        if not user.check_password(password):
            return jsonify(msg="Password is incorrect"), 400

        db.session.delete(user)
        db.session.commit()

        response = jsonify(msg="Account deleted successfully")
        unset_jwt_cookies(response)
        return response, 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to delete account"), 500


@auth_bp.post('/register')
@limiter.limit("5 per minute")
def register():
    """Legacy simple register endpoint (kept for compatibility)."""
    if not request.is_json:
        abort(400)

    data = request.get_json()

    try:
        user = User(email=data['email'], username=data['username'])
        user.set_password(data['password'])

        role = _ensure_role_by_name("buyer")
        user_role = UserRole(user=user, role=role)

        db.session.add(user)
        db.session.add(user_role)
        db.session.commit()

        return jsonify(msg="Successfully registered user!"), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="An error occurred!"), 500


@auth_bp.post('/register-rider')
@limiter.limit("5 per minute")
def register_rider():
	"""Full rider registration: create User + RiderProfile.

	Expected multipart/form-data body:
	  - givenName, surname, email, password, contactNumber
	  - vehicleType, licenseNumber
	  - address: JSON string with AddressData fields
	  - license: uploaded file (image/pdf)
	  - orCr: uploaded file (image/pdf)
	"""

	form = request.form or {}
	current_app.logger.info("[register_rider] form keys=%s", list(form.keys()))
	current_app.logger.info("[register_rider] file keys=%s", list(request.files.keys()))

	try:
		email = (form.get('email') or '').strip()
		password = form.get('password') or ''
		given_name = (form.get('givenName') or '').strip()
		surname = (form.get('surname') or '').strip()
		contact_number = (form.get('contactNumber') or '').strip()
		vehicle_type = (form.get('vehicleType') or '').strip()
		license_number = (form.get('licenseNumber') or '').strip()

		address_raw = form.get('address') or '{}'
		try:
			address = json.loads(address_raw)
		except Exception:
			address = {}

		if not email or not password:
			return jsonify(msg="email and password are required"), 400
		if not vehicle_type or not license_number:
			return jsonify(msg="vehicleType and licenseNumber are required"), 400

		user = User(
			email=email,
			username=email,
			given_name=given_name,
			surname=surname,
			contact_number=contact_number,
		)
		user.set_password(password)

		role = _ensure_role_by_name("rider")
		user_role = UserRole(user=user, role=role)

		rider_profile = RiderProfile(
			region_code=address.get('regionCode', ''),
			region_name=address.get('regionName', ''),
			province_code=address.get('provinceCode', ''),
			province_name=address.get('provinceName', ''),
			municipality_code=address.get('municipalityCode', ''),
			municipality_name=address.get('municipalityName', ''),
			barangay_code=address.get('barangayCode', ''),
			barangay_name=address.get('barangayName', ''),
			street_address=address.get('streetAddress', ''),
			postal_code=address.get('postalCode', ''),
			vehicle_type=vehicle_type,
			license_number=license_number,
			user=user,
		)

		from app.utils.upload import save_upload

		def save_doc(field_name: str, prefix: str) -> str | None:
			file = request.files.get(field_name)
			if not file or not file.filename:
				return None

			if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp", "application/pdf"}:
				raise ValueError(f"Invalid file type for {field_name}")

			safe_name = secure_filename(file.filename or field_name)
			filename = f"{prefix}_{email}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"
			return save_upload(file, "rider_docs", filename=filename)

		try:
			license_path = save_doc('license', 'license')
			orcr_path = save_doc('orCr', 'orcr')
		except ValueError as e:
			db.session.rollback()
			return jsonify(msg=str(e)), 400
		except Exception:
			db.session.rollback()
			current_app.logger.exception("[register_rider] failed to save one or more documents")
			return jsonify(msg="Failed to save documents"), 500

		if license_path:
			rider_profile.license_path = license_path
		if orcr_path:
			rider_profile.orcr_path = orcr_path

		if not rider_profile.license_path or not rider_profile.orcr_path:
			return jsonify(msg="Both license and OR/CR documents are required"), 400

		db.session.add(user)
		db.session.add(user_role)
		db.session.add(rider_profile)
		db.session.commit()

		return jsonify(msg="Successfully registered rider. Awaiting admin approval."), 201
	except IntegrityError:
		db.session.rollback()
		return jsonify(msg="Email already exists!"), 400
	except ValueError as e:
		db.session.rollback()
		return jsonify(msg=str(e)), 400
	except Exception:
		db.session.rollback()
		return jsonify(msg="An error occurred!"), 500


@auth_bp.post('/register-seller')
@limiter.limit("5 per minute")
def register_seller():
    """Full seller registration: create User + Seller + StoreRegistration.

    Expected multipart/form-data body (matches SellerRegistrationData):
      - givenName, surname, email, password, contactNumber, shopName, tagline, description
      - categories: JSON string of string[]
      - address: JSON string with AddressData fields
      - logo: optional shop logo image (saved as seller avatar)
      - dti, birTin, businessPermit, validId: uploaded files (image/pdf)
    """

    # Expect multipart/form-data
    form = request.form or {}

    current_app.logger.info("[register_seller] form keys=%s", list(form.keys()))
    current_app.logger.info("[register_seller] file keys=%s", list(request.files.keys()))

    try:
        email = (form.get('email') or '').strip()
        password = form.get('password') or ''
        given_name = (form.get('givenName') or '').strip()
        surname = (form.get('surname') or '').strip()
        contact_number = (form.get('contactNumber') or '').strip()
        shop_name = (form.get('shopName') or '').strip()
        tagline = form.get('tagline') or ''
        description = form.get('description') or ''

        categories_raw = form.get('categories') or '[]'
        try:
            categories = json.loads(categories_raw) or []
        except Exception:
            categories = []

        address_raw = form.get('address') or '{}'
        try:
            address = json.loads(address_raw)
        except Exception:
            address = {}

        if not email or not password or not shop_name:
            return jsonify(msg="email, password, and shopName are required"), 400

        # Create user
        user = User(
            email=email,
            username=email,
            given_name=given_name,
            surname=surname,
            contact_number=contact_number,
        )
        user.set_password(password)

        role = _ensure_role_by_name("seller")
        user_role = UserRole(user=user, role=role)

        # Create seller profile with detailed address
        full_name = f"{given_name} {surname}".strip()
        region_code = address.get('regionCode', '')
        region_name = address.get('regionName', '')
        province_code = address.get('provinceCode', '')
        province_name = address.get('provinceName', '')
        municipality_code = address.get('municipalityCode', '')
        municipality_name = address.get('municipalityName', '')
        barangay_code = address.get('barangayCode', '')
        barangay_name = address.get('barangayName', '')
        street_address = address.get('streetAddress', '')
        postal_code = address.get('postalCode', '')

        residential_address_parts = [
            street_address,
            barangay_name,
            municipality_name,
            province_name,
        ]
        residential_address = ", ".join([p for p in residential_address_parts if p])

        seller = Seller(
            full_name=full_name or email,
            residential_address=residential_address or street_address or '',
            personal_phone_number=contact_number,
            country="Philippines",
            province=province_name,
            city=municipality_name,
            region_code=region_code,
            region_name=region_name,
            province_code=province_code,
            province_name=province_name,
            municipality_code=municipality_code,
            municipality_name=municipality_name,
            barangay_code=barangay_code,
            barangay_name=barangay_name,
            street_address=street_address,
            postal_code=postal_code,
            user=user,
        )

        from app.utils.upload import save_upload

        def save_logo() -> str | None:
            from app.utils.mime_utils import is_allowed_upload

            file = request.files.get('logo')
            if not file or not file.filename:
                return None
            if not is_allowed_upload(file.filename, file.mimetype, ("image/",)):
                raise ValueError(
                    f"Invalid file type for logo: {file.mimetype}. Allowed: JPEG, PNG, WebP"
                )
            safe_name = secure_filename(file.filename or 'logo')
            filename = f"logo_{email}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"
            return save_upload(file, "seller_avatars", filename=filename)

        def save_doc(field_name: str, folder: str, prefix: str) -> str | None:
            from app.utils.mime_utils import infer_content_type, is_allowed_upload

            file = request.files.get(field_name)
            if not file or not file.filename:
                current_app.logger.info(f"[register_seller] {field_name}: no file provided")
                return None

            inferred = infer_content_type(file.filename, file.mimetype)
            current_app.logger.info(
                "[register_seller] %s: filename=%s mimetype=%s inferred=%s",
                field_name,
                file.filename,
                file.mimetype,
                inferred,
            )

            if not is_allowed_upload(
                file.filename,
                inferred,
                ("image/", "application/pdf"),
            ):
                raise ValueError(
                    f"Invalid file type for {field_name}: {inferred}. "
                    "Allowed: PDF, JPEG, PNG, WebP, HEIC"
                )

            safe_name = secure_filename(file.filename or field_name)
            filename = f"{prefix}_{email}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"
            return save_upload(file, folder, filename=filename)

        try:
            # Save documents
            current_app.logger.info("[register_seller] Starting document save...")
            dti_path = save_doc('dti', 'seller_dti', 'dti')
            current_app.logger.info(f"[register_seller] dti_path={dti_path}")
            bir_tin_path = save_doc('birTin', 'seller_bir', 'birtin')
            current_app.logger.info(f"[register_seller] bir_tin_path={bir_tin_path}")
            business_permit_path = save_doc('businessPermit', 'seller_permits', 'permit')
            current_app.logger.info(f"[register_seller] business_permit_path={business_permit_path}")
            valid_id_path = save_doc('validId', 'seller_ids', 'seller_id')
            current_app.logger.info(f"[register_seller] valid_id_path={valid_id_path}")
            logo_path = save_logo()
            if logo_path:
                seller.avatar_path = logo_path
                current_app.logger.info(f"[register_seller] logo_path={logo_path}")

            # Validate all required documents were saved
            missing_docs = []
            if not dti_path:
                missing_docs.append("DTI")
            if not bir_tin_path:
                missing_docs.append("BIR TIN")
            if not business_permit_path:
                missing_docs.append("Business Permit")
            if not valid_id_path:
                missing_docs.append("Valid ID")

            if missing_docs:
                db.session.rollback()
                error_msg = f"Missing required documents: {', '.join(missing_docs)}"
                current_app.logger.error(f"[register_seller] {error_msg}")
                return jsonify(msg=error_msg), 400

        except ValueError as e:
            db.session.rollback()
            current_app.logger.error(f"[register_seller] ValueError: {e}")
            return jsonify(msg=str(e)), 400
        except Exception:
            db.session.rollback()
            current_app.logger.exception("[register_seller] failed to save one or more documents")
            return jsonify(msg="Failed to save documents"), 500

        seller.valid_id_path = valid_id_path

        store_registration = StoreRegistration(
            store_purpose=description or tagline or shop_name,
            shop_name=shop_name,
            tagline=tagline or None,
            categories_json=json.dumps(categories) if categories else None,
            dti_path=dti_path,
            bir_tin_path=bir_tin_path,
            business_permit_path=business_permit_path,
            user=user,
            seller=seller,
        )

        db.session.add(user)
        db.session.add(user_role)
        db.session.add(seller)
        db.session.add(store_registration)
        db.session.commit()

        return jsonify(msg="Successfully registered seller. Awaiting admin approval."), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except ValueError as e:
        db.session.rollback()
        return jsonify(msg=str(e)), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="An error occurred!"), 500


@auth_bp.post('/register-buyer')
@limiter.limit("5 per minute")
def register_buyer():
    """Full buyer registration: create User + BuyerProfile with pending verification.

    Expected multipart/form-data body:
      - givenName, surname, email, password, contactNumber (form fields)
      - address: JSON string with keys:
          { regionCode, regionName, provinceCode, provinceName,
            municipalityCode, municipalityName, barangayCode,
            barangayName, streetAddress?, postalCode? }
      - validId: uploaded file (image/pdf) for verification

    The created buyer will have email_verified = False and must be approved
    by an admin before gaining full access.
    """

    # We now expect multipart/form-data instead of raw JSON
    form = request.form or {}

    # Debug logging to inspect incoming form and files
    current_app.logger.info("[register_buyer] form keys=%s", list(form.keys()))
    current_app.logger.info("[register_buyer] file keys=%s", list(request.files.keys()))

    try:
        email = (form.get('email') or '').strip()
        password = form.get('password') or ''
        given_name = form.get('givenName', '')
        surname = form.get('surname', '')
        contact_number = form.get('contactNumber', '')

        address_raw = form.get('address') or '{}'
        try:
            address = json.loads(address_raw)
        except Exception:
            address = {}

        # Create user
        user = User(
            email=email,
            username=email,
            given_name=given_name,
            surname=surname,
            contact_number=contact_number,
        )
        user.set_password(password)

        role = _ensure_role_by_name("buyer")
        user_role = UserRole(user=user, role=role)

        # Create buyer profile
        buyer_profile = BuyerProfile(
            region_code=address.get('regionCode', ''),
            region_name=address.get('regionName', ''),
            province_code=address.get('provinceCode', ''),
            province_name=address.get('provinceName', ''),
            municipality_code=address.get('municipalityCode', ''),
            municipality_name=address.get('municipalityName', ''),
            barangay_code=address.get('barangayCode', ''),
            barangay_name=address.get('barangayName', ''),
            street_address=address.get('streetAddress', ''),
            postal_code=address.get('postalCode', ''),
            user=user,
        )

        # Handle optional valid ID upload
        file = request.files.get('validId')
        if file and file.filename:
            # Basic file type check (allow common image types and PDF)
            if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp", "application/pdf"}:
                return jsonify(msg="Invalid file type for valid ID"), 400

            from app.utils.upload import save_upload

            safe_name = secure_filename(file.filename or 'valid_id')
            filename = f"buyer_{email}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"

            try:
                buyer_profile.valid_id_path = save_upload(
                    file, "buyer_ids", filename=filename
                )
                current_app.logger.info(
                    "[register_buyer] saved valid ID for email=%s to path=%s",
                    email,
                    buyer_profile.valid_id_path,
                )
            except Exception:
                db.session.rollback()
                current_app.logger.exception("[register_buyer] failed to save valid ID file")
                return jsonify(msg="Failed to save valid ID"), 500

        db.session.add(user)
        db.session.add(user_role)
        db.session.add(buyer_profile)
        db.session.commit()

        return jsonify(msg="Successfully registered buyer. Awaiting admin approval."), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="An error occurred!"), 500
    
@auth_bp.get('/protected')
@jwt_required()
def protected():
    user = db.session.execute(
        select(User).where(User.id == current_user.id)
    ).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    csrf_token = get_csrf_token(
        create_access_token(identity=user.id, additional_claims=_build_jwt_claims(user))
    )
    return jsonify(**_session_snapshot(user), csrf_token=csrf_token), 200


def _serialize_buyer_profile(user, buyer_profile=None):
    """Build buyer profile JSON; empty address when profile row is missing."""
    from app.utils.upload import public_url_for_stored_path

    avatar_url = None
    if buyer_profile is not None and buyer_profile.avatar_path:
        avatar_url = public_url_for_stored_path(buyer_profile.avatar_path)
    bp = buyer_profile
    return {
        "givenName": user.given_name or "",
        "surname": user.surname or "",
        "email": user.email,
        "contactNumber": user.contact_number or "",
        "isVerified": user.email_verified,
        "avatarUrl": avatar_url,
        "address": {
            "regionCode": (bp.region_code if bp else None) or "",
            "regionName": (bp.region_name if bp else None) or "",
            "provinceCode": (bp.province_code if bp else None) or "",
            "provinceName": (bp.province_name if bp else None) or "",
            "municipalityCode": (bp.municipality_code if bp else None) or "",
            "municipalityName": (bp.municipality_name if bp else None) or "",
            "barangayCode": (bp.barangay_code if bp else None) or "",
            "barangayName": (bp.barangay_name if bp else None) or "",
            "streetAddress": (bp.street_address if bp else None) or "",
            "postalCode": (bp.postal_code if bp else None) or "",
        },
    }


@auth_bp.get('/buyer/profile')
@jwt_required()
@buyer_required()
def get_buyer_profile():
    """Return the currently authenticated buyer's profile and address data."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg="User not found"), 404

    buyer_profile = user.buyer_profile
    profile = _serialize_buyer_profile(user, buyer_profile)
    return jsonify(profile=profile), 200


@auth_bp.put('/buyer/profile')
@jwt_required()
@buyer_required()
def update_buyer_profile():
    """Update buyer name, contact, and optional registration address."""
    if not request.is_json:
        abort(400)

    data = request.get_json() or {}
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    buyer_profile = user.buyer_profile
    if buyer_profile is None:
        buyer_profile = BuyerProfile(user_id=user.id)
        db.session.add(buyer_profile)

    try:
        if data.get('givenName') is not None:
            user.given_name = str(data['givenName']).strip()
        if data.get('surname') is not None:
            user.surname = str(data['surname']).strip()
        if data.get('contactNumber') is not None:
            user.contact_number = str(data['contactNumber']).strip()
        if data.get('email') is not None:
            user.email = str(data['email']).strip()
            user.username = user.email

        addr = data.get('address')
        if isinstance(addr, dict):
            for key, attr in (
                ('regionCode', 'region_code'),
                ('regionName', 'region_name'),
                ('provinceCode', 'province_code'),
                ('provinceName', 'province_name'),
                ('municipalityCode', 'municipality_code'),
                ('municipalityName', 'municipality_name'),
                ('barangayCode', 'barangay_code'),
                ('barangayName', 'barangay_name'),
                ('streetAddress', 'street_address'),
                ('postalCode', 'postal_code'),
            ):
                if addr.get(key) is not None:
                    setattr(buyer_profile, attr, str(addr[key]).strip())

        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to update profile"), 500

    return get_buyer_profile()


@auth_bp.get('/buyer/reviews')
@jwt_required()
@buyer_required()
def list_buyer_reviews():
    """Paginated list of reviews written by the current buyer."""
    from app.review_utils import serialize_review_row

    page = max(1, int(request.args.get('page', 1)))
    per_page = min(50, max(1, int(request.args.get('per_page', 20))))

    base = (
        select(Review, Product, OrderItem, Order)
        .outerjoin(Product, Review.product_id == Product.id)
        .join(OrderItem, Review.order_item_id == OrderItem.id)
        .join(Order, OrderItem.order_id == Order.id)
        .where(Review.buyer_id == current_user.id)
        .order_by(Review.created_at.desc())
    )

    rows = db.session.execute(
        base.offset((page - 1) * per_page).limit(per_page)
    ).all()

    from sqlalchemy import func

    total = db.session.execute(
        select(func.count()).select_from(Review).where(
            Review.buyer_id == current_user.id
        )
    ).scalar() or 0

    reviews = [
        serialize_review_row(review, _public_image_url, product, None, order_item)
        for review, product, order_item, _order in rows
    ]

    return jsonify(reviews=reviews, total=int(total), page=page, perPage=per_page), 200


def _build_rider_profile_payload(user: User, rider_profile: RiderProfile) -> dict:
    from app.utils.upload import public_url_for_stored_path

    avatar_url = None
    if rider_profile.avatar_path:
        avatar_url = public_url_for_stored_path(rider_profile.avatar_path)
    return {
        "givenName": user.given_name or "",
        "surname": user.surname or "",
        "email": user.email,
        "contactNumber": user.contact_number or "",
        "isVerified": user.email_verified,
        "avatarUrl": avatar_url,
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
            "license": rider_profile.license_path,
            "orCr": rider_profile.orcr_path,
        },
    }


@auth_bp.get('/rider/profile')
@jwt_required()
@rider_required()
def get_rider_profile():
    """Return the currently authenticated rider's profile (read allowed while pending)."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg="User not found"), 404

    rider_profile = user.rider_profile

    if rider_profile is None:
        return jsonify(msg="Rider profile not found"), 404

    profile = _build_rider_profile_payload(user, rider_profile)

    return jsonify(profile=profile), 200


@auth_bp.put('/rider/profile')
@jwt_required()
@rider_required()
def update_rider_profile():
    """Update the currently authenticated rider's basic profile information.

    Expects JSON body with optional fields:
      - givenName
      - surname
      - email
      - contactNumber
      - vehicleType
      - licenseNumber

    Returns the updated rider profile in the same shape as GET /rider/profile.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg="User not found"), 404

    # Enforce verification for rider profile updates
    if not user.email_verified:
        return jsonify(msg="Rider account is not yet verified/approved"), 403

    rider_profile = user.rider_profile

    if rider_profile is None:
        return jsonify(msg="Rider profile not found"), 404

    try:
        given_name = data.get('givenName')
        surname = data.get('surname')
        email = data.get('email')
        contact_number = data.get('contactNumber')
        vehicle_type = data.get('vehicleType')
        license_number = data.get('licenseNumber')

        if email is not None:
            user.email = email.strip()
            user.username = user.email
        if given_name is not None:
            user.given_name = given_name.strip()
        if surname is not None:
            user.surname = surname.strip()
        if contact_number is not None:
            user.contact_number = contact_number.strip()

        if vehicle_type is not None:
            rider_profile.vehicle_type = vehicle_type.strip()
        if license_number is not None:
            rider_profile.license_number = license_number.strip()

        addr = data.get('address')
        if isinstance(addr, dict):
            for key, attr in (
                ('regionCode', 'region_code'),
                ('regionName', 'region_name'),
                ('provinceCode', 'province_code'),
                ('provinceName', 'province_name'),
                ('municipalityCode', 'municipality_code'),
                ('municipalityName', 'municipality_name'),
                ('barangayCode', 'barangay_code'),
                ('barangayName', 'barangay_name'),
                ('streetAddress', 'street_address'),
                ('postalCode', 'postal_code'),
            ):
                if addr.get(key) is not None:
                    setattr(rider_profile, attr, str(addr[key]).strip())

        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to update rider profile"), 500

    profile = _build_rider_profile_payload(user, rider_profile)

    return jsonify(profile=profile), 200


@auth_bp.post('/rider/documents')
@jwt_required()
@rider_required()
def upload_rider_documents():
    """Re-upload rider license and/or OR/CR (verified riders only)."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()

    if user is None:
        return jsonify(msg="User not found"), 404

    if not user.email_verified:
        return jsonify(msg="Rider account is not yet verified/approved"), 403

    rider_profile = user.rider_profile
    if rider_profile is None:
        return jsonify(msg="Rider profile not found"), 404

    from app.utils.upload import save_upload

    def save_doc(field_name: str, prefix: str) -> str | None:
        file = request.files.get(field_name)
        if not file or not file.filename:
            return None
        if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp", "application/pdf"}:
            raise ValueError(f"Invalid file type for {field_name}")
        safe_name = secure_filename(file.filename or field_name)
        filename = f"{prefix}_{user.id}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"
        return save_upload(file, "rider_docs", filename=filename)

    try:
        license_path = save_doc('license', 'license')
        orcr_path = save_doc('orCr', 'orcr')
        if license_path:
            rider_profile.license_path = license_path
        if orcr_path:
            rider_profile.orcr_path = orcr_path
        if not license_path and not orcr_path:
            return jsonify(msg="At least one document file is required"), 400
        db.session.commit()
    except ValueError as e:
        db.session.rollback()
        return jsonify(msg=str(e)), 400
    except Exception:
        db.session.rollback()
        current_app.logger.exception("[upload_rider_documents] failed")
        return jsonify(msg="Failed to upload documents"), 500

    profile = _build_rider_profile_payload(user, rider_profile)
    return jsonify(profile=profile), 200


@auth_bp.put('/seller/profile')
@jwt_required()
@seller_required()
def update_seller_profile():
    """Update the currently authenticated seller's basic profile information.

    Expects JSON body with optional fields:
      - givenName
      - surname
      - email
      - contactNumber

    Returns the updated seller profile in the same shape as GET /seller/profile.
    """

    if not request.is_json:
        abort(400)

    data = request.get_json() or {}

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    # Load seller and registration to return updated profile
    seller = db.session.execute(
        select(Seller).where(Seller.user_id == user.id)
    ).scalar_one_or_none()

    if seller is None:
        return jsonify(msg="Seller profile not found"), 404

    registration = db.session.execute(
        select(StoreRegistration).where(StoreRegistration.user_id == user.id)
    ).scalar_one_or_none()

    try:
        given_name = data.get('givenName')
        surname = data.get('surname')
        email = data.get('email')
        contact_number = data.get('contactNumber')

        # Optional shop fields
        shop_name = data.get('shopName')
        tagline = data.get('tagline')
        description = data.get('description')
        categories = data.get('categories')

        # --- Update basic user fields ---
        if email is not None:
            user.email = email.strip()
            user.username = user.email
        if given_name is not None:
            user.given_name = given_name.strip()
        if surname is not None:
            user.surname = surname.strip()
        if contact_number is not None:
            user.contact_number = contact_number.strip()

        # --- Update store registration (shop settings) if present ---
        if registration is not None:
            if shop_name is not None:
                registration.shop_name = shop_name.strip() or None
            if tagline is not None:
                # Allow clearing tagline with empty string
                registration.tagline = tagline.strip() or None
            if description is not None:
                registration.store_purpose = description.strip() or ""

            if categories is not None:
                # Expect a JSON-serializable list of category ids/labels from frontend
                try:
                    if isinstance(categories, str):
                        parsed_categories = json.loads(categories) or []
                    else:
                        parsed_categories = list(categories) if categories is not None else []
                except Exception:
                    parsed_categories = []

                registration.categories_json = json.dumps(parsed_categories) if parsed_categories else None

        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return jsonify(msg="Email already exists!"), 400
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to update seller profile"), 500

    # Parse categories from JSON, if present, to mirror GET /seller/profile
    categories_list: list[str] = []
    if registration and registration.categories_json:
        try:
            categories_list = json.loads(registration.categories_json) or []
        except Exception:
            categories_list = []

    from app.utils.upload import public_url_for_stored_path

    avatar_url = public_url_for_stored_path(seller.avatar_path) if seller.avatar_path else None
    banner_url = (
        public_url_for_stored_path(seller.banner_path)
        if getattr(seller, "banner_path", None)
        else None
    )

    # Calculate total sales from completed orders
    total_sales = 0.0
    try:
        # Get the seller's store
        store = db.session.execute(
            select(Store).where(Store.seller_id == seller.id)
        ).scalar_one_or_none()
        
        if store:
            # Calculate total sales from completed/delivered orders
            sales_result = db.session.execute(
                select(db.func.sum(Order.total_amount))
                .where(
                    Order.store_id == store.id,
                    Order.status.in_([OrderStatus.DELIVERED, OrderStatus.COMPLETED])
                )
            ).scalar()
            total_sales = float(sales_result) if sales_result else 0.0
    except Exception:
        total_sales = 0.0

    profile = {
        "givenName": user.given_name or "",
        "surname": user.surname or "",
        "email": user.email,
        "contactNumber": user.contact_number or "",
        "role": "seller",
        "isVerified": user.email_verified,
        "shopName": (registration.shop_name if registration else None) or "",
        "tagline": registration.tagline if registration else None,
        "description": (registration.store_purpose if registration else None) or "",
        "categories": categories_list,
        "avatarUrl": avatar_url,
        "bannerUrl": banner_url,
        "rating": 0,
        "totalSales": total_sales,
        "address": {
            "regionCode": seller.region_code or "",
            "regionName": seller.region_name or "",
            "provinceCode": seller.province_code or "",
            "provinceName": seller.province_name or "",
            "municipalityCode": seller.municipality_code or "",
            "municipalityName": seller.municipality_name or "",
            "barangayCode": seller.barangay_code or "",
            "barangayName": seller.barangay_name or "",
            "streetAddress": seller.street_address or "",
            "postalCode": seller.postal_code or "",
        },
        "documents": {
            "dti": registration.dti_path if registration else None,
            "birTin": registration.bir_tin_path if registration else None,
            "businessPermit": registration.business_permit_path if registration else None,
            "validId": seller.valid_id_path,
        },
    }

    return jsonify(profile=profile), 200


@auth_bp.post('/buyer/avatar')
@jwt_required()
@buyer_required()
def upload_buyer_avatar():
    """Upload and save a buyer avatar image for the current user."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    buyer_profile = user.buyer_profile
    if buyer_profile is None:
        return jsonify(msg="Buyer profile not found"), 404

    file = request.files.get('avatar')
    if not file:
        return jsonify(msg="No file uploaded"), 400

    if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp"}:
        return jsonify(msg="Invalid file type"), 400

    from app.utils.upload import public_url_for_stored_path, save_upload

    safe_name = secure_filename(file.filename or 'avatar')
    filename = f"buyer_{user.id}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"

    try:
        buyer_profile.avatar_path = save_upload(file, "avatars", filename=filename)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to save avatar"), 500

    avatar_url = public_url_for_stored_path(buyer_profile.avatar_path)
    return jsonify(avatarUrl=avatar_url), 200


@auth_bp.post('/rider/avatar')
@jwt_required()
@rider_required()
def upload_rider_avatar():
    """Upload and save a rider avatar image for the current user."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    rider_profile = user.rider_profile
    if rider_profile is None:
        return jsonify(msg="Rider profile not found"), 404

    file = request.files.get('avatar')
    if not file:
        return jsonify(msg="No file uploaded"), 400

    if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp"}:
        return jsonify(msg="Invalid file type"), 400

    from app.utils.upload import public_url_for_stored_path, save_upload

    safe_name = secure_filename(file.filename or 'avatar')
    filename = f"rider_{user.id}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"

    try:
        rider_profile.avatar_path = save_upload(file, "rider_avatars", filename=filename)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to save avatar"), 500

    avatar_url = public_url_for_stored_path(rider_profile.avatar_path)
    return jsonify(avatarUrl=avatar_url), 200


@auth_bp.post('/seller/avatar')
@jwt_required()
@seller_required()
def upload_seller_avatar():
    """Upload and save a seller avatar (shop logo) image for the current user."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    seller = db.session.execute(select(Seller).where(Seller.user_id == user.id)).scalar_one_or_none()
    if seller is None:
        return jsonify(msg="Seller profile not found"), 404

    file = request.files.get('avatar')
    if not file:
        return jsonify(msg="No file uploaded"), 400

    if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp"}:
        return jsonify(msg="Invalid file type"), 400

    from app.utils.upload import public_url_for_stored_path, save_upload

    safe_name = secure_filename(file.filename or 'avatar')
    filename = f"seller_{user.id}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"

    try:
        seller.avatar_path = save_upload(file, "seller_avatars", filename=filename)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to save avatar"), 500

    avatar_url = public_url_for_stored_path(seller.avatar_path)
    return jsonify(avatarUrl=avatar_url), 200


@auth_bp.post('/seller/banner')
@jwt_required()
@seller_required()
def upload_seller_banner():
    """Upload a seller shop banner image for the current user.

    The banner path is not persisted in the database yet; the endpoint
    returns a direct URL to the uploaded banner so the frontend can use it.
    """

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    seller = db.session.execute(select(Seller).where(Seller.user_id == user.id)).scalar_one_or_none()
    if seller is None:
        return jsonify(msg="Seller profile not found"), 404

    file = request.files.get('banner')
    if not file:
        return jsonify(msg="No file uploaded"), 400

    if file.mimetype not in {"image/jpeg", "image/png", "image/jpg", "image/webp"}:
        return jsonify(msg="Invalid file type"), 400

    from app.utils.upload import public_url_for_stored_path, save_upload

    safe_name = secure_filename(file.filename or 'banner')
    filename = f"seller_banner_{user.id}_{int(datetime.now(timezone.utc).timestamp())}_{safe_name}"

    try:
        seller.banner_path = save_upload(file, "seller_banners", filename=filename)
        db.session.commit()
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to save banner"), 500

    banner_url = public_url_for_stored_path(seller.banner_path)
    return jsonify(bannerUrl=banner_url), 200


@auth_bp.get('/seller/profile')
@jwt_required()
@seller_required()
def get_seller_profile():
    """Return the currently authenticated seller's profile and shop data.

    Response is shaped similarly to the frontend SellerProfile type.
    """

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    seller = db.session.execute(
        select(Seller).where(Seller.user_id == user.id)
    ).scalar_one_or_none()

    if seller is None:
        return jsonify(msg="Seller profile not found"), 404

    registration = db.session.execute(
        select(StoreRegistration).where(StoreRegistration.user_id == user.id)
    ).scalar_one_or_none()

    # Parse categories from JSON, if present
    categories: list[str] = []
    if registration and registration.categories_json:
        try:
            categories = json.loads(registration.categories_json) or []
        except Exception:
            categories = []

    from app.utils.upload import public_url_for_stored_path

    avatar_url = public_url_for_stored_path(seller.avatar_path) if seller.avatar_path else None
    banner_url = (
        public_url_for_stored_path(seller.banner_path)
        if getattr(seller, "banner_path", None)
        else None
    )

    # Calculate total sales from completed orders
    total_sales = 0.0
    try:
        # Get the seller's store
        store = db.session.execute(
            select(Store).where(Store.seller_id == seller.id)
        ).scalar_one_or_none()
        
        if store:
            # Calculate total sales from completed/delivered orders
            sales_result = db.session.execute(
                select(db.func.sum(Order.total_amount))
                .where(
                    Order.store_id == store.id,
                    Order.status.in_([OrderStatus.DELIVERED, OrderStatus.COMPLETED])
                )
            ).scalar()
            total_sales = float(sales_result) if sales_result else 0.0
    except Exception:
        total_sales = 0.0

    store_id_val = None
    avg_rating = 0.0
    try:
        if store:
            store_id_val = store.id
            from app.models import Review, Product
            from app.review_utils import public_review_filter

            rating_rows = db.session.execute(
                select(Review.rating)
                .join(Product, Review.product_id == Product.id)
                .where(Product.store_id == store.id, *public_review_filter())
            ).all()
            ratings = [int(r[0] or 0) for r in rating_rows if r[0]]
            if ratings:
                avg_rating = round(sum(ratings) / len(ratings), 1)
    except Exception:
        avg_rating = 0.0

    # Determine verification status based on store registration for sellers
    is_verified = user.email_verified
    if registration:
        is_verified = registration.request_status.name == StoreRequestStatus.ACCEPTED.name

    profile = {
        "id": user.id,
        "userId": user.id,
        "givenName": user.given_name or "",
        "surname": user.surname or "",
        "email": user.email,
        "contactNumber": user.contact_number or "",
        "role": "seller",
        "isVerified": is_verified,
        "shopName": (registration.shop_name if registration else None) or "",
        "tagline": registration.tagline if registration else None,
        "description": (registration.store_purpose if registration else None) or "",
        "categories": categories,
        "avatarUrl": avatar_url,
        "bannerUrl": banner_url,
        "rating": avg_rating,
        "totalSales": total_sales,
        "storeId": store_id_val,
        "storeStatus": registration.request_status.name if registration else None,
        "address": {
            "regionCode": seller.region_code or "",
            "regionName": seller.region_name or "",
            "provinceCode": seller.province_code or "",
            "provinceName": seller.province_name or "",
            "municipalityCode": seller.municipality_code or "",
            "municipalityName": seller.municipality_name or "",
            "barangayCode": seller.barangay_code or "",
            "barangayName": seller.barangay_name or "",
            "streetAddress": seller.street_address or "",
            "postalCode": seller.postal_code or "",
        },
        "documents": {
            "dti": registration.dti_path if registration else None,
            "birTin": registration.bir_tin_path if registration else None,
            "businessPermit": registration.business_permit_path if registration else None,
            "validId": seller.valid_id_path,
        },
    }

    return jsonify(profile=profile), 200


def _serialize_wishlist_product(product: Product) -> dict:
    images: list[str] = []
    if product.image_url:
        url = _public_image_url(product.image_url)
        if url:
            images.append(url)
    for media in getattr(product, "media", []) or []:
        if media.media_type == "image" and media.path:
            url = _public_image_url(media.path)
            if url and url not in images:
                images.append(url)

    slug = getattr(product, "slug", None) or str(product.id)
    sale = product.sale_price

    return {
        "id": product.id,
        "slug": slug,
        "name": product.name,
        "images": images,
        "image_url": images[0] if images else None,
        "price": float(product.price or 0),
        "sale_price": float(sale) if sale is not None else None,
        "salePrice": float(sale) if sale is not None else None,
        "store_id": product.store_id,
        "sellerId": str(product.store_id),
        "categories": [],
        "description": product.description or "",
        "variations": [],
        "category": getattr(product, "subcategory", None) or "",
        "rating": float(getattr(product, "rating", 0) or 0),
        "review_count": int(getattr(product, "review_count", 0) or 0),
        "reviewCount": int(getattr(product, "review_count", 0) or 0),
        "visibility": bool(getattr(product, "is_live", True)),
        "created_at": product.created_at.isoformat() if product.created_at else None,
        "createdAt": product.created_at.isoformat() if product.created_at else None,
        "updated_at": (
            product.updated_at.isoformat()
            if product.updated_at
            else (product.created_at.isoformat() if product.created_at else None)
        ),
        "updatedAt": (
            product.updated_at.isoformat()
            if product.updated_at
            else (product.created_at.isoformat() if product.created_at else None)
        ),
    }


@auth_bp.get('/buyer/wishlist')
@jwt_required()
@buyer_required()
def get_buyer_wishlist():
    """Return the current buyer's wishlist products."""

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    items = db.session.execute(
        select(WishlistItem)
        .where(WishlistItem.user_id == user.id)
        .options(
            selectinload(WishlistItem.product).selectinload(Product.media),
        )
    ).scalars().all()

    products_json = [
        _serialize_wishlist_product(item.product)
        for item in items
        if item.product is not None
    ]

    return jsonify(products=products_json), 200


@auth_bp.post('/buyer/wishlist')
@jwt_required()
@buyer_required()
def add_to_wishlist():
    data = request.get_json() or {}
    product_id = data.get('productId')

    if not product_id:
        return jsonify(msg="productId is required"), 400

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    product = db.session.execute(select(Product).where(Product.id == product_id)).scalar_one_or_none()
    if product is None:
        return jsonify(msg="Product not found"), 404

    existing = db.session.execute(
        select(WishlistItem).where(
            WishlistItem.user_id == user.id,
            WishlistItem.product_id == product.id,
        )
    ).scalar_one_or_none()

    if existing:
        return jsonify(msg="Already in wishlist"), 200

    try:
        item = WishlistItem(user_id=user.id, product_id=product.id)
        db.session.add(item)
        db.session.commit()
        return jsonify(msg="Added to wishlist"), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to add to wishlist"), 500


@auth_bp.delete('/buyer/wishlist')
@jwt_required()
@buyer_required()
def clear_buyer_wishlist():
    """Remove all wishlist items for the current buyer."""
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    try:
        for item in db.session.execute(
            select(WishlistItem).where(WishlistItem.user_id == user.id)
        ).scalars().all():
            db.session.delete(item)
        db.session.commit()
        return jsonify(msg="Wishlist cleared"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to clear wishlist"), 500


@auth_bp.delete('/buyer/wishlist/<int:product_id>')
@jwt_required()
@buyer_required()
def remove_from_wishlist(product_id):
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    item = db.session.execute(
        select(WishlistItem).where(
            WishlistItem.user_id == user.id,
            WishlistItem.product_id == product_id,
        )
    ).scalar_one_or_none()

    if item is None:
        return jsonify(msg="Not in wishlist"), 404

    try:
        db.session.delete(item)
        db.session.commit()
        return jsonify(msg="Removed from wishlist"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to remove from wishlist"), 500


_RECENTLY_VIEWED_MAX = 30


def _trim_recently_viewed(user_id: int) -> None:
    rows = db.session.execute(
        select(RecentlyViewedProduct.id)
        .where(RecentlyViewedProduct.user_id == user_id)
        .order_by(RecentlyViewedProduct.viewed_at.desc())
    ).scalars().all()
    if len(rows) <= _RECENTLY_VIEWED_MAX:
        return
    excess_ids = rows[_RECENTLY_VIEWED_MAX:]
    db.session.execute(
        delete(RecentlyViewedProduct).where(RecentlyViewedProduct.id.in_(excess_ids))
    )


@auth_bp.get('/buyer/following-stores')
@jwt_required()
@buyer_required()
def get_following_stores():
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    rows = db.session.execute(
        select(Store, StoreFollow.created_at)
        .join(StoreFollow, StoreFollow.store_id == Store.id)
        .where(StoreFollow.user_id == user.id)
        .order_by(StoreFollow.created_at.desc())
    ).all()

    stores_payload = []
    for store, followed_at in rows:
        card = _serialize_store_card(store)
        card["followedAt"] = followed_at.isoformat() if followed_at else None
        card["storeId"] = store.id
        card["logoUrl"] = card.get("logo_url") or card.get("image_url")
        stores_payload.append(card)

    return jsonify(stores=stores_payload), 200


@auth_bp.get('/buyer/following-stores/<int:store_id>')
@jwt_required()
@buyer_required()
def get_following_store_status(store_id: int):
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    existing = db.session.execute(
        select(StoreFollow).where(
            StoreFollow.user_id == user.id,
            StoreFollow.store_id == store_id,
        )
    ).scalar_one_or_none()

    return jsonify(following=existing is not None), 200


@auth_bp.post('/buyer/following-stores')
@jwt_required()
@buyer_required()
def follow_store():
    data = request.get_json() or {}
    store_id = data.get('storeId')

    if not store_id:
        return jsonify(msg="storeId is required"), 400

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    store = db.session.execute(select(Store).where(Store.id == store_id)).scalar_one_or_none()
    if store is None:
        return jsonify(msg="Store not found"), 404

    existing = db.session.execute(
        select(StoreFollow).where(
            StoreFollow.user_id == user.id,
            StoreFollow.store_id == store.id,
        )
    ).scalar_one_or_none()

    if existing:
        return jsonify(msg="Already following store"), 200

    try:
        db.session.add(StoreFollow(user_id=user.id, store_id=store.id))
        db.session.commit()
        return jsonify(msg="Now following store"), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to follow store"), 500


@auth_bp.delete('/buyer/following-stores/<int:store_id>')
@jwt_required()
@buyer_required()
def unfollow_store(store_id: int):
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    item = db.session.execute(
        select(StoreFollow).where(
            StoreFollow.user_id == user.id,
            StoreFollow.store_id == store_id,
        )
    ).scalar_one_or_none()

    if item is None:
        return jsonify(msg="Not following store"), 404

    try:
        db.session.delete(item)
        db.session.commit()
        return jsonify(msg="Unfollowed store"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to unfollow store"), 500


@auth_bp.get('/buyer/recently-viewed')
@jwt_required()
@buyer_required()
def get_recently_viewed():
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    rows = db.session.execute(
        select(RecentlyViewedProduct)
        .where(RecentlyViewedProduct.user_id == user.id)
        .order_by(RecentlyViewedProduct.viewed_at.desc())
        .limit(_RECENTLY_VIEWED_MAX)
        .options(selectinload(RecentlyViewedProduct.product).selectinload(Product.media))
    ).scalars().all()

    products_json = [
        {
            **_serialize_wishlist_product(row.product),
            "viewedAt": row.viewed_at.isoformat() if row.viewed_at else None,
            "viewed_at": row.viewed_at.isoformat() if row.viewed_at else None,
        }
        for row in rows
        if row.product is not None
    ]

    return jsonify(products=products_json), 200


@auth_bp.delete('/buyer/recently-viewed')
@jwt_required()
@buyer_required()
def clear_recently_viewed():
    """Clear all recently viewed products for the current buyer."""
    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    try:
        for row in db.session.execute(
            select(RecentlyViewedProduct).where(RecentlyViewedProduct.user_id == user.id)
        ).scalars().all():
            db.session.delete(row)
        db.session.commit()
        return jsonify(msg="Recently viewed cleared"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to clear recently viewed"), 500


@auth_bp.post('/buyer/recently-viewed')
@jwt_required()
@buyer_required()
def record_recently_viewed():
    data = request.get_json() or {}
    product_id = data.get('productId')

    if not product_id:
        return jsonify(msg="productId is required"), 400

    user = db.session.execute(select(User).where(User.id == current_user.id)).scalar_one_or_none()
    if user is None:
        return jsonify(msg="User not found"), 404

    product = db.session.execute(select(Product).where(Product.id == product_id)).scalar_one_or_none()
    if product is None:
        return jsonify(msg="Product not found"), 404

    now = datetime.now()
    existing = db.session.execute(
        select(RecentlyViewedProduct).where(
            RecentlyViewedProduct.user_id == user.id,
            RecentlyViewedProduct.product_id == product.id,
        )
    ).scalar_one_or_none()

    try:
        if existing:
            existing.viewed_at = now
        else:
            db.session.add(
                RecentlyViewedProduct(
                    user_id=user.id,
                    product_id=product.id,
                    viewed_at=now,
                )
            )
        db.session.flush()
        _trim_recently_viewed(user.id)
        db.session.commit()
        return jsonify(msg="Recorded view"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to record view"), 500


def _notify_admins_problem_report(report: ProblemReport) -> None:
    admin_role = db.session.execute(select(Role).where(Role.id == RoleTypes.ADMIN.value)).scalar_one_or_none()
    if not admin_role:
        admin = get_platform_admin_user()
        if admin:
            notify_admin_order_issue_reported(
                admin_user_id=admin.id,
                order_id=report.order_id or 0,
            )
        return

    admins = db.session.execute(
        select(User)
        .join(UserRole, UserRole.user_id == User.id)
        .where(UserRole.role_id == admin_role.id, User.active.is_(True))
    ).scalars().all()

    title_map = {
        "app": "App issue reported",
        "store": "Store reported",
        "rider": "Rider issue reported",
    }
    for admin in admins:
        create_notification(
            user_id=admin.id,
            role="admin",
            title=title_map.get(report.category, "Problem reported"),
            message=report.description[:200],
            page="/admin/problem-reports",
            category="support",
            data={
                "reportId": report.id,
                "category": report.category,
                "storeId": report.store_id,
                "orderId": report.order_id,
            },
        )


@auth_bp.get('/buyer/coupons')
@jwt_required()
@buyer_required()
def get_buyer_coupons():
    store_id = request.args.get('storeId', type=int)
    now = datetime.now()

    stmt = select(Coupon).where(Coupon.is_active.is_(True))
    if store_id:
        stmt = stmt.where(
            (Coupon.scope == 'platform')
            | ((Coupon.scope == 'store') & (Coupon.store_id == store_id))
        )

    coupons = db.session.execute(stmt.order_by(Coupon.created_at.desc())).scalars().all()
    active = [
        serialize_coupon(c)
        for c in coupons
        if (not c.expires_at or c.expires_at >= now)
        and (c.max_uses is None or c.used_count < c.max_uses)
    ]
    return jsonify(coupons=active), 200


@auth_bp.post('/buyer/coupons/validate')
@jwt_required()
@buyer_required()
def validate_buyer_coupon():
    data = request.get_json() or {}
    code = data.get('code') or data.get('couponCode')
    store_id = data.get('storeId')
    subtotal = float(data.get('subtotal') or 0)

    coupon, discount, message = validate_coupon(
        code=code,
        user_id=current_user.id,
        store_id=int(store_id) if store_id else None,
        subtotal=subtotal,
    )
    if coupon is None:
        return jsonify(valid=False, discount=0, message=message), 200

    return jsonify(
        valid=True,
        discount=discount,
        message=message,
        coupon=serialize_coupon(coupon),
    ), 200


@auth_bp.post('/buyer/reports')
@jwt_required()
@buyer_required()
def submit_buyer_report():
    """Deprecated — use POST /api/reports instead."""
    return jsonify(
        msg="This endpoint is deprecated. Please use POST /api/reports with reportTypeId and target context.",
    ), 410


PIN_LENGTH = 6
PIN_EXPIRY_MINUTES = 15
MAX_PIN_ATTEMPTS = 5
_GENERIC_RESET_MSG = (
    "If an account exists for that email, a 6-digit code has been sent."
)


def _generate_pin() -> str:
    return "".join(str(secrets.randbelow(10)) for _ in range(PIN_LENGTH))


def _normalize_phone(value: str) -> str:
    """Digits only, for matching stored contact numbers."""
    return "".join(c for c in (value or "") if c.isdigit())


def _find_user_by_email_or_username(identifier: str):
    identifier = (identifier or "").strip()
    if not identifier:
        return None
    lowered = identifier.lower()
    return db.session.execute(
        select(User).where(
            or_(
                func.lower(User.email) == lowered,
                User.username == identifier,
            )
        )
    ).scalar_one_or_none()


def _find_user_by_contact_number(contact_number: str):
    norm = _normalize_phone(contact_number)
    if len(norm) < 7:
        return None
    candidates = db.session.execute(
        select(User).where(User.contact_number.isnot(None))
    ).scalars().all()
    for user in candidates:
        stored = _normalize_phone(user.contact_number or "")
        if not stored:
            continue
        if stored == norm or stored.endswith(norm) or norm.endswith(stored):
            return user
    return None


def _invalidate_reset_codes(user_id: int) -> None:
    db.session.execute(
        delete(PasswordResetCode).where(PasswordResetCode.user_id == user_id)
    )


def _get_active_reset_code(user_id: int):
    now = datetime.now(timezone.utc)
    return db.session.execute(
        select(PasswordResetCode)
        .where(PasswordResetCode.user_id == user_id)
        .order_by(PasswordResetCode.created_at.desc())
    ).scalars().first()


@auth_bp.post("/forgot-password/contact-lookup")
@limiter.limit("10 per minute")
def forgot_password_contact_lookup():
    """Return saved contact number for an account email (for SMS prefill)."""
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    email = (data.get("email") or data.get("username") or "").strip().lower()
    if not email:
        return jsonify(msg="Email is required"), 400

    user = _find_user_by_email_or_username(email)
    if user is None or not user.contact_number:
        return jsonify(contactNumber=None), 200

    return jsonify(contactNumber=user.contact_number), 200


@auth_bp.post("/forgot-password")
@limiter.limit("5 per minute")
def forgot_password():
    """Request a 6-digit reset PIN via email or SMS."""
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    email = (data.get("email") or data.get("username") or "").strip().lower()
    contact_number = (
        data.get("contactNumber") or data.get("contact_number") or ""
    ).strip()
    channel = (data.get("channel") or "email").strip().lower()

    if channel not in ("email", "sms"):
        return jsonify(msg="channel must be 'email' or 'sms'"), 400

    if channel == "sms":
        if not contact_number:
            return jsonify(msg="Contact number is required"), 400
        user = _find_user_by_contact_number(contact_number)
        if user is None and email:
            user = _find_user_by_email_or_username(email)
    else:
        if not email:
            return jsonify(msg="Email is required"), 400
        user = _find_user_by_email_or_username(email)

    if user is not None:
        try:
            if channel == "sms":
                if not user.contact_number:
                    return (
                        jsonify(
                            msg="No contact number on file. Use email instead."
                        ),
                        400,
                    )
                if not sms_service.sms_configured():
                    return (
                        jsonify(
                            msg="SMS unavailable on server. Use email instead."
                        ),
                        400,
                    )

            pin = _generate_pin()
            pin_hash = bcrypt.generate_password_hash(pin).decode("utf-8")
            expires_at = datetime.now(timezone.utc) + timedelta(
                minutes=PIN_EXPIRY_MINUTES
            )

            if channel == "sms":
                submitted_norm = _normalize_phone(contact_number)
                stored_norm = _normalize_phone(user.contact_number or "")
                if submitted_norm and stored_norm and submitted_norm != stored_norm:
                    if not (
                        stored_norm.endswith(submitted_norm)
                        or submitted_norm.endswith(stored_norm)
                    ):
                        return (
                            jsonify(
                                msg="Contact number does not match our records."
                            ),
                            400,
                        )

            _invalidate_reset_codes(user.id)
            db.session.add(
                PasswordResetCode(
                    user_id=user.id,
                    code_hash=pin_hash,
                    channel=channel,
                    expires_at=expires_at,
                    attempts=0,
                    verified=False,
                )
            )

            if channel == "sms":
                sms_service.send_sms(
                    user.contact_number,
                    f"Your Yamada password reset code is {pin}. "
                    f"Expires in {PIN_EXPIRY_MINUTES} minutes.",
                )
            else:
                send_password_reset_email(
                    to_email=user.email,
                    pin=pin,
                    expiry_minutes=PIN_EXPIRY_MINUTES,
                )

            db.session.commit()
        except Exception as exc:
            db.session.rollback()
            current_app.logger.exception("forgot_password failed: %s", exc)
            if channel == "sms":
                return jsonify(msg="Failed to send SMS. Try email instead."), 500
            return jsonify(msg="Failed to send reset email. Try again later."), 500

        return jsonify(msg=_GENERIC_RESET_MSG, email=user.email), 200

    return jsonify(msg=_GENERIC_RESET_MSG), 200


@auth_bp.post("/verify-pin")
@limiter.limit("10 per minute")
def verify_pin():
    """Validate reset PIN before setting a new password."""
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    email = (data.get("email") or "").strip().lower()
    pin = (data.get("pin") or "").strip()

    if not email or not pin:
        return jsonify(msg="email and pin are required"), 400
    if len(pin) != PIN_LENGTH or not pin.isdigit():
        return jsonify(msg=f"PIN must be {PIN_LENGTH} digits"), 400

    user = _find_user_by_email_or_username(email)
    if user is None:
        return jsonify(msg="Invalid PIN"), 400

    record = _get_active_reset_code(user.id)
    if record is None:
        return jsonify(msg="Invalid or expired PIN"), 400

    now = datetime.now(timezone.utc)
    expires = record.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if now > expires:
        return jsonify(msg="Invalid or expired PIN"), 400

    if record.attempts >= MAX_PIN_ATTEMPTS:
        return jsonify(msg="Too many attempts. Request a new code."), 400

    if not bcrypt.check_password_hash(record.code_hash, pin):
        record.attempts += 1
        db.session.commit()
        return jsonify(msg="Invalid PIN"), 400

    record.verified = True
    db.session.commit()
    return jsonify(msg="PIN verified"), 200


@auth_bp.post("/reset-password")
@limiter.limit("5 per minute")
def reset_password():
    """Set a new password using a verified PIN."""
    if not request.is_json:
        return jsonify(msg="JSON required"), 400

    data = request.get_json() or {}
    email = (data.get("email") or "").strip().lower()
    pin = (data.get("pin") or "").strip()
    new_password = data.get("newPassword") or data.get("new_password") or ""

    if not email or not pin or not new_password:
        return jsonify(msg="email, pin, and newPassword are required"), 400
    if len(pin) != PIN_LENGTH or not pin.isdigit():
        return jsonify(msg=f"PIN must be {PIN_LENGTH} digits"), 400
    if len(new_password) < 8:
        return jsonify(msg="Password must be at least 8 characters"), 400

    user = _find_user_by_email_or_username(email)
    if user is None:
        return jsonify(msg="Invalid PIN"), 400

    record = _get_active_reset_code(user.id)
    if record is None or not record.verified:
        return jsonify(msg="Verify PIN first"), 400

    now = datetime.now(timezone.utc)
    expires = record.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if now > expires:
        return jsonify(msg="Invalid or expired PIN"), 400

    if not bcrypt.check_password_hash(record.code_hash, pin):
        return jsonify(msg="Invalid PIN"), 400

    try:
        user.set_password(new_password)
        _invalidate_reset_codes(user.id)
        db.session.commit()
        return jsonify(msg="Password reset successfully"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Failed to reset password"), 500
