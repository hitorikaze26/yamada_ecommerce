"""Chat business logic, serialization, and realtime emits."""

from __future__ import annotations

import datetime
import json
from typing import Any, Optional

from flask import current_app
from sqlalchemy import select, func, and_, or_
from sqlalchemy.orm import joinedload, selectinload

from app.models import (
    db,
    User,
    Role,
    RoleTypes,
    Store,
    Order,
    Product,
    OrderItem,
    ChatSettings,
    Conversation,
    ConversationKind,
    ConversationParticipant,
    ChatMessage,
    ChatMessageType,
    UserPresence,
    RiderDelivery,
)
from app.notifications.realtime import emit_to_user


ONLINE_WINDOW_SECONDS = 60


def _user_role_names(user: User) -> list[str]:
    names = []
    for ur in user.roles or []:
        try:
            if ur.role and ur.role.name:
                names.append(ur.role.name.lower())
        except Exception:
            continue
    return names


def user_has_role(user: User, role_name: str) -> bool:
    return role_name.lower() in _user_role_names(user)


def get_platform_admin_user() -> Optional[User]:
    admin_role = db.session.execute(
        select(Role).where(Role.id == RoleTypes.ADMIN.value)
    ).scalar_one_or_none()
    if not admin_role:
        return None
    from app.models import UserRole

    row = db.session.execute(
        select(User)
        .join(UserRole, UserRole.user_id == User.id)
        .where(UserRole.role_id == admin_role.id, User.active.is_(True))
        .limit(1)
    ).scalar_one_or_none()
    return row


def touch_presence(user_id: int, online: bool = True) -> None:
    pres = db.session.get(UserPresence, user_id)
    now = datetime.datetime.now()
    if pres is None:
        pres = UserPresence(user_id=user_id, last_seen_at=now, is_online=online)
        db.session.add(pres)
    else:
        pres.last_seen_at = now
        pres.is_online = online
    db.session.commit()


def is_user_online(user_id: int) -> bool:
    pres = db.session.get(UserPresence, user_id)
    if not pres:
        return False
    if pres.is_online:
        delta = (datetime.datetime.now() - pres.last_seen_at).total_seconds()
        return delta < ONLINE_WINDOW_SECONDS
    return False


def emit_chat_message(participant_user_ids: list[int], payload: dict) -> None:
    for uid in participant_user_ids:
        emit_to_user(uid, "chat_message", payload)


def emit_chat_read(participant_user_ids: list[int], payload: dict) -> None:
    for uid in participant_user_ids:
        emit_to_user(uid, "chat_read", payload)


def emit_chat_presence(user_ids: list[int], payload: dict) -> None:
    for uid in user_ids:
        emit_to_user(uid, "chat_presence", payload)


def _user_display_name(user: User) -> str:
    given = (user.given_name or "").strip()
    surname = (user.surname or "").strip()
    full = f"{given} {surname}".strip()
    if full:
        return full
    username = (user.username or "").strip()
    if username and "@" not in username:
        return username
    return username or "User"


def _avatar_url(user: User) -> Optional[str]:
    try:
        if user.buyer_profile and user.buyer_profile.avatar_path:
            path = user.buyer_profile.avatar_path
            if path.startswith("http"):
                return path
            return f"/static/{path.lstrip('/')}"
    except Exception:
        pass
    try:
        if user.rider_profile and user.rider_profile.avatar_path:
            path = user.rider_profile.avatar_path
            if path.startswith("http"):
                return path
            return f"/static/{path.lstrip('/')}"
    except Exception:
        pass
    return None


def _store_logo_url(store: Store) -> Optional[str]:
    seller = getattr(store, "seller", None)
    if not seller:
        return None
    path = getattr(seller, "avatar_path", None)
    if not path:
        return None
    if str(path).startswith(("http://", "https://")):
        return str(path)
    return _normalize_image_url(str(path))


