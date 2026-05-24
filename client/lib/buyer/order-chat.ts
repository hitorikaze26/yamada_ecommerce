import { chatApi } from "@/lib/api"
import type { PendingOrderShare } from "@/lib/chat/types"

export interface BuyerOrderChatInput {
  orderId: number
  storeId: number
  productName?: string
  productImageUrl?: string | null
  status?: string
  totalAmount?: number
  displayId?: string
}

/** Open or create buyer–seller chat for an order; returns conversation id. */
export async function openBuyerOrderChat(
  input: BuyerOrderChatInput | number,
): Promise<{ conversationId: number | null; pendingOrderShare: PendingOrderShare | null }> {
  const params =
    typeof input === "number"
      ? { orderId: input, storeId: 0 }
      : input

  if (!params.storeId) {
    return { conversationId: null, pendingOrderShare: null }
  }

  try {
    const res = await chatApi.createConversation({
      kind: "buyer_seller",
      storeId: params.storeId,
      orderId: params.orderId,
    })
    const id = res.data.conversation?.id ?? null
    if (id == null) return { conversationId: null, pendingOrderShare: null }

    const pendingOrderShare: PendingOrderShare | null =
      typeof input !== "number"
        ? {
            orderId: input.orderId,
            productName:
              input.productName?.trim() ||
              input.displayId?.trim() ||
              `Order ${input.orderId}`,
            productImageUrl: input.productImageUrl,
            status: input.status ?? "",
            totalAmount: input.totalAmount ?? 0,
            displayId: input.displayId ?? String(input.orderId),
          }
        : null

    return { conversationId: id, pendingOrderShare }
  } catch {
    return { conversationId: null, pendingOrderShare: null }
  }
}

export function resolveStoreIdFromOrder(order: {
  store?: { id?: number }
  seller?: { id?: string }
  items?: Array<{ sellerId?: string; product?: { sellerId?: string } }>
}): number | null {
  const store = order.store?.id
  if (store != null) return Number(store)
  const first = order.items?.[0]
  const fromItem = first?.sellerId ?? first?.product?.sellerId ?? order.seller?.id
  if (fromItem == null) return null
  const n = Number(fromItem)
  return Number.isNaN(n) ? null : n
}

export async function openSupportChat(): Promise<number | null> {
  try {
    const res = await chatApi.getSupportConversation()
    return res.data.conversation?.id ?? null
  } catch {
    return null
  }
}
