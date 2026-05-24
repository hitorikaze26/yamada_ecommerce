"use client"

import { useCallback, useState } from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { useChat } from "@/context/chat-context"
import {
  openBuyerOrderChatFromPage,
  openBuyerStoreChatFromPage,
  openRiderSellerChatFromPage,
  openSellerOrderChatFromPage,
  openChatQuery,
  stashPendingShareIfAny,
  type ChatOpenResult,
} from "@/lib/chat/navigation"
import type { BuyerOrderChatInput } from "@/lib/buyer/order-chat"
import type { SellerOrderChatInput } from "@/lib/seller/order-chat"

type OpenTarget =
  | { kind: "home" }
  | { kind: "path"; pathname: string }
  | { kind: "pending" }

/**
 * Mobile-parity chat open: disable trigger while API runs, stash pending order share,
 * then navigate or open inbox modal.
 */
export function useChatOpen() {
  const router = useRouter()
  const { setPendingOpenConversationId } = useChat()
  const [busyKey, setBusyKey] = useState<string | null>(null)

  const isBusy = useCallback((key: string) => busyKey === key, [busyKey])

  const runOpen = useCallback(
    async (
      key: string,
      openFn: () => Promise<ChatOpenResult>,
      target: OpenTarget,
    ): Promise<boolean> => {
      if (busyKey != null) return false
      setBusyKey(key)
      try {
        const { conversationId, pendingOrderShare } = await openFn()
        if (conversationId == null) {
          toast.error("Could not open chat", {
            description: "Try again from the messages icon in the header.",
          })
          return false
        }
        stashPendingShareIfAny(conversationId, pendingOrderShare)
        if (target.kind === "pending") {
          setPendingOpenConversationId(conversationId)
        } else if (target.kind === "home") {
          router.push(`/home?openChat=${conversationId}`)
        } else {
          router.push(openChatQuery(target.pathname, conversationId))
        }
        return true
      } catch {
        toast.error("Could not open chat")
        return false
      } finally {
        setBusyKey(null)
      }
    },
    [busyKey, router, setPendingOpenConversationId],
  )

  const openBuyerOrder = useCallback(
    (key: string, input: BuyerOrderChatInput) =>
      runOpen(key, () => openBuyerOrderChatFromPage(input), { kind: "home" }),
    [runOpen],
  )

  const openBuyerOrderOnPath = useCallback(
    (key: string, input: BuyerOrderChatInput, pathname: string) =>
      runOpen(key, () => openBuyerOrderChatFromPage(input), { kind: "path", pathname }),
    [runOpen],
  )

  const openSellerOrder = useCallback(
    (key: string, input: SellerOrderChatInput, sellerPath = "/seller/orders") =>
      runOpen(key, () => openSellerOrderChatFromPage(input), {
        kind: "path",
        pathname: sellerPath,
      }),
    [runOpen],
  )

  const openRiderToSeller = useCallback(
    (key: string, storeId: number, orderId?: number) =>
      runOpen(key, () => openRiderSellerChatFromPage(storeId, orderId), { kind: "pending" }),
    [runOpen],
  )

  const openBuyerStore = useCallback(
    (key: string, storeId: number, pathname: string) =>
      runOpen(key, () => openBuyerStoreChatFromPage(storeId), { kind: "path", pathname }),
    [runOpen],
  )

  return {
    busyKey,
    isBusy,
    openBuyerOrder,
    openBuyerOrderOnPath,
    openSellerOrder,
    openRiderToSeller,
    openBuyerStore,
  }
}
