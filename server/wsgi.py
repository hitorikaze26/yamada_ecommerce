"""WSGI entry point for production (gunicorn + eventlet on Render)."""

from app import create_app
from app.notifications.realtime import socketio

app = create_app()

# gunicorn --worker-class eventlet -w 1 wsgi:app
# Socket.IO attaches to the same app instance via eventlet monkey-patching.
