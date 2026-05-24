import { chatApi } from "@/lib/api"
import type { PendingOrderShare } from "@/lib/chat/types"

export interface SellerOrderChatInput {
  orderId: number
  productName?: string
  productImageUrl?: string | null
  status?: string
  totalAmount?: number
  displayId?: string
}

/** Open or create seller–buyer chat for an order; returns conversation id. */
export async function openSellerOrderChat(
  input: SellerOrderChatInput | number,
): Promise<{ conversationId: number | null; pendingOrderShare: PendingOrderShare | null }> {
  const orderId = typeof input === "number" ? input : input.orderId

  try {
    const res = await chatApi.openOrderChat(orderId)
    const id = res.data.conversation?.id ?? null
    if (id == null) return { conversationId: null, pendingOrderShare: null }

    const pendingOrderShare: PendingOrderShare | null =
      typeof input !== "number"
        ? {
            orderId,
            productName:
              input.productName?.trim() ||
              input.displayId?.trim() ||
              `Order ${orderId}`,
            productImageUrl: input.productImageUrl,
            status: input.status ?? "",
            totalAmount: input.totalAmount ?? 0,
            displayId: input.displayId ?? String(orderId),
          }
        : null

    return { conversationId: id, pendingOrderShare }
  } catch {
    return { conversationId: null, pendingOrderShare: null }
  }
}
