"""Active punishment checks and enforcement helpers."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from sqlalchemy import select

from app.models import Punishment, PunishmentSeverity, db

# Actions checked across the platform
ACTION_MESSAGING = "messaging"
ACTION_ORDERING = "ordering"
ACTION_REFUND_REQUEST = "refund_request"
ACTION_REVIEW_POST = "review_post"
ACTION_PRODUCT_LISTING = "product_listing"
ACTION_DELIVERY_ASSIGNMENT = "delivery_assignment"
ACTION_WITHDRAWAL = "withdrawal"

RESTRICTION_MESSAGES = {
    "messaging_disabled": "Your account cannot send messages due to an active restriction.",
    "communication_restricted": "Your account cannot send messages due to an active restriction.",
    "no_ordering": "You cannot place orders right now due to an active account restriction.",
    "refund_limited": "Refund requests are limited on your account due to an active restriction.",
    "review_disabled": "You cannot post reviews due to an active account restriction.",
    "listing_suspended": "Product listing is suspended on your account due to an active restriction.",
    "delivery_suspension": "Delivery assignments are suspended on your account due to an active restriction.",
    "assignment_reduced": "Delivery assignments are limited on your account due to an active restriction.",
    "withdrawal_freeze": "Wallet withdrawals are frozen on your account due to an active restriction.",
    "order_limit": "Your store has an order-processing limit due to an active restriction.",
    "tracking_disabled": "Delivery tracking is under investigation on your account.",
    "permanent_ban": "Your account has been permanently banned.",
}

RESTRICTION_ACTIONS: dict[str, str] = {
    "messaging_disabled": ACTION_MESSAGING,
    "communication_restricted": ACTION_MESSAGING,
    "no_ordering": ACTION_ORDERING,
    "refund_limited": ACTION_REFUND_REQUEST,
    "review_disabled": ACTION_REVIEW_POST,
    "listing_suspended": ACTION_PRODUCT_LISTING,
    "delivery_suspension": ACTION_DELIVERY_ASSIGNMENT,
    "assignment_reduced": ACTION_DELIVERY_ASSIGNMENT,
    "withdrawal_freeze": ACTION_WITHDRAWAL,
    "order_limit": "order_limit",
    "tracking_disabled": "tracking",
    "permanent_ban": "ban",
}


class PunishmentService:
    @classmethod
    def get_active_punishments(cls, user_id: int) -> list[Punishment]:
        if user_id is None:
            return []
        now = dt.datetime.utcnow()
        rows = db.session.execute(
            select(Punishment).where(
                Punishment.user_id == user_id,
                Punishment.is_active.is_(True),
            )
        ).scalars().all()
        active: list[Punishment] = []
        for p in rows:
            if p.end_date is not None and p.end_date <= now:
                continue
            active.append(p)
        return active

    @classmethod
    def is_banned(cls, user_id: int) -> bool:
        for p in cls.get_active_punishments(user_id):
            if p.severity == PunishmentSeverity.BAN:
                return True
            if p.restriction_type == "permanent_ban":
                return True
        return False

    @classmethod
    def check(cls, user_id: int, action: str) -> tuple[bool, Optional[str]]:
        """Return (allowed, error_message)."""
        if user_id is None:
            return True, None

        if cls.is_banned(user_id):
            return False, "Your account has been banned and cannot perform this action."

        for p in cls.get_active_punishments(user_id):
            restriction = (p.restriction_type or "").strip()
            if not restriction:
                if p.severity == PunishmentSeverity.RESTRICTION and action != ACTION_MESSAGING:
                    continue
                if p.severity == PunishmentSeverity.WARNING:
                    continue
                continue

            blocked_action = RESTRICTION_ACTIONS.get(restriction)
            if blocked_action == "ban" or blocked_action == action:
                return False, RESTRICTION_MESSAGES.get(
                    restriction,
                    "This action is restricted on your account.",
                )

        return True, None

    @classmethod
    def enforce(cls, user_id: int, action: str) -> Optional[tuple]:
        """Return a Flask (jsonify, status) tuple when blocked, else None."""
        allowed, msg = cls.check(user_id, action)
        if allowed:
            return None
        from flask import jsonify

        return jsonify(msg=msg), 403
