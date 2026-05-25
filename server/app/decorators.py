from functools import wraps

from flask import jsonify
from flask_jwt_extended import (
    get_jwt,
    get_jwt_identity,
    verify_jwt_in_request,
    current_user,
)
from app.models import (
    db,
    Store,
    User,
    UserRole,
    RoleTypes,
)
from sqlalchemy import select

ROLE_PRIORITY = ("admin", "seller", "rider", "buyer")


def get_effective_role(claims: dict | None = None, user_id: int | None = None) -> str | None:
    """Resolve portal role from JWT claims; admin > seller > rider > buyer."""
    claims = claims or {}
    if claims.get("is_admin"):
        return "admin"
    if claims.get("is_seller"):
        return "seller"
    if claims.get("is_rider"):
        return "rider"
    if claims.get("is_buyer"):
        return "buyer"
    if user_id is not None:
        role_ids = list(
            db.session.execute(
                select(UserRole.role_id).where(UserRole.user_id == user_id)
            ).scalars().all()
        )
        if RoleTypes.ADMIN.value in role_ids:
            return "admin"
        if RoleTypes.SELLER.value in role_ids:
            return "seller"
        if RoleTypes.RIDER.value in role_ids:
            return "rider"
        if RoleTypes.BUYER.value in role_ids:
            return "buyer"
    return None


ROLE_NAME_BY_TYPE = {
    RoleTypes.ADMIN: "admin",
    RoleTypes.BUYER: "buyer",
    RoleTypes.SELLER: "seller",
    RoleTypes.RIDER: "rider",
}


def _user_has_db_role(user_id: int, role_type: RoleTypes) -> bool:
    role_name = ROLE_NAME_BY_TYPE.get(role_type)
    if not role_name:
        return False
    from sqlalchemy import func
    from app.models import Role

    found = db.session.execute(
        select(UserRole.role_id)
        .join(Role, Role.id == UserRole.role_id)
        .where(
            UserRole.user_id == user_id,
            func.lower(Role.name) == role_name,
        )
    ).scalar_one_or_none()
    if found is not None:
        return True
    return (
        db.session.execute(
            select(UserRole.role_id).where(
                UserRole.user_id == user_id,
                UserRole.role_id == role_type.value,
            )
        ).scalar_one_or_none()
        is not None
    )


def _claim_or_db_role(claim_key: str, role_type: RoleTypes) -> bool:
    claims = get_jwt()
    if claims.get(claim_key, False):
        return True
    try:
        user_id = int(get_jwt_identity())
    except (TypeError, ValueError):
        return False
    return _user_has_db_role(user_id, role_type)


def seller_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            if _claim_or_db_role("is_seller", RoleTypes.SELLER):
                return fn(*args, **kwargs)
            return jsonify(msg="Sellers only!"), 403

        return decorator

    return wrapper


def buyer_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            if _claim_or_db_role("is_buyer", RoleTypes.BUYER):
                return fn(*args, **kwargs)
            return jsonify(msg="Buyers only!"), 403

        return decorator

    return wrapper


def rider_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            if _claim_or_db_role("is_rider", RoleTypes.RIDER):
                return fn(*args, **kwargs)
            return jsonify(msg="Riders only!"), 403

        return decorator

    return wrapper


def role_required(*allowed_roles: str):
    """Require JWT/DB role in allowed_roles (e.g. 'seller', 'admin')."""

    allowed = {r.lower() for r in allowed_roles}

    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            try:
                user_id = int(get_jwt_identity())
            except (TypeError, ValueError):
                return jsonify(msg="Unauthorized"), 403
            effective = get_effective_role(get_jwt(), user_id)
            if effective and effective in allowed:
                return fn(*args, **kwargs)
            return jsonify(msg="Unauthorized for this portal"), 403

        return decorator

    return wrapper


def admin_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            if not claims.get("is_admin", False):
                return jsonify(msg="Admins only!"), 403
            try:
                user_id = int(get_jwt_identity())
            except (TypeError, ValueError):
                return jsonify(msg="Admins only!"), 403
            user = db.session.get(User, user_id)
            if user is None:
                return jsonify(msg="Admins only!"), 403
            if not _user_has_db_role(user.id, RoleTypes.ADMIN):
                return jsonify(msg="Admins only!"), 403
            return fn(*args, **kwargs)

        return decorator

    return wrapper


def is_store_accepted(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        store = db.session.execute(
            select(Store).where(Store.user_id == current_user.id)
        ).scalar_one_or_none()
        if store is None:
            return jsonify(msg="Store must be accepted first!"), 403
        if store.isAccepted():
            return f(*args, **kwargs)
        return jsonify(msg="Store must be accepted first!"), 403

    return decorated_function
