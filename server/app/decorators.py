from functools import wraps

from flask import (
    jsonify
)
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

def seller_required():
    def wrapper(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            verify_jwt_in_request()
            claims=get_jwt()
            if claims.get('is_seller', False):
                return fn(*args, **kwargs)
            else:
                return jsonify(msg="Sellers only!"), 403
            
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
            admin_role = db.session.execute(
                select(UserRole.role_id).where(
                    UserRole.user_id == user.id,
                    UserRole.role_id == RoleTypes.ADMIN.value,
                )
            ).scalar_one_or_none()
            if admin_role is None:
                return jsonify(msg="Admins only!"), 403
            return fn(*args, **kwargs)
            
        return decorator
    
    return wrapper

def is_store_accepted(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        store=db.session.execute(select(Store).where(Store.user_id==current_user.id)).scalar_one_or_none()
        if store.isAccepted():
            return f(*args, **kwargs)
        else:
            return jsonify(msg="Store must be accepted first!"), 403
    return decorated_function
