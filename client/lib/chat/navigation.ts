import type { PendingOrderShare } from "@/lib/chat/types"
import { stashPendingOrderShare } from "@/lib/chat/open-chat"
import { openBuyerOrderChat, type BuyerOrderChatInput } from "@/lib/buyer/order-chat"
import { openSellerOrderChat, type SellerOrderChatInput } from "@/lib/seller/order-chat"
import { openRiderSellerChat } from "@/lib/rider/store-chat"
import { openBuyerStoreChat } from "@/lib/buyer/store-chat"

export type ChatOpenResult = {
  conversationId: number | null
  pendingOrderShare: PendingOrderShare | null
}

/** Build pending order card for buyer order → chat (queued above composer, not auto-sent). */
export function pendingOrderShareFromBuyerOrder(order: {
  id: string | number
  orderNumber?: string
  status: string
  total: number
  items: Array<{
    product?: { name?: string; imageUrl?: string; image_url?: string }
    productName?: string
    productImage?: string
  }>
}): PendingOrderShare {
  const first = order.items[0]
  const name =
    first?.product?.name?.trim() ||
    first?.productName?.trim() ||
    ""
  const orderId = Number(order.id)
  return {
    orderId,
    productName: name || order.orderNumber || `Order ${order.id}`,
    productImageUrl:
      first?.product?.imageUrl ?? first?.product?.image_url ?? first?.productImage ?? null,
    status: order.status,
    totalAmount: order.total,
    displayId: order.orderNumber ?? String(order.id),
  }
}

/** Build pending order card for seller order → chat. */
export function pendingOrderShareFromSellerOrder(order: {
  backendId: number
  id: string
  status: string
  total: number
  items: Array<{
    product?: { name?: string; images?: string[] }
    productName?: string
    productImageUrl?: string
  }>
}): PendingOrderShare {
  const first = order.items[0]
  const name = first?.product?.name?.trim() || first?.productName?.trim() || ""
  return {
    orderId: order.backendId,
    productName: name || order.id,
    productImageUrl: first?.product?.images?.[0] ?? first?.productImageUrl ?? null,
    status: order.status,
    totalAmount: order.total,
    displayId: order.id,
  }
}

export function stashPendingShareIfAny(
  conversationId: number,
  pending: PendingOrderShare | null,
): void {
  if (pending) stashPendingOrderShare(conversationId, pending)
}

export function openChatQuery(pathname: string, conversationId: number): string {
  const base = pathname.split("?")[0] || pathname
  return `${base}?openChat=${conversationId}`
}

export async function openBuyerOrderChatFromPage(
  input: BuyerOrderChatInput,
): Promise<ChatOpenResult> {
  const result = await openBuyerOrderChat(input)
  return {
    conversationId: result.conversationId,
    pendingOrderShare: result.pendingOrderShare,
  }
}

export async function openSellerOrderChatFromPage(
  input: SellerOrderChatInput,
): Promise<ChatOpenResult> {
  const result = await openSellerOrderChat(input)
  return {
    conversationId: result.conversationId,
    pendingOrderShare: result.pendingOrderShare,
  }
}

export async function openRiderSellerChatFromPage(
  storeId: number,
  orderId?: number,
): Promise<ChatOpenResult> {
  const conversationId = await openRiderSellerChat(storeId, orderId)
  return { conversationId, pendingOrderShare: null }
}

export async function openBuyerStoreChatFromPage(storeId: number): Promise<ChatOpenResult> {
  const conversationId = await openBuyerStoreChat(storeId)
  return { conversationId, pendingOrderShare: null }
}

export function canMessageSellerForBuyerOrder(order: {
  status: string
  store?: { id?: number }
  seller?: { id?: string }
  items?: Array<{ sellerId?: string; product?: { sellerId?: string } }>
}): boolean {
  if (order.status.toLowerCase() === "cancelled") return false
  const storeId =
    order.store?.id ??
    (order.items?.[0]?.sellerId != null ? Number(order.items[0].sellerId) : null) ??
    (order.items?.[0]?.product?.sellerId != null
      ? Number(order.items[0].product.sellerId)
      : null) ??
    (order.seller?.id != null ? Number(order.seller.id) : null)
  return storeId != null && !Number.isNaN(storeId)
}
