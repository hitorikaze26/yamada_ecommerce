"""Refund settlement and moderation helpers."""

from __future__ import annotations

import datetime as dt
import json
from typing import Literal, Optional

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import (
    DeliveryStatus,
    Order,
    PaymentStatus,
    PaymentTransaction,
    RefundRequest,
    RefundStatus,
    SellerWallet,
    db,
)
from app.notifications.service import (
    notify_admin_refund_disputed,
    notify_buyer_refund_approved,
    notify_buyer_refund_declined,
    notify_buyer_refund_seller_rejected,
)

ADMIN_COMMISSION_RATE = 0.10
RIDER_FIXED_EARNING = 50.0
RIDER_FEE_ADMIN_SHARE_PERCENT = 50.0
RIDER_FEE_SELLER_SHARE_PERCENT = 50.0


def compute_order_financials_for_refund(order: Order) -> dict:
    """Financial breakdown for refunds, mirroring buyer-side completion logic."""

    subtotal = float(order.total_amount or 0.0)
    admin_commission = subtotal * ADMIN_COMMISSION_RATE

    rider_fee = 0.0
    deliveries = getattr(order, "deliveries", None) or []
    if deliveries:
        deliveries_sorted = sorted(
            deliveries,
            key=lambda d: getattr(d, "created_at", None) or dt.datetime.min,
            reverse=True,
        )
        d = deliveries_sorted[0]
        status_value = d.status.value if hasattr(d.status, "value") else str(d.status)
        if status_value in {
            DeliveryStatus.PICKUP.value,
            DeliveryStatus.TRANSIT.value,
            DeliveryStatus.DELIVERED.value,
        }:
            rider_fee = RIDER_FIXED_EARNING

    admin_share_rider_fee = rider_fee * (RIDER_FEE_ADMIN_SHARE_PERCENT / 100.0)
    seller_share_rider_fee = rider_fee * (RIDER_FEE_SELLER_SHARE_PERCENT / 100.0)

    seller_payout = float(subtotal - admin_commission - seller_share_rider_fee)
    if seller_payout < 0.0:
        seller_payout = 0.0

    platform_fee = float(admin_commission + admin_share_rider_fee)
    phase = "after_pickup" if rider_fee > 0.0 else "before_pickup"

    return {
        "subtotal": subtotal,
        "adminCommission": admin_commission,
        "riderFeeTotal": rider_fee,
        "adminShareOfRiderFee": admin_share_rider_fee,
        "sellerShareOfRiderFee": seller_share_rider_fee,
        "sellerPayout": seller_payout,
        "platformFee": platform_fee,
        "phase": phase,
    }


ADMIN_APPROVE_STATUSES = {
    RefundStatus.DISPUTED,
    RefundStatus.EVIDENCE_REQUESTED,
    RefundStatus.ADMIN_REVIEW,
    RefundStatus.APPROVED_BY_SELLER,
}

ADMIN_QUEUE_STATUSES = {
    RefundStatus.DISPUTED,
    RefundStatus.EVIDENCE_REQUESTED,
    RefundStatus.ADMIN_REVIEW,
}


