import type { PendingOrderShare } from "@/lib/chat/types"

/** Store pending order share until thread opens (used with ?openChat= deep links). */
const pendingByConversation = new Map<number, PendingOrderShare>()

export function stashPendingOrderShare(conversationId: number, share: PendingOrderShare) {
  pendingByConversation.set(conversationId, share)
}

export function takePendingOrderShare(conversationId: number): PendingOrderShare | null {
  const share = pendingByConversation.get(conversationId) ?? null
  pendingByConversation.delete(conversationId)
  return share
}
