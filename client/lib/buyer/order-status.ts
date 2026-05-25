import { orderStatusColors } from "@/lib/order-status"

/** Buyer-facing order tracking steps (aligned with mobile OrderTrackingTimeline). */
export const ORDER_TRACKING_STEPS = [
  { key: "confirmed", label: "Order confirmed", icon: "check" },
  { key: "packed", label: "Packed", icon: "box" },
  { key: "shipped", label: "Shipped", icon: "truck-loading" },
  { key: "out_for_delivery", label: "Out for delivery", icon: "motorcycle" },
  { key: "delivered", label: "Delivered", icon: "home" },
] as const

export function normalizeOrderStatus(status: string): string {
  return status.toLowerCase().trim().replace(/\s+/g, "_")
}

/** Rider delivery completed but orders.status may lag — use for display and actions. */
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

  if (
    riderComplete &&
    !["delivered", "completed", "cancelled", "canceled", "returned"].includes(order)
  ) {
    return "delivered"
  }
  return order
}

/** Buyer can confirm received (package arrived, order not yet completed). */
export function canBuyerConfirmReceipt(
  orderStatus: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): boolean {
  const raw = normalizeOrderStatus(orderStatus)
  if (["completed", "cancelled", "canceled", "returned", "pending"].includes(raw)) {
    return false
  }
  const effective = getEffectiveOrderStatus(
    orderStatus,
    riderDeliveryStatus,
    riderProofPhotoUrl,
    riderHasProofPhoto,
  )
  return effective === "delivered" || raw === "out_for_delivery"
}

export function canBuyerLeaveReview(orderStatus: string): boolean {
  return normalizeOrderStatus(orderStatus) === "completed"
}

export function isOrderDelivered(
  orderStatus: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): boolean {
  const s = getEffectiveOrderStatus(
    orderStatus,
    riderDeliveryStatus,
    riderProofPhotoUrl,
    riderHasProofPhoto,
  )
  return s === "delivered" || s === "completed"
}

export function riderHasProofOfDelivery(rider?: {
  proofPhotoUrl?: string | null
  hasProofPhoto?: boolean | null
  proofNote?: string | null
} | null): boolean {
  if (!rider) return false
  return Boolean(rider.hasProofPhoto) || Boolean(rider.proofPhotoUrl?.trim()) || Boolean(rider.proofNote?.trim())
}

/**
 * Active timeline step index, or -1 when timeline should not show (pending/cancelled).
 * 0 = confirmed … 4 = delivered/completed
 */
export function getOrderTimelineIndex(status: string): number {
  const s = normalizeOrderStatus(status)
  if (s === "cancelled" || s === "canceled" || s === "returned") return -1
  if (s === "pending") return -1
  if (s === "confirmed" || s === "processing") return 0
  if (s === "packed") return 1
  if (s === "shipped") return 2
  if (s === "out_for_delivery") return 3
  if (s === "delivered" || s === "completed") return 4
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
  if (labels[s]) return labels[s]
  return s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}

export function orderStatusBadgeClass(status: string): string {
  const s = normalizeOrderStatus(status)
  return orderStatusColors[s] || "bg-muted text-muted-foreground"
}

/** Statuses where the order may still change — poll for updates on the detail page. */
export function shouldPollOrderStatus(
  status: string,
  riderDeliveryStatus?: string | null,
  riderProofPhotoUrl?: string | null,
  riderHasProofPhoto?: boolean | null,
): boolean {
  const s = getEffectiveOrderStatus(status, riderDeliveryStatus, riderProofPhotoUrl, riderHasProofPhoto)
  return ["confirmed", "processing", "packed", "shipped", "out_for_delivery"].includes(s)
}
