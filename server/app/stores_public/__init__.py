from flask import Blueprint

stores_public = Blueprint('stores_public', __name__)

from . import routes  # noqa: E402, F401
