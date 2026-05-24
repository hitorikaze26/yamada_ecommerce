"""Product moderation helpers for admin post-publish review."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from sqlalchemy import select

from app.models import (
    Product,
    ProductModerationLog,
    ProductModerationStatus,
    Order,
    OrderItem,
    Store,
    product_is_public,
    db,
)


def _status_value(status: ProductModerationStatus | str) -> str:
    if hasattr(status, "value"):
        return status.value
    return str(status)


def sync_is_live(product: Product, status: ProductModerationStatus) -> None:
    product.is_live = status == ProductModerationStatus.ACTIVE


def log_action(
    product: Product,
    action: str,
    *,
    admin_id: Optional[int] = None,
    note: Optional[str] = None,
) -> None:
    db.session.add(
        ProductModerationLog(
            product_id=product.id,
            admin_id=admin_id,
            action=action,
            note=note,
        )
    )


class ProductModerationService:
    @classmethod
    def set_status(
        cls,
        product: Product,
        status: ProductModerationStatus,
        *,
        admin_id: Optional[int] = None,
        reason: Optional[str] = None,
        notify_seller: bool = True,
    ) -> Product:
        product.moderation_status = status
        product.moderation_reason = reason
        product.moderation_updated_at = dt.datetime.now()
        product.moderation_updated_by = admin_id
        sync_is_live(product, status)
        log_action(product, f"status_{_status_value(status)}", admin_id=admin_id, note=reason)

        if notify_seller and product.store and product.store.user_id:
            try:
                from app.notifications.service import notify_seller_product_moderation

                notify_seller_product_moderation(
                    user_id=product.store.user_id,
                    product_name=product.name,
                    status=_status_value(status),
                    reason=reason,
                )
            except Exception:
                pass
        return product

    @classmethod
    def request_edits(
        cls,
        product: Product,
        note: str,
        *,
        admin_id: Optional[int] = None,
    ) -> Product:
        product.edit_requested_at = dt.datetime.now()
        product.edit_request_note = note
        if product.moderation_status == ProductModerationStatus.ACTIVE:
            cls.set_status(
                product,
                ProductModerationStatus.UNDER_REVIEW,
                admin_id=admin_id,
                reason=note,
                notify_seller=True,
            )
        else:
            log_action(product, "request_edits", admin_id=admin_id, note=note)
            if product.store and product.store.user_id:
                try:
                    from app.notifications.service import notify_seller_product_moderation

                    notify_seller_product_moderation(
                        user_id=product.store.user_id,
                        product_name=product.name,
                        status="edit_requested",
                        reason=note,
                    )
                except Exception:
                    pass
        return product

    @classmethod
    def flag_for_review(cls, product: Product, reason: str) -> Product:
        if product.moderation_status == ProductModerationStatus.ACTIVE:
            product.moderation_status = ProductModerationStatus.UNDER_REVIEW
            product.moderation_reason = reason
            product.moderation_updated_at = dt.datetime.now()
            sync_is_live(product, ProductModerationStatus.UNDER_REVIEW)
            log_action(product, "flagged_for_review", admin_id=None, note=reason)
        return product

    @classmethod
    def flag_products_for_store_report(
        cls,
        store_id: int,
        reason: str,
        *,
        order_id: Optional[int] = None,
    ) -> int:
        product_ids: set[int] = set()
        if order_id:
            items = db.session.execute(
                select(OrderItem.product_id).where(
                    OrderItem.order_id == order_id,
                    OrderItem.product_id.isnot(None),
                )
            ).scalars().all()
            product_ids.update(i for i in items if i)

        if product_ids:
            products = db.session.execute(
                select(Product).where(Product.id.in_(product_ids))
            ).scalars().all()
        else:
            products = db.session.execute(
                select(Product).where(
                    Product.store_id == store_id,
                    Product.moderation_status == ProductModerationStatus.ACTIVE,
                )
            ).scalars().all()

        count = 0
        for p in products:
            if p.store_id != store_id and store_id:
                store = db.session.get(Store, store_id)
                if store and p.store_id != store.id:
                    continue
            cls.flag_for_review(p, reason)
            count += 1
        return count

    @classmethod
    def serialize_moderation_brief(cls, product: Product) -> dict:
        return {
            "moderationStatus": _status_value(product.moderation_status),
            "moderationReason": product.moderation_reason,
            "editRequestedAt": product.edit_requested_at.isoformat() if product.edit_requested_at else None,
            "editRequestNote": product.edit_request_note,
            "canEdit": product.moderation_status not in (
                ProductModerationStatus.REMOVED,
                ProductModerationStatus.RESTRICTED,
            ),
            "isPublic": product_is_public(product),
        }
