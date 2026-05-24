"""Flask-SocketIO realtime layer for in-app notifications."""

from __future__ import annotations

from flask import request
from flask_jwt_extended import decode_token
from flask_jwt_extended.exceptions import JWTDecodeError
from flask_socketio import SocketIO, join_room, leave_room
from jwt import ExpiredSignatureError, InvalidTokenError
from socketio.exceptions import ConnectionRefusedError

from app.models import db

socketio = SocketIO(cors_allowed_origins="*", async_mode="threading")


def user_room(user_id: int) -> str:
    return f"user_{user_id}"


def conversation_room(conversation_id: int) -> str:
    return f"conv_{conversation_id}"


def init_socketio(app) -> SocketIO:
    """Attach SocketIO to the Flask app and register connection handlers."""
    socketio.init_app(
        app,
        cors_allowed_origins="*",
        async_mode="threading",
        logger=False,
        engineio_logger=False,
    )

    @socketio.on("connect")
    def on_connect(auth=None):
        token = None
        if isinstance(auth, dict):
            token = auth.get("token")
        if not token:
            token = request.args.get("token")

        if not token:
            raise ConnectionRefusedError("Authentication token required")

        try:
            decoded = decode_token(token)
            user_id = decoded.get("sub")
            if user_id is None:
                raise ConnectionRefusedError("Invalid token")
            uid = int(user_id)
        except (
            JWTDecodeError,
            ExpiredSignatureError,
            InvalidTokenError,
            TypeError,
            ValueError,
        ) as exc:
            raise ConnectionRefusedError("Invalid or expired token") from exc

        join_room(user_room(uid))
        request.environ["socket_user_id"] = uid

        try:
            from app.chat.service import touch_presence, emit_chat_presence

            touch_presence(uid, online=True)
            emit_chat_presence([uid], {"userId": uid, "isOnline": True})
        except Exception:
            pass

        return True

    @socketio.on("disconnect")
    def on_disconnect():
        uid = request.environ.get("socket_user_id")
        if uid is None:
            return
        try:
            leave_room(user_room(int(uid)))
            conv_rooms = request.environ.get("socket_conv_rooms") or []
            for room in conv_rooms:
                leave_room(room)
        except Exception:
            pass
        try:
            from app.chat.service import touch_presence, emit_chat_presence

            touch_presence(int(uid), online=False)
            emit_chat_presence([int(uid)], {"userId": int(uid), "isOnline": False})
        except Exception:
            db.session.rollback()

    @socketio.on("join_conversation")
    def on_join_conversation(data):
        uid = request.environ.get("socket_user_id")
        if uid is None:
            return False
        conv_id = None
        if isinstance(data, dict):
            conv_id = data.get("conversationId") or data.get("conversation_id")
        if conv_id is None:
            return False
        try:
            conv_id = int(conv_id)
        except (TypeError, ValueError):
            return False

        from app.chat.service import get_participant

        if not get_participant(conv_id, int(uid)):
            return False

        room = conversation_room(conv_id)
        join_room(room)
        rooms = request.environ.setdefault("socket_conv_rooms", [])
        if room not in rooms:
            rooms.append(room)
        return True

    @socketio.on("chat_presence_ping")
    def on_presence_ping():
        uid = request.environ.get("socket_user_id")
        if uid is None:
            return
        try:
            from app.chat.service import touch_presence

            touch_presence(int(uid), online=True)
        except Exception:
            pass

    return socketio


def emit_to_user(user_id: int, event: str, payload: dict) -> None:
    socketio.emit(event, payload, room=user_room(user_id))
