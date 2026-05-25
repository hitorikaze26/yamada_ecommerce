"""Chat REST API."""

import os
import uuid
from datetime import datetime

from flask import jsonify, request, current_app
from flask_jwt_extended import jwt_required, current_user
from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload
from werkzeug.utils import secure_filename

from . import chat
from . import service as chat_svc
from app.extensions import limiter
from app.models import (
    db,
    Conversation,
    ConversationKind,
    ConversationParticipant,
    ChatMessage,
    ChatMessageType,
    Store,
    Product,
    ProductModerationStatus,
    Order,
    OrderItem,
    RiderDelivery,
    RoleTypes,
)


ALLOWED_UPLOAD = {"png", "jpg", "jpeg", "gif", "webp", "pdf", "doc", "docx"}


def _parse_kind(raw: str) -> ConversationKind | None:
    try:
        return ConversationKind(raw.strip().lower())
    except ValueError:
        return None


def _parse_message_type(raw: str) -> ChatMessageType:
    try:
        return ChatMessageType((raw or "text").strip().lower())
    except ValueError:
        return ChatMessageType.TEXT


@chat.get("/conversations")
@jwt_required()
def list_conversations():
    archived_only = (request.args.get("archived") or "").strip().lower() in {
        "1",
        "true",
        "yes",
    }
    q = (
        select(ConversationParticipant)
        .join(
            Conversation,
            ConversationParticipant.conversation_id == Conversation.id,
        )
        .where(
            ConversationParticipant.user_id == current_user.id,
            ConversationParticipant.deleted_at.is_(None),
            ConversationParticipant.is_archived.is_(archived_only),
        )
    )
    parts = db.session.execute(
        q.options(
            joinedload(ConversationParticipant.conversation)
            .joinedload(Conversation.participants)
            .joinedload(ConversationParticipant.user),
            joinedload(ConversationParticipant.conversation)
            .joinedload(Conversation.store)
            .joinedload(Store.seller),
        )
        .order_by(Conversation.last_message_at.desc())
    ).unique().scalars().all()

    items = []
    for part in parts:
        conv = part.conversation
        if not conv:
            continue
        items.append(chat_svc.serialize_conversation(conv, part, current_user))

    return jsonify(
        conversations=items,
        unreadTotal=chat_svc.total_unread(current_user.id),
    ), 200


@chat.get("/conversations/support")
@jwt_required()
def get_support_conversation():
    roles = chat_svc._user_role_names(current_user)
    if "seller" in roles:
        kind = ConversationKind.SELLER_ADMIN
    elif "buyer" in roles:
        kind = ConversationKind.ADMIN_BUYER
    else:
        return jsonify(msg="Support chat is not available for this role"), 403

    try:
        conv = chat_svc.create_support_conversation(current_user, kind)
    except ValueError as e:
        return jsonify(msg=str(e)), 503

    part = chat_svc.get_participant(conv.id, current_user.id)
    return jsonify(
        conversation=chat_svc.serialize_conversation(conv, part, current_user)
    ), 200


@chat.post("/conversations")
@jwt_required()
def create_conversation():
    data = request.get_json(silent=True) or {}
    kind_raw = data.get("kind") or ""
    kind = _parse_kind(kind_raw)
    if not kind:
        return jsonify(msg="Invalid conversation kind"), 400

    store_id = data.get("storeId")
    order_id = data.get("orderId")
    peer_user_id = data.get("peerUserId")

    try:
        if kind == ConversationKind.BUYER_SELLER:
            if not store_id:
                return jsonify(msg="storeId is required"), 400
            if not chat_svc.user_has_role(current_user, "buyer"):
                return jsonify(msg="Only buyers can start store chats"), 403
            conv = chat_svc.create_buyer_seller(
                current_user, int(store_id), int(order_id) if order_id else None
            )
        elif kind == ConversationKind.RIDER_SELLER:
            if not store_id:
                return jsonify(msg="storeId is required"), 400
            if not chat_svc.user_has_role(current_user, "rider"):
                return jsonify(msg="Only riders can start operational chats"), 403
            conv = chat_svc.create_rider_seller(
                current_user, int(store_id), int(order_id) if order_id else None
            )
        elif kind == ConversationKind.SELLER_ADMIN:
            if not chat_svc.user_has_role(current_user, "seller"):
                return jsonify(msg="Forbidden"), 403
            conv = chat_svc.create_support_conversation(
                current_user, ConversationKind.SELLER_ADMIN
            )
        elif kind == ConversationKind.ADMIN_BUYER:
            if not chat_svc.user_has_role(current_user, "buyer"):
                return jsonify(msg="Forbidden"), 403
            conv = chat_svc.create_support_conversation(
                current_user, ConversationKind.ADMIN_BUYER
            )
        else:
            return jsonify(msg="Unsupported kind"), 400
    except ValueError as e:
        return jsonify(msg=str(e)), 400

    part = chat_svc.get_participant(conv.id, current_user.id)
    return jsonify(
        conversation=chat_svc.serialize_conversation(conv, part, current_user)
    ), 200


