import { chatApi } from "@/lib/api"

/** Open or create rider–seller operational chat. */
export async function openRiderSellerChat(
  storeId: number,
  orderId?: number,
): Promise<number | null> {
  try {
    const res = await chatApi.createConversation({
      kind: "rider_seller",
      storeId,
      orderId,
    })
    return res.data.conversation?.id ?? null
  } catch {
    return null
  }
}
