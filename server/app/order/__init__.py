from flask import Blueprint
from app.models import (
    db,
    Order,
    OrderItem,
    Product,
    Store,
    User,
    BuyerProfile,
    OrderStatus,
    RiderDelivery,
    RiderProfile,
    DeliveryStatus,
)

orders = Blueprint("orders", __name__)

from . import routes