@chat.post("/conversations/from-order")
@jwt_required()
def conversation_from_order():
    """Seller opens buyer chat for an order (find or create buyer_seller thread)."""
    if not chat_svc.user_has_role(current_user, "seller"):
        return jsonify(msg="Only sellers can open order chats"), 403
    data = request.get_json(silent=True) or {}
    order_id = data.get("orderId")
    if not order_id:
        return jsonify(msg="orderId is required"), 400
    try:
        conv = chat_svc.create_buyer_seller_for_seller_order(
            current_user, int(order_id)
        )
    except ValueError as e:
        return jsonify(msg=str(e)), 400

    part = chat_svc.get_participant(conv.id, current_user.id)
    return jsonify(
        conversation=chat_svc.serialize_conversation(conv, part, current_user)
    ), 200


@chat.get("/conversations/<int:conversation_id>/messages")
@jwt_required()
def list_messages(conversation_id: int):
    part = chat_svc.get_participant(conversation_id, current_user.id)
    if not part:
        return jsonify(msg="Forbidden"), 403

    cursor = request.args.get("cursor")
    limit_raw = request.args.get("limit", "50")
    try:
        limit = min(int(limit_raw), 100)
    except (TypeError, ValueError):
        limit = 50

    q = (
        select(ChatMessage)
        .where(ChatMessage.conversation_id == conversation_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit + 1)
    )
    if cursor:
        try:
            cursor_id = int(cursor)
            cursor_msg = db.session.get(ChatMessage, cursor_id)
            if cursor_msg and cursor_msg.created_at:
                q = q.where(ChatMessage.created_at < cursor_msg.created_at)
        except (TypeError, ValueError):
            pass

    rows = db.session.execute(
        q.options(joinedload(ChatMessage.sender))
    ).unique().scalars().all()

    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]
    rows = list(reversed(rows))

    conv = db.session.execute(
        select(Conversation)
        .where(Conversation.id == conversation_id)
        .options(
            joinedload(Conversation.store).joinedload(Store.seller),
            joinedload(Conversation.participants).joinedload(ConversationParticipant.user),
        )
    ).unique().scalar_one_or_none()
    part_loaded = chat_svc.get_participant(conversation_id, current_user.id)
    peer = {}
    if conv:
        for p in conv.participants:
            if p.user_id != current_user.id and p.user:
                peer = chat_svc._peer_display(p.user, conv.kind, conv.store)
                break

    messages = [chat_svc.serialize_message(m, current_user.id) for m in rows]
    next_cursor = rows[0].id if rows and has_more else None

    return jsonify(
        messages=messages,
        nextCursor=next_cursor,
        peer=peer,
        conversation=chat_svc.serialize_conversation(conv, part_loaded, current_user)
        if conv and part_loaded
        else None,
    ), 200


@chat.post("/conversations/<int:conversation_id>/messages")
@jwt_required()
def send_message(conversation_id: int):
    from app.services.punishment_service import PunishmentService, ACTION_MESSAGING

    blocked = PunishmentService.enforce(current_user.id, ACTION_MESSAGING)
    if blocked:
        return blocked

    part = chat_svc.get_participant(conversation_id, current_user.id)
    if not part:
        return jsonify(msg="Forbidden"), 403

    conv = db.session.get(Conversation, conversation_id)
    if not conv:
        return jsonify(msg="Conversation not found"), 404

    data = request.get_json(silent=True) or {}
    body = (data.get("body") or "").strip()
    msg_type = _parse_message_type(data.get("messageType") or "text")
    metadata = data.get("metadata") or {}

    if msg_type == ChatMessageType.TEXT and not body:
        return jsonify(msg="Message body is required"), 400

    if msg_type == ChatMessageType.PRODUCT:
        pid = metadata.get("productId")
        if pid:
            metadata = {**metadata, **chat_svc.enrich_product_metadata(int(pid))}
        body = body or f"Shared product"
    elif msg_type == ChatMessageType.ORDER:
        oid = metadata.get("orderId")
        if oid:
            metadata = {**metadata, **chat_svc.enrich_order_metadata(int(oid))}
        body = body or "Shared order"

    reply_id = metadata.get("replyToMessageId")
    if reply_id:
        metadata["replyToMessageId"] = int(reply_id)

    msg = chat_svc.create_message(
        conv,
        current_user,
        body=body,
        message_type=msg_type,
        metadata=metadata or None,
    )
    return jsonify(message=chat_svc.serialize_message(msg, current_user.id)), 201


@chat.post("/conversations/<int:conversation_id>/read")
@jwt_required()
def mark_read(conversation_id: int):
    try:
        payload = chat_svc.mark_conversation_read(conversation_id, current_user.id)
    except PermissionError:
        return jsonify(msg="Forbidden"), 403
    return jsonify(**payload, unreadTotal=chat_svc.total_unread(current_user.id)), 200


