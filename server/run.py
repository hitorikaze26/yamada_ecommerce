from app import create_app
from app.notifications.realtime import socketio
import os

if __name__ == "__main__":
    app = create_app()
    # host='0.0.0.0' allows connections from any device on the network (phone, other PCs)
    port = int(os.environ.get("PORT", 5000))
    socketio.run(
        app,
        host="0.0.0.0",
        port=port,
        debug=True,
        allow_unsafe_werkzeug=True,
    )
