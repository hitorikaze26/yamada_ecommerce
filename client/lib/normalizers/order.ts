import type { Order, OrderItem, OrderStatus } from "@/lib/types"
import { resolveImageUrl } from "@/lib/api"
import { normalizeProduct } from "./product"

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
  return Number(readRaw(raw, keys) ?? 0)
}

function readRaw(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

export function normalizeOrderStatus(status: string): string {
  return status.toLowerCase().trim().replace(/\s+/g, "_")
}

export function normalizeOrderItem(raw: Record<string, unknown>): OrderItem {
  const productRaw = (raw.product ?? raw.productData ?? {}) as Record<string, unknown>
  const variationRaw = (raw.variation ?? raw.selectedVariation ?? {}) as Record<string, unknown>
  return {
    id: str(raw, "id", "itemId", "orderItemId") || undefined,
    product: normalizeProduct(productRaw),
    quantity: num(raw, "quantity"),
    variation: {
      id: str(variationRaw, "id"),
      size: str(variationRaw, "size"),
      color: str(variationRaw, "color"),
      colorHex: str(variationRaw, "colorHex", "color_hex") || undefined,
      sku: str(variationRaw, "sku"),
      inventory: num(variationRaw, "inventory"),
      price: typeof variationRaw.price === "number" ? variationRaw.price : undefined,
    },
    price: num(raw, "price", "unitPrice", "unit_price"),
    sellerId: str(raw, "sellerId", "seller_id", "storeId", "store_id") || undefined,
    sellerName: str(raw, "sellerName", "seller_name", "storeName", "store_name") || undefined,
  }
}

export function normalizeOrder(raw: Record<string, unknown>): Order {
  const itemsRaw = Array.isArray(raw.items) ? (raw.items as Record<string, unknown>[]) : []
  const buyerRaw = (raw.buyer ?? raw.buyerData ?? {}) as Record<string, unknown>
  const sellerRaw = (raw.seller ?? raw.sellerData ?? raw.store ?? {}) as Record<string, unknown>
  const riderRaw = (raw.rider ?? raw.riderData ?? {}) as Record<string, unknown>
  const addressRaw = (raw.shippingAddress ?? raw.address ?? {}) as Record<string, unknown>

  const items: OrderItem[] = itemsRaw.map(normalizeOrderItem)

  const status = normalizeOrderStatus(str(raw, "status", "orderStatus", "order_status"))
  const validStatuses: OrderStatus[] = [
    "pending", "confirmed", "processing", "shipped",
    "out_for_delivery", "delivered", "cancelled", "returned",
  ]
  const orderStatus: OrderStatus = validStatuses.includes(status as OrderStatus)
    ? (status as OrderStatus)
    : "pending"

  return {
    id: str(raw, "id", "orderId", "order_id"),
    orderNumber: str(raw, "orderNumber", "order_number"),
    buyer: {
      id: str(buyerRaw, "id", "userId", "user_id"),
      name: str(buyerRaw, "name", "givenName", "given_name"),
      email: str(buyerRaw, "email"),
    },
    seller: {
      id: str(sellerRaw, "id", "storeId", "store_id", "userId", "user_id"),
      shopName: str(sellerRaw, "shopName", "shop_name", "name"),
    },
    rider: riderRaw.id
      ? {
          id: str(riderRaw, "id", "riderId", "rider_id", "userId", "user_id"),
          name: str(riderRaw, "name", "givenName", "given_name"),
          contactNumber: str(riderRaw, "contactNumber", "contact_number"),
        }
      : undefined,
    items,
    shippingAddress: {
      id: str(addressRaw, "id") || "addr",
      regionCode: str(addressRaw, "regionCode", "region_code"),
      regionName: str(addressRaw, "regionName", "region_name"),
      provinceCode: str(addressRaw, "provinceCode", "province_code"),
      provinceName: str(addressRaw, "provinceName", "province_name"),
      municipalityCode: str(addressRaw, "municipalityCode", "municipality_code"),
      municipalityName: str(addressRaw, "municipalityName", "municipality_name"),
      barangayCode: str(addressRaw, "barangayCode", "barangay_code"),
      barangayName: str(addressRaw, "barangayName", "barangay_name"),
      streetAddress: str(addressRaw, "streetAddress", "street_address") || undefined,
      postalCode: str(addressRaw, "postalCode", "postal_code") || undefined,
      isDefault: false,
    },
    paymentMethod: str(raw, "paymentMethod", "payment_method"),
    paymentStatus: (str(raw, "paymentStatus", "payment_status") as Order["paymentStatus"]) || "pending",
    status: orderStatus,
    subtotal: num(raw, "subtotal"),
    shipping: num(raw, "shipping", "shippingFee", "shipping_fee"),
    total: num(raw, "total", "grandTotal", "grand_total"),
    createdAt: str(raw, "createdAt", "created_at", new Date().toISOString()),
    updatedAt: str(raw, "updatedAt", "updated_at", new Date().toISOString()),
  }
}

export function normalizeOrderList(rawList: unknown[]): Order[] {
  return rawList.map(item => normalizeOrder(item as Record<string, unknown>))
}

// Buyer-facing order tracking helpers
export const ORDER_TRACKING_STEPS = [
  { key: "confirmed", label: "Order confirmed", icon: "check" },
  { key: "packed", label: "Packed", icon: "box" },
  { key: "shipped", label: "Shipped", icon: "truck-loading" },
  { key: "out_for_delivery", label: "Out for delivery", icon: "motorcycle" },
  { key: "delivered", label: "Delivered", icon: "home" },
] as const

export function getEffectiveOrderStatus(
  orderStatus: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): string {
  const order = normalizeOrderStatus(orderStatus)
  const rider = riderDeliveryStatus ? normalizeOrderStatus(riderDeliveryStatus) : null
  const hasProof = Boolean(riderHasProofPhoto) || Boolean(riderProofPhotoUrl?.trim())
  const riderComplete = rider === "delivered" || hasProof
  if (riderComplete && !["delivered", "completed", "cancelled", "canceled", "returned"].includes(order)) {
    return "delivered"
  }
  return order
}

export function canBuyerConfirmReceipt(
  orderStatus: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): boolean {
  const raw = normalizeOrderStatus(orderStatus)
  if (["completed", "cancelled", "canceled", "returned", "pending"].includes(raw)) return false
  const effective = getEffectiveOrderStatus(orderStatus, riderDeliveryStatus, riderProofPhotoUrl, riderHasProofPhoto)
  return effective === "delivered" || raw === "out_for_delivery"
}

export function canBuyerLeaveReview(orderStatus: string): boolean {
  return normalizeOrderStatus(orderStatus) === "completed"
}

export function getOrderTimelineIndex(status: string): number {
  const s = normalizeOrderStatus(status)
  if (["cancelled", "canceled", "returned", "pending"].includes(s)) return -1
  if (["confirmed", "processing"].includes(s)) return 0
  if (s === "packed") return 1
  if (s === "shipped") return 2
  if (s === "out_for_delivery") return 3
  if (["delivered", "completed"].includes(s)) return 4
  return 0
}

export function formatOrderStatusLabel(status: string): string {
  const s = normalizeOrderStatus(status)
  const labels: Record<string, string> = {
    pending: "Pending payment",
    confirmed: "Confirmed",
    processing: "Processing",
    packed: "Packed",
    shipped: "Shipped",
    out_for_delivery: "Out for delivery",
    delivered: "Delivered",
    completed: "Completed",
    cancelled: "Cancelled",
    canceled: "Cancelled",
    returned: "Returned",
  }
  return labels[s] || s.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
}

export function shouldPollOrderStatus(
  status: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): boolean {
  const s = getEffectiveOrderStatus(status, riderDeliveryStatus, riderProofPhotoUrl, riderHasProofPhoto)
  return ["confirmed", "processing", "packed", "shipped", "out_for_delivery"].includes(s)
}

export function orderStatusBadgeClass(status: string): string {
  return orderStatusColors[status] ?? "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400"
}

export function isOrderDelivered(status: string): boolean {
  return status === "delivered" || status === "completed"
}