@chat.patch("/conversations/<int:conversation_id>/archive")
@jwt_required()
def archive_conversation(conversation_id: int):
    data = request.get_json(silent=True) or {}
    archived = bool(data.get("isArchived", True))
    try:
        is_archived = chat_svc.archive_conversation(
            conversation_id, current_user.id, archived=archived
        )
    except PermissionError:
        return jsonify(msg="Forbidden"), 403
    return jsonify(isArchived=is_archived), 200


@chat.delete("/conversations/<int:conversation_id>")
@jwt_required()
def delete_conversation(conversation_id: int):
    try:
        chat_svc.delete_conversation_for_user(conversation_id, current_user.id)
    except PermissionError:
        return jsonify(msg="Forbidden"), 403
    return jsonify(
        msg="Conversation deleted",
        unreadTotal=chat_svc.total_unread(current_user.id),
    ), 200


@chat.patch("/conversations/<int:conversation_id>/pin")
@jwt_required()
def toggle_pin(conversation_id: int):
    part = chat_svc.get_participant(conversation_id, current_user.id)
    if not part:
        return jsonify(msg="Forbidden"), 403
    data = request.get_json(silent=True) or {}
    if "isPinned" in data:
        part.is_pinned = bool(data["isPinned"])
    else:
        part.is_pinned = not part.is_pinned
    db.session.commit()
    return jsonify(isPinned=part.is_pinned), 200


@chat.get("/unread-count")
@jwt_required()
def unread_count():
    return jsonify(unreadTotal=chat_svc.total_unread(current_user.id)), 200


@chat.post("/upload")
@jwt_required()
@limiter.limit("20 per minute")
def upload_attachment():
    if "file" not in request.files:
        return jsonify(msg="No file provided"), 400
    f = request.files["file"]
    if not f.filename:
        return jsonify(msg="Empty filename"), 400

    ext = f.filename.rsplit(".", 1)[-1].lower() if "." in f.filename else ""
    if ext not in ALLOWED_UPLOAD:
        return jsonify(msg="File type not allowed"), 400

    from app.utils.upload import public_url_for_stored_path, save_upload

    stored_name = f"{uuid.uuid4().hex}_{secure_filename(f.filename)}"
    try:
        stored_path = save_upload(f, "chat_uploads", filename=stored_name)
    except ValueError as exc:
        return jsonify(msg=str(exc)), 400
    url = public_url_for_stored_path(stored_path)
    if not url.startswith("http") and not url.startswith("/"):
        url = f"/static/{stored_path.lstrip('/')}"
    is_image = ext in {"png", "jpg", "jpeg", "gif", "webp"}
    return jsonify(
        url=url,
        fileName=f.filename,
        messageType="image" if is_image else "file",
    ), 200


@chat.get("/share/products")
@jwt_required()
def share_products():
    roles = chat_svc._user_role_names(current_user)
    items = []

    product_load = selectinload(Product.media)
    if "seller" in roles and current_user.store:
        products = db.session.execute(
            select(Product)
            .where(
                Product.store_id == current_user.store.id,
                Product.moderation_status == ProductModerationStatus.ACTIVE,
                Product.is_live.is_(True),
            )
            .options(product_load)
            .order_by(Product.name)
            .limit(50)
        ).scalars().all()
        for p in products:
            items.append(chat_svc._serialize_product_share_meta(p))
    elif "buyer" in roles:
        store_id = request.args.get("storeId")
        if store_id:
            products = db.session.execute(
                select(Product)
                .where(
                    Product.store_id == int(store_id),
                    Product.moderation_status == ProductModerationStatus.ACTIVE,
                    Product.is_live.is_(True),
                )
                .options(product_load)
                .limit(30)
            ).scalars().all()
            for p in products:
                items.append(chat_svc._serialize_product_share_meta(p))

    return jsonify(products=items), 200


@chat.get("/share/orders")
@jwt_required()
def share_orders():
    roles = chat_svc._user_role_names(current_user)
    items = []

    order_load = joinedload(Order.items).joinedload(OrderItem.product).joinedload(
        Product.media
    )
    if "buyer" in roles:
        orders = db.session.execute(
            select(Order)
            .where(Order.buyer_id == current_user.id)
            .options(order_load)
            .order_by(Order.created_at.desc())
            .limit(30)
        ).unique().scalars().all()
    elif "seller" in roles and current_user.store:
        orders = db.session.execute(
            select(Order)
            .where(Order.store_id == current_user.store.id)
            .options(order_load)
            .order_by(Order.created_at.desc())
            .limit(30)
        ).unique().scalars().all()
    elif "rider" in roles:
        deliveries = db.session.execute(
            select(RiderDelivery)
            .where(
                RiderDelivery.rider_id == current_user.id,
                RiderDelivery.status != "cancelled",
            )
            .order_by(RiderDelivery.id.desc())
            .limit(30)
        ).scalars().all()
        order_ids = [d.order_id for d in deliveries if d.order_id]
        orders = []
        if order_ids:
            orders = db.session.execute(
                select(Order)
                .where(Order.id.in_(order_ids))
                .options(order_load)
            ).unique().scalars().all()
    else:
        orders = []

    for o in orders:
        items.append(chat_svc._serialize_order_share_meta(o))

    return jsonify(orders=items), 200