class RefundService:
    @classmethod
    def _load_refund(cls, refund_id: int) -> RefundRequest | None:
        return db.session.execute(
            select(RefundRequest)
            .where(RefundRequest.id == refund_id)
            .options(
                selectinload(RefundRequest.payment_transaction),
                selectinload(RefundRequest.order).selectinload(Order.deliveries),
                selectinload(RefundRequest.buyer),
            )
        ).scalar_one_or_none()

    @classmethod
    def process_refund(
        cls,
        refund_id: int,
        *,
        actor: Literal["seller", "admin"],
    ) -> tuple[RefundRequest | None, str | None]:
        refund = cls._load_refund(refund_id)
        if refund is None:
            return None, "Refund request not found"

        if refund.is_transaction_frozen:
            return None, "Refund transaction is frozen by admin"

        if actor == "seller":
            if refund.status != RefundStatus.REQUESTED:
                return None, "Refund is not awaiting seller review"
        else:
            if refund.status not in ADMIN_APPROVE_STATUSES:
                return None, "Admin can only approve disputed or seller-approved refunds"

        tx = refund.payment_transaction
        if tx is None:
            return None, "Payment transaction not found"

        if tx.status == PaymentStatus.REFUNDED or refund.status == RefundStatus.APPROVED:
            return None, "Refund already processed"

        order = refund.order
        if order is None or order.buyer_id is None:
            return None, "Order or buyer not found"

        if tx.status == PaymentStatus.HELD:
            tx.status = PaymentStatus.REFUNDED
        elif tx.status == PaymentStatus.SETTLED:
            tx.status = PaymentStatus.REFUNDED
            financials = compute_order_financials_for_refund(order)
            seller_payout = float(financials["sellerPayout"])
            if tx.seller_id is not None and seller_payout > 0.0:
                wallet = db.session.execute(
                    select(SellerWallet).where(SellerWallet.seller_id == tx.seller_id)
                ).scalar_one_or_none()
                if wallet is None:
                    wallet = SellerWallet(seller_id=tx.seller_id, balance=0.0)
                    db.session.add(wallet)
                wallet.balance = float(wallet.balance or 0.0) - seller_payout

        tx.updated_at = dt.datetime.utcnow()
        refund.status = RefundStatus.APPROVED
        refund.updated_at = dt.datetime.utcnow()

        notify_buyer_refund_approved(user_id=order.buyer_id, order_id=order.id)
        return refund, None

    @classmethod
    def reject_refund(
        cls,
        refund_id: int,
        *,
        actor: Literal["seller", "admin"],
        note: Optional[str] = None,
    ) -> tuple[RefundRequest | None, str | None]:
        refund = cls._load_refund(refund_id)
        if refund is None:
            return None, "Refund request not found"

        order = refund.order
        if order is None or order.buyer_id is None:
            return None, "Order or buyer not found"

        if actor == "seller":
            if refund.status in {
                RefundStatus.APPROVED,
                RefundStatus.REJECTED,
                RefundStatus.REJECTED_BY_SELLER,
            }:
                return None, "Refund already finalized"
            refund.status = RefundStatus.REJECTED_BY_SELLER
            if note:
                refund.seller_response_note = note
            notify_buyer_refund_seller_rejected(user_id=order.buyer_id, order_id=order.id)
        else:
            if refund.status in {RefundStatus.APPROVED, RefundStatus.REJECTED}:
                return None, "Refund already finalized"
            if refund.status not in ADMIN_QUEUE_STATUSES:
                return None, "Admin can only reject disputed refunds"
            refund.status = RefundStatus.REJECTED
            if note:
                refund.admin_note = note
            notify_buyer_refund_declined(user_id=order.buyer_id, order_id=order.id)

        refund.updated_at = dt.datetime.utcnow()
        return refund, None

    @classmethod
    def dispute_refund(
        cls,
        refund_id: int,
        buyer_id: int,
        *,
        note: Optional[str] = None,
        evidence_paths: Optional[list[str]] = None,
    ) -> tuple[RefundRequest | None, str | None]:
        refund = cls._load_refund(refund_id)
        if refund is None:
            return None, "Refund request not found"

        if refund.buyer_id != buyer_id:
            return None, "Unauthorized"

        if refund.status != RefundStatus.REJECTED_BY_SELLER:
            return None, "Only seller-rejected refunds can be disputed"

        refund.status = RefundStatus.DISPUTED
        refund.disputed_at = dt.datetime.utcnow()
        refund.updated_at = dt.datetime.utcnow()
        if note:
            refund.buyer_evidence_note = note
        if evidence_paths:
            refund.evidence_paths_json = json.dumps(evidence_paths)

        try:
            from app.models import User, Role, RoleTypes, UserRole

            admin_ids = db.session.execute(
                select(User.id)
                .join(UserRole)
                .join(Role)
                .where(Role.id == RoleTypes.ADMIN.value)
            ).scalars().all()
            for admin_id in admin_ids:
                notify_admin_refund_disputed(admin_user_id=admin_id, order_id=refund.order_id or 0)
        except Exception:
            pass

        return refund, None

    @classmethod
    def freeze_transaction(cls, refund_id: int) -> tuple[RefundRequest | None, str | None]:
        refund = cls._load_refund(refund_id)
        if refund is None:
            return None, "Refund request not found"

        refund.is_transaction_frozen = True
        refund.frozen_at = dt.datetime.utcnow()
        refund.updated_at = dt.datetime.utcnow()
        return refund, None

    @classmethod
    def request_evidence(cls, refund_id: int, admin_note: str) -> tuple[RefundRequest | None, str | None]:
        refund = cls._load_refund(refund_id)
        if refund is None:
            return None, "Refund request not found"

        if refund.status not in ADMIN_QUEUE_STATUSES | {RefundStatus.DISPUTED}:
            return None, "Evidence can only be requested for disputed refunds"

        refund.status = RefundStatus.EVIDENCE_REQUESTED
        refund.admin_note = admin_note
        refund.evidence_requested_at = dt.datetime.utcnow()
        refund.updated_at = dt.datetime.utcnow()
        return refund, None
