from flask import Blueprint

from app.models import db, Notification

notifications = Blueprint("notifications", __name__)

# Import routes so the endpoints are registered with this blueprint
from . import routes  # noqa: E402,F401

__all__ = ["notifications", "db", "Notification", "routes"]
