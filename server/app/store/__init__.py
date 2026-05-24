from flask import Blueprint
from app.models import (
    db, 
    Product,
    Seller,
    StoreRegistration,
    Store
)

store=Blueprint('store', __name__)

from . import routes