def _peer_display(user: User, kind: ConversationKind, store: Optional[Store]) -> dict:
    role = "user"
    name = _user_display_name(user)
    verified = bool(user.email_verified)
    avatar = _avatar_url(user)

    if kind in (ConversationKind.SELLER_ADMIN, ConversationKind.ADMIN_BUYER):
        if user_has_role(user, "admin"):
            return {
                "userId": user.id,
                "name": "Yamada Support",
                "role": "admin",
                "isVerified": True,
                "avatarUrl": None,
                "isOnline": is_user_online(user.id),
            }

    if store and user.id == store.user_id:
        name = store.store_name
        role = "seller"
        verified = bool(store.seller and store.seller.registration and
                        store.seller.registration.request_status.name == "ACCEPTED")
        avatar = _store_logo_url(store)
    elif user_has_role(user, "buyer"):
        role = "buyer"
        name = _user_display_name(user)
    elif user_has_role(user, "rider"):
        role = "rider"
        name = _user_display_name(user)
    elif user_has_role(user, "seller"):
        role = "seller"
        if user.store:
            name = user.store.store_name
            logo = _store_logo_url(user.store)
            if logo:
                avatar = logo
    elif user_has_role(user, "admin"):
        role = "admin"
        name = "Yamada Support"

    return {
        "userId": user.id,
        "name": name,
        "role": role,
        "isVerified": verified,
        "avatarUrl": avatar,
        "isOnline": is_user_online(user.id),
    }


def serialize_message(msg: ChatMessage, current_user_id: int) -> dict:
    sender_role = "system"
    if msg.sender_user_id:
        sender = msg.sender
        if sender:
            if user_has_role(sender, "admin"):
                sender_role = "admin"
            elif user_has_role(sender, "seller"):
                sender_role = "seller"
            elif user_has_role(sender, "rider"):
                sender_role = "rider"
            else:
                sender_role = "buyer"

    meta = msg.metadata_json or {}
    return {
        "id": msg.id,
        "conversationId": msg.conversation_id,
        "senderUserId": msg.sender_user_id,
        "senderRole": sender_role,
        "body": msg.body or "",
        "messageType": msg.message_type.value if hasattr(msg.message_type, "value") else str(msg.message_type),
        "metadata": meta,
        "createdAt": msg.created_at.isoformat() if msg.created_at else None,
        "isMine": msg.sender_user_id == current_user_id,
    }


def serialize_conversation(
    conv: Conversation,
    participant: ConversationParticipant,
    current_user: User,
) -> dict:
    peer_part = None
    for p in conv.participants:
        if p.user_id != current_user.id:
            peer_part = p
            break

    peer_user = peer_part.user if peer_part else None
    store = conv.store
    peer = {}
    if peer_user:
        peer = _peer_display(peer_user, conv.kind, store)
    elif conv.kind in (ConversationKind.SELLER_ADMIN, ConversationKind.ADMIN_BUYER):
        peer = {
            "userId": 0,
            "name": "Yamada Support",
            "role": "admin",
            "isVerified": True,
            "avatarUrl": None,
            "isOnline": False,
        }

    kind_val = conv.kind.value if hasattr(conv.kind, "value") else str(conv.kind)
    title = peer.get("name", "Conversation")
    if conv.kind == ConversationKind.ADMIN_BUYER:
        title = "Support"
    elif conv.kind == ConversationKind.SELLER_ADMIN:
        title = "Yamada Support"

    return {
        "id": conv.id,
        "kind": kind_val,
        "storeId": conv.store_id,
        "orderId": conv.order_id,
        "title": title,
        "lastMessagePreview": conv.last_message_preview or "",
        "lastMessageAt": conv.last_message_at.isoformat() if conv.last_message_at else None,
        "unreadCount": participant.unread_count,
        "isPinned": participant.is_pinned,
        "isArchived": bool(participant.is_archived),
        "peer": peer,
    }


def get_participant(conv_id: int, user_id: int) -> Optional[ConversationParticipant]:
    return db.session.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv_id,
            ConversationParticipant.user_id == user_id,
        )
    ).scalar_one_or_none()


