import type { Order } from "@/lib/types"
import { getEffectiveOrderStatus } from "@/lib/buyer/order-status"

export type BuyerOrderFilterKey =
  | "all"
  | "to_pay"
  | "processing"
  | "packed"
  | "shipped"
  | "delivered"
  | "cancelled"

export const BUYER_ORDER_FILTERS: {
  key: BuyerOrderFilterKey
  label: string
  icon: string
}[] = [
  { key: "all", label: "All", icon: "receipt" },
  { key: "to_pay", label: "To pay", icon: "credit-card" },
  { key: "processing", label: "Processing", icon: "clock" },
  { key: "packed", label: "Packed", icon: "box" },
  { key: "shipped", label: "Shipped", icon: "truck" },
  { key: "delivered", label: "Delivered", icon: "check-circle" },
  { key: "cancelled", label: "Cancelled", icon: "times-circle" },
]

/** Map notification / legacy deep links to canonical filter keys. */
export function normalizeBuyerOrderFilter(raw: string | null | undefined): BuyerOrderFilterKey {
  const v = (raw ?? "all").toLowerCase().trim()
  switch (v) {
    case "pending":
    case "to_pay":
      return "to_pay"
    case "to_ship":
    case "confirmed":
      return "processing"
    case "to_receive":
    case "out_for_delivery":
    case "out for delivery":
      return "shipped"
    case "completed":
      return "delivered"
    case "processing":
    case "packed":
    case "shipped":
    case "delivered":
    case "cancelled":
    case "all":
      return v as BuyerOrderFilterKey
    default:
      return "all"
  }
}

type OrderWithRider = Order & {
  riderDelivery?: { status?: string; proofPhotoUrl?: string | null; hasProofPhoto?: boolean }
}

function statusMatches(order: Order, statuses: string[]): boolean {
  const rd = (order as OrderWithRider).riderDelivery
  const s = getEffectiveOrderStatus(order.status ?? "", rd?.status, rd?.proofPhotoUrl, rd?.hasProofPhoto)
  return statuses.includes(s)
}

export function matchesBuyerOrderFilter(order: Order, filter: BuyerOrderFilterKey): boolean {
  switch (filter) {
    case "all":
      return true
    case "to_pay":
      return statusMatches(order, ["pending"])
    case "processing":
      return statusMatches(order, ["confirmed", "processing"])
    case "packed":
      return statusMatches(order, ["packed"])
    case "shipped":
      return statusMatches(order, ["shipped", "out_for_delivery", "out for delivery"])
    case "delivered":
      return statusMatches(order, ["delivered", "completed"])
    case "cancelled":
      return statusMatches(order, ["cancelled"])
    default:
      return true
  }
}

export function countOrdersByBuyerFilter(orders: Order[]): Record<BuyerOrderFilterKey, number> {
  const counts = {} as Record<BuyerOrderFilterKey, number>
  for (const f of BUYER_ORDER_FILTERS) {
    counts[f.key] =
      f.key === "all"
        ? orders.length
        : orders.filter((o) => matchesBuyerOrderFilter(o, f.key)).length
  }
  return counts
}

export function filterOrdersByBuyerFilter(orders: Order[], filter: BuyerOrderFilterKey): Order[] {
  if (filter === "all") return orders
  return orders.filter((o) => matchesBuyerOrderFilter(o, filter))
}
