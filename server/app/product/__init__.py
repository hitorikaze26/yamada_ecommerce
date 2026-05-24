from flask import Blueprint
from app.models import (
    db,
    Product,
    Store,
    Category,
    ProductCategory,
    ProductVariation,
)
from app.decorators import (
    seller_required,
    is_store_accepted
)

products=Blueprint('products', __name__)

from . import routes