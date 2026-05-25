"""Development entry point — DO NOT use in production (gunicorn via wsgi.py)."""
from app import create_app
from app.notifications.realtime import socketio
import os

if __name__ == "__main__":
    app = create_app()
    port = int(os.environ.get("PORT", 5000))
    is_dev = not app.config.get("TESTING", False) and app.config.get("DEBUG", False)
    socketio.run(
        app,
        host="0.0.0.0",
        port=port,
        debug=is_dev,
        allow_unsafe_werkzeug=is_dev,
    )
