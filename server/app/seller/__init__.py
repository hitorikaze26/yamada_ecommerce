from flask import Blueprint
from app.models import (
    db, 
    Product,
    Seller,
    StoreRegistration,
    Store,
    User,
    UserRole,
    Role,
    RoleTypes,
    RiderDelivery,
    RiderProfile,
)

seller=Blueprint('seller', __name__)

from . import routes
from . import insights_routes  # noqa: F401