import { resolveImageUrl } from "@/lib/api"
import type { SerializedReview } from "@/lib/review-types"

function str(raw: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return String(v)
  }
  return ""
}

function num(raw: Record<string, unknown>, ...keys: string[]): number {
  for (const k of keys) {
    const v = raw[k]
    if (typeof v === "number") return v
  }
  return Number(_read(raw, keys) ?? 0)
}

function _read(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

export function normalizeReview(raw: Record<string, unknown>): SerializedReview {
  return {
    id: num(raw, "id"),
    rating: num(raw, "rating"),
    reviewFormat: (raw.reviewFormat as SerializedReview["reviewFormat"]) ?? undefined,
    ratings: typeof raw.ratings === "object" && raw.ratings !== null
      ? (raw.ratings as Record<string, number>)
      : undefined,
    comment: (raw.comment as string) ?? (raw.customerReview as string) ?? null,
    deliverySatisfaction: typeof raw.deliverySatisfaction === "number" ? raw.deliverySatisfaction : null,
    deliveryPills: Array.isArray(raw.deliveryPills) ? (raw.deliveryPills as string[]) : undefined,
    createdAt: (raw.createdAt as string) ?? (raw.created_at as string) ?? null,
    productId: raw.productId != null ? num(raw, "productId", "product_id") : null,
    productName: (raw.productName as string) ?? (raw.product_name as string) ?? null,
    buyerName: (raw.buyerName as string) ?? (raw.buyer_name as string) ?? null,
    sellerReply: (raw.sellerReply as string) ?? (raw.seller_reply as string) ?? null,
    sellerReplyAt: (raw.sellerReplyAt as string) ?? (raw.seller_reply_at as string) ?? null,
    variant: (raw.variant as string) ?? null,
    unitPrice: typeof raw.unitPrice === "number" ? raw.unitPrice : typeof raw.unit_price === "number" ? raw.unit_price : null,
    quantity: num(raw, "quantity"),
    orderItemId: raw.orderItemId != null ? num(raw, "orderItemId", "order_item_id") : null,
    orderId: raw.orderId != null ? num(raw, "orderId", "order_id") : null,
    productImage: resolveImageUrl((raw.productImage as string) ?? (raw.product_image as string) ?? null),
  }
}

export function normalizeReviewList(rawList: unknown[]): SerializedReview[] {
  return rawList.map(item => normalizeReview(item as Record<string, unknown>))
}
