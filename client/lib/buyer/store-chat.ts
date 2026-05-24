import { chatApi } from "@/lib/api"

/** Open or create buyer–seller chat for a store; returns conversation id. */
export async function openBuyerStoreChat(storeId: number): Promise<number | null> {
  try {
    const res = await chatApi.createConversation({
      kind: "buyer_seller",
      storeId,
    })
    return res.data.conversation?.id ?? null
  } catch {
    return null
  }
}
