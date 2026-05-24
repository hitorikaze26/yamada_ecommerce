from . import notifications, db, Notification

from flask import jsonify, request
from flask_jwt_extended import jwt_required, current_user
from sqlalchemy import select, update, func
from app.decorators import admin_required

from .service import serialize_notification, emit_notifications_read


def _serialize_notification(n: Notification) -> dict:
    return serialize_notification(n)


@notifications.get("/notifications")
@jwt_required()
def list_notifications():
    """Return notifications for the current user.

    Optional query params:
      - role: filter by role string (buyer/seller/rider/admin)
      - page: filter by page/context string
      - unreadOnly: true to return only unread
      - limit: max rows (default 50)
    """

    role = (request.args.get("role") or "").strip().lower() or None
    page = (request.args.get("page") or "").strip() or None
    unread_only = (request.args.get("unreadOnly") or "").strip().lower() in {
        "1",
        "true",
        "yes",
    }
    limit_raw = request.args.get("limit")
    try:
        limit = int(limit_raw) if limit_raw else 50
    except (TypeError, ValueError):
        limit = 50
    if limit < 1:
        limit = 50
    if limit > 200:
        limit = 200

    query = (
        select(Notification)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    )

    if role is not None:
        query = query.where(Notification.role == role)

    if page is not None:
        query = query.where(Notification.page == page)

    if unread_only:
        query = query.where(Notification.read.is_(False))

    query = query.limit(limit)

    rows = db.session.execute(query).scalars().all()

    return jsonify(notifications=[_serialize_notification(n) for n in rows]), 200


@notifications.get("/notifications/unread-count")
@jwt_required()
def unread_count():
    """Return unread notification count for the current user."""

    role = (request.args.get("role") or "").strip().lower() or None
    page = (request.args.get("page") or "").strip() or None

    query = select(func.count()).select_from(Notification).where(
        Notification.user_id == current_user.id,
        Notification.read.is_(False),
    )

    if role is not None:
        query = query.where(Notification.role == role)

    if page is not None:
        query = query.where(Notification.page == page)

    count = db.session.execute(query).scalar() or 0

    return jsonify(count=int(count)), 200


@notifications.post("/notifications/<int:notification_id>/mark-read")
@jwt_required()
def mark_notification_read(notification_id: int):
    """Mark a single notification as read for the current user."""
    try:
        n = db.session.get(Notification, notification_id)
        if n is None:
            return jsonify(msg="Notification not found"), 404
        if n.user_id != current_user.id:
            return jsonify(msg="Not authorized"), 403

        n.read = True
        db.session.commit()
        emit_notifications_read(current_user.id, role=n.role)
        return jsonify(msg="Notification marked as read", notification_id=notification_id), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error marking notification as read"), 500


@notifications.post("/notifications/mark-all-read")
@jwt_required()
def mark_all_read():
    """Mark all notifications as read for the current user (optionally by role/page)."""

    data = request.get_json(silent=True) or {}
    role = (data.get("role") or "").strip().lower() or None
    page = (data.get("page") or "").strip() or None

    try:
        stmt = (
            update(Notification)
            .where(Notification.user_id == current_user.id)
        )

        if role is not None:
            stmt = stmt.where(Notification.role == role)

        if page is not None:
            stmt = stmt.where(Notification.page == page)

        stmt = stmt.values(read=True)
        db.session.execute(stmt)
        db.session.commit()

        emit_notifications_read(current_user.id, role=role)
        return jsonify(msg="Notifications marked as read"), 200
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error marking notifications as read"), 500


@notifications.post("/notifications/admin")
@jwt_required()
@admin_required()
def create_notification_admin():
    """Create a notification for a specific user.

    Expected JSON body:
      - userId: int (required)
      - title: str (required)
      - body: str (required)
      - role: str (optional, buyer/seller/rider/admin)
      - page: str (optional, page/context key)
    """

    from .service import create_notification

    data = request.get_json(silent=True) or {}
    user_id = data.get("userId")
    title = (data.get("title") or "").strip()
    body = (data.get("body") or "").strip()
    role = (data.get("role") or None)
    page = (data.get("page") or None)

    if not user_id or not title or not body:
        return jsonify(msg="userId, title, and body are required"), 400

    try:
        n = create_notification(
            user_id=int(user_id),
            title=title,
            message=body,
            role=role.lower() if isinstance(role, str) else role,
            page=page,
        )
        db.session.commit()

        return jsonify(notification=_serialize_notification(n)), 201
    except Exception:
        db.session.rollback()
        return jsonify(msg="Error creating notification"), 500
