from flask import Blueprint
from app.models import (
    db,
    User,
    RoleTypes,
    Role,
    UserRole,
    Seller,
    StoreRegistration,
    StoreRequestStatus,
    RiderProfile,
)
from app.extensions import (
    jwt,
)

auth = Blueprint('auth', __name__)

from . import routes