from flask import Blueprint

from app.models import db

chat = Blueprint("chat", __name__)

from . import routes  # noqa: E402,F401

__all__ = ["chat", "db", "routes"]