def _normalize_image_url(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    if url.startswith(("http://", "https://", "/static/")):
        return url
    return f"/static/{url.lstrip('/')}"


def _product_display_image(product) -> Optional[str]:
    if not product:
        return None
    image_url = _normalize_image_url(getattr(product, "image_url", None))
    media_list = getattr(product, "media", None) or []
    for media in media_list:
        path = _normalize_image_url(getattr(media, "path", None))
        if path:
            return path
    return image_url


def _conversation_label(conv: Conversation) -> str:
    kind = conv.kind
    if kind == ConversationKind.BUYER_SELLER:
        if conv.store:
            return f"chat with {conv.store.store_name}"
        return "buyer–seller chat"
    if kind == ConversationKind.SELLER_ADMIN:
        return "seller support chat"
    if kind == ConversationKind.ADMIN_BUYER:
        return "Yamada support chat"
    if kind == ConversationKind.RIDER_SELLER:
        return "rider–seller chat"
    return "Yamada chat"


def _email_chat_recipients(
    conv: Conversation,
    sender: User,
    msg: ChatMessage,
) -> None:
    """Send email alerts to conversation participants (except sender)."""
    if msg.message_type == ChatMessageType.SYSTEM:
        return
    meta = msg.metadata_json or {}
    if meta.get("autoReply"):
        return

    from app.services.email_service import send_chat_message_email

    sender_name = _user_display_name(sender)
    preview = conv.last_message_preview or _preview_for_message(msg)
    label = _conversation_label(conv)

    recipient_ids = [
        p.user_id
        for p in conv.participants
        if p.user_id != sender.id
    ]
    for uid in recipient_ids:
        user = db.session.get(User, uid)
        if user is None or not user.active or not user.email:
            continue
        try:
            send_chat_message_email(
                to_email=user.email,
                sender_name=sender_name,
                preview=preview,
                conversation_label=label,
            )
        except Exception:
            current_app.logger.exception(
                "Failed to send chat email to user %s", uid
            )


def _preview_for_message(msg: ChatMessage) -> str:
    mt = msg.message_type
    meta = msg.metadata_json or {}
    if mt == ChatMessageType.TEXT:
        return (msg.body or "")[:200]
    if mt == ChatMessageType.IMAGE:
        return "Photo"
    if mt == ChatMessageType.FILE:
        return "Attachment"
    if mt == ChatMessageType.PRODUCT:
        name = (meta.get("name") or "").strip()
        return f"Product · {name}" if name else "Shared a product"
    if mt == ChatMessageType.ORDER:
        name = (meta.get("productName") or "").strip()
        return f"Order · {name}" if name else "Shared an order"
    if mt == ChatMessageType.SYSTEM:
        return msg.body or "System message"
    return "Message"


def _increment_unread(conv_id: int, exclude_user_id: int) -> list[int]:
    parts = db.session.execute(
        select(ConversationParticipant).where(
            ConversationParticipant.conversation_id == conv_id,
            ConversationParticipant.user_id != exclude_user_id,
        )
    ).scalars().all()
    ids = []
    for p in parts:
        p.unread_count = (p.unread_count or 0) + 1
        ids.append(p.user_id)
    return ids


def maybe_send_auto_reply(conv: Conversation, buyer_user_id: int) -> None:
    if conv.kind != ConversationKind.BUYER_SELLER or not conv.store_id:
        return
    settings = db.session.execute(
        select(ChatSettings).where(ChatSettings.store_id == conv.store_id)
    ).scalar_one_or_none()
    if not settings or not settings.auto_reply_enabled:
        return
    count = db.session.execute(
        select(func.count(ChatMessage.id)).where(
            ChatMessage.conversation_id == conv.id,
            ChatMessage.message_type == ChatMessageType.SYSTEM,
        )
    ).scalar() or 0
    if count > 0:
        return
    buyer_msgs = db.session.execute(
        select(func.count(ChatMessage.id)).where(
            ChatMessage.conversation_id == conv.id,
            ChatMessage.sender_user_id == buyer_user_id,
        )
    ).scalar() or 0
    if buyer_msgs != 1:
        return

    store = conv.store
    if not store:
        return
    seller_uid = store.user_id
    auto_msg = ChatMessage(
        conversation_id=conv.id,
        sender_user_id=seller_uid,
        body=settings.auto_reply_message,
        message_type=ChatMessageType.SYSTEM,
        metadata_json={"autoReply": True},
    )
    db.session.add(auto_msg)
    conv.last_message_at = datetime.datetime.now()
    conv.last_message_preview = _preview_for_message(auto_msg)
    recipient_ids = _increment_unread(conv.id, seller_uid)
    db.session.commit()
    payload = serialize_message(auto_msg, buyer_user_id)
    emit_chat_message([buyer_user_id] + recipient_ids, payload)


def create_message(
    conv: Conversation,
    sender: User,
    *,
    body: str = "",
    message_type: ChatMessageType = ChatMessageType.TEXT,
    metadata: Optional[dict] = None,
) -> ChatMessage:
    msg = ChatMessage(
        conversation_id=conv.id,
        sender_user_id=sender.id,
        body=body or "",
        message_type=message_type,
        metadata_json=metadata,
    )
    db.session.add(msg)
    conv.last_message_at = datetime.datetime.now()
    conv.last_message_preview = _preview_for_message(msg)
    recipient_ids = _increment_unread(conv.id, sender.id)
    db.session.commit()
    db.session.refresh(msg)

    participant_ids = [p.user_id for p in conv.participants]
    payload = serialize_message(msg, sender.id)
    emit_chat_message(participant_ids, payload)
    _email_chat_recipients(conv, sender, msg)

    if conv.kind == ConversationKind.BUYER_SELLER and user_has_role(sender, "buyer"):
        maybe_send_auto_reply(conv, sender.id)

    return msg


def find_buyer_seller_conversation(buyer_id: int, store_id: int) -> Optional[Conversation]:
    return db.session.execute(
        select(Conversation)
        .where(
            Conversation.kind == ConversationKind.BUYER_SELLER,
            Conversation.store_id == store_id,
            Conversation.buyer_user_id == buyer_id,
        )
        .options(joinedload(Conversation.participants).joinedload(ConversationParticipant.user))
    ).unique().scalar_one_or_none()


def find_support_conversation(user_id: int, kind: ConversationKind) -> Optional[Conversation]:
    return db.session.execute(
        select(Conversation)
        .join(ConversationParticipant)
        .where(
            Conversation.kind == kind,
            ConversationParticipant.user_id == user_id,
        )
        .options(joinedload(Conversation.participants).joinedload(ConversationParticipant.user))
    ).unique().scalar_one_or_none()


def find_rider_seller_conversation(
    rider_id: int, store_id: int, order_id: Optional[int]
) -> Optional[Conversation]:
    q = select(Conversation).where(
        Conversation.kind == ConversationKind.RIDER_SELLER,
        Conversation.store_id == store_id,
    )
    if order_id:
        q = q.where(Conversation.order_id == order_id)
    else:
        q = q.join(ConversationParticipant).where(
            ConversationParticipant.user_id == rider_id
        )
    return db.session.execute(
        q.options(joinedload(Conversation.participants).joinedload(ConversationParticipant.user))
    ).unique().scalar_one_or_none()


def _add_participant(conv_id: int, user_id: int, role: str) -> ConversationParticipant:
    existing = get_participant(conv_id, user_id)
    if existing:
        return existing
    p = ConversationParticipant(
        conversation_id=conv_id,
        user_id=user_id,
        participant_role=role,
    )
    db.session.add(p)
    return p


def create_buyer_seller_for_seller_order(seller: User, order_id: int) -> Conversation:
    if not user_has_role(seller, "seller") or not seller.store:
        raise ValueError("Seller store not found")
    order = db.session.get(Order, order_id)
    if not order or order.store_id != seller.store.id:
        raise ValueError("Order not found")
    if not order.buyer_id:
        raise ValueError("Buyer not found for this order")
    buyer = db.session.get(User, order.buyer_id)
    if not buyer:
        raise ValueError("Buyer not found")
    conv = create_buyer_seller(buyer, seller.store.id, order_id)
    seller_part = get_participant(conv.id, seller.id)
    if seller_part:
        restore_participant_if_deleted(seller_part)
    return conv


def create_buyer_seller(buyer: User, store_id: int, order_id: Optional[int] = None) -> Conversation:
    store = db.session.get(Store, store_id)
    if not store:
        raise ValueError("Store not found")
    existing = find_buyer_seller_conversation(buyer.id, store_id)
    if existing:
        part = get_participant(existing.id, buyer.id)
        if part:
            restore_participant_if_deleted(part)
        if order_id and not existing.order_id:
            existing.order_id = order_id
            db.session.commit()
        return existing

    conv = Conversation(
        kind=ConversationKind.BUYER_SELLER,
        store_id=store_id,
        order_id=order_id,
        buyer_user_id=buyer.id,
        last_message_preview="",
    )
    db.session.add(conv)
    db.session.flush()
    _add_participant(conv.id, buyer.id, "buyer")
    _add_participant(conv.id, store.user_id, "seller")
    db.session.commit()
    db.session.refresh(conv)
    return conv


def create_support_conversation(user: User, kind: ConversationKind) -> Conversation:
    existing = find_support_conversation(user.id, kind)
    if existing:
        return existing
    admin = get_platform_admin_user()
    if not admin:
        raise ValueError("Platform support is unavailable")

    conv = Conversation(kind=kind, last_message_preview="")
    db.session.add(conv)
    db.session.flush()

    if kind == ConversationKind.SELLER_ADMIN:
        _add_participant(conv.id, user.id, "seller")
        _add_participant(conv.id, admin.id, "admin")
    else:
        _add_participant(conv.id, user.id, "buyer")
        _add_participant(conv.id, admin.id, "admin")

    db.session.commit()
    db.session.refresh(conv)
    return conv


def create_rider_seller(
    rider: User, store_id: int, order_id: Optional[int] = None
) -> Conversation:
    store = db.session.get(Store, store_id)
    if not store:
        raise ValueError("Store not found")
    if order_id:
        existing = find_rider_seller_conversation(rider.id, store_id, order_id)
        if existing:
            return existing
    else:
        existing = find_rider_seller_conversation(rider.id, store_id, None)
        if existing:
            return existing

    conv = Conversation(
        kind=ConversationKind.RIDER_SELLER,
        store_id=store_id,
        order_id=order_id,
        last_message_preview="",
    )
    db.session.add(conv)
    db.session.flush()
    _add_participant(conv.id, rider.id, "rider")
    _add_participant(conv.id, store.user_id, "seller")
    db.session.commit()
    db.session.refresh(conv)
    return conv


def mark_conversation_read(conv_id: int, user_id: int) -> dict:
    part = get_participant(conv_id, user_id)
    if not part:
        raise PermissionError("Not a participant")
    restore_participant_if_deleted(part)
    now = datetime.datetime.now()
    part.last_read_at = now
    part.unread_count = 0
    db.session.commit()

    conv = db.session.get(Conversation, conv_id)
    participant_ids = [p.user_id for p in conv.participants] if conv else []
    payload = {
        "conversationId": conv_id,
        "userId": user_id,
        "readAt": now.isoformat(),
    }
    emit_chat_read(participant_ids, payload)
    return payload


def total_unread(user_id: int) -> int:
    total = db.session.execute(
        select(func.coalesce(func.sum(ConversationParticipant.unread_count), 0)).where(
            ConversationParticipant.user_id == user_id,
            ConversationParticipant.deleted_at.is_(None),
            ConversationParticipant.is_archived.is_(False),
        )
    ).scalar()
    return int(total or 0)


def archive_conversation(conv_id: int, user_id: int, *, archived: bool = True) -> bool:
    part = get_participant(conv_id, user_id)
    if not part or part.deleted_at is not None:
        raise PermissionError("Not a participant")
    part.is_archived = archived
    if archived:
        part.is_pinned = False
    db.session.commit()
    return part.is_archived


def delete_conversation_for_user(conv_id: int, user_id: int) -> None:
    part = get_participant(conv_id, user_id)
    if not part:
        raise PermissionError("Not a participant")
    part.deleted_at = datetime.datetime.now()
    part.is_archived = False
    part.is_pinned = False
    part.unread_count = 0
    db.session.commit()


def restore_participant_if_deleted(part: ConversationParticipant) -> None:
    if part.deleted_at is not None:
        part.deleted_at = None
        part.is_archived = False
        db.session.flush()


def _serialize_product_share_meta(product: Product) -> dict:
    price = float(product.sale_price or product.price or 0)
    return {
        "id": product.id,
        "name": product.name,
        "price": price,
        "imageUrl": _product_display_image(product),
    }


def enrich_product_metadata(product_id: int) -> dict:
    product = db.session.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(selectinload(Product.media))
    ).scalar_one_or_none()
    if not product:
        return {}
    meta = _serialize_product_share_meta(product)
    return {
        "productId": meta["id"],
        "name": meta["name"],
        "price": meta["price"],
        "imageUrl": meta["imageUrl"],
        "slug": getattr(product, "slug", None) or str(product.id),
    }


def _serialize_order_share_meta(order: Order) -> dict:
    first_item = order.items[0] if order.items else None
    product_name = ""
    product_image = None
    if first_item and first_item.product:
        product_name = first_item.product.name
        product_image = _product_display_image(first_item.product)
    status = order.status.value if hasattr(order.status, "value") else str(order.status)
    return {
        "orderId": order.id,
        "orderNumber": str(order.id),
        "status": status,
        "productName": product_name,
        "productImageUrl": product_image,
        "totalAmount": float(order.grand_total or 0),
    }


def enrich_order_metadata(order_id: int) -> dict:
    order = db.session.execute(
        select(Order)
        .where(Order.id == order_id)
        .options(
            selectinload(Order.items)
            .selectinload(OrderItem.product)
            .selectinload(Product.media)
        )
    ).scalar_one_or_none()
    if not order:
        return {}
    return _serialize_order_share_meta(order)
