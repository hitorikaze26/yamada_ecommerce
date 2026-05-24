"""WSGI entry point for production (gunicorn + gthread on Railway)."""

from app import create_app
from app.notifications.realtime import socketio

app = create_app()

# gunicorn --worker-class gthread -w 1 --threads 100 wsgi:app
# Socket.IO uses async_mode="threading" (see app/notifications/realtime.py).
