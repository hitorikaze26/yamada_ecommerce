"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { ChatListSheet } from "@/components/chat/chat-list-sheet"
import { ChatConversationModal } from "@/components/chat/chat-conversation-modal"
import { useChat } from "@/context/chat-context"
import { useAuth } from "@/context/auth-context"
import {
  canOpenSupport,
  filtersForRole,
  type ChatConversation,
  type ChatMessage,
} from "@/lib/chat/types"
import { toast } from "sonner"
import { takePendingOrderShare } from "@/lib/chat/open-chat"

interface ChatInboxButtonProps {
  className?: string
  iconSize?: "lg" | "md" | "sm"
  /** When set, opens this conversation (e.g. from ?openChat= deep link). */
  openConversationId?: string | number | null
  onOpenConversationHandled?: () => void
}

export function ChatInboxButton({
  className,
  iconSize = "lg",
  openConversationId,
  onOpenConversationHandled,
}: ChatInboxButtonProps) {
  const { getRole, isAuthenticated } = useAuth()
  const role = getRole()
  const {
    conversations,
    unreadTotal,
    isLoadingList,
    threadTick,
    getThread,
    loadConversations,
    openConversation,
    openSupport,
    markConversationRead,
    deleteConversation,
    archiveConversation,
    togglePin,
    sendText,
    sendComposer,
    uploadAndSend,
    sendRich,
    setPendingOrderShare,
    setReplyTo,
    loadMoreMessages,
    pendingOpenConversationId,
    setPendingOpenConversationId,
  } = useChat()

  const [isListOpen, setIsListOpen] = useState(false)
  const [activeId, setActiveId] = useState<number | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)

  const handledDeepLinkRef = useRef<number | null>(null)
  const onOpenConversationHandledRef = useRef(onOpenConversationHandled)
  onOpenConversationHandledRef.current = onOpenConversationHandled

  const filters = useMemo(() => filtersForRole(role), [role])

  const activeConversation = useMemo(
    () => conversations.find((c) => c.id === activeId) ?? null,
    [conversations, activeId],
  )

  const thread = activeId != null ? getThread(activeId) : getThread(0)
  void threadTick

  const openConv = useCallback(
    async (conv: ChatConversation) => {
      setActiveId(conv.id)
      setIsModalOpen(true)
      setIsListOpen(false)
      await openConversation(conv.id)
    },
    [openConversation],
  )

  const handleCloseModal = useCallback(() => {
    setIsModalOpen(false)
    if (activeId != null) {
      setReplyTo(activeId, null)
    }
  }, [activeId, setReplyTo])

  // Deep link: ?openChat= — run once per conversation id
  useEffect(() => {
    if (!openConversationId || !isAuthenticated) {
      if (!openConversationId) handledDeepLinkRef.current = null
      return
    }
    const id = Number(openConversationId)
    if (Number.isNaN(id) || handledDeepLinkRef.current === id) return
    handledDeepLinkRef.current = id

    setActiveId(id)
    setIsModalOpen(true)
    void (async () => {
      const share = takePendingOrderShare(id)
      if (share) setPendingOrderShare(id, share)
      await openConversation(id)
    })()
    onOpenConversationHandledRef.current?.()
  }, [openConversationId, isAuthenticated, openConversation, setPendingOrderShare])

  // Rider / delivery: open via setPendingOpenConversationId
  const lastPendingRef = useRef<number | null>(null)
  useEffect(() => {
    if (pendingOpenConversationId == null) {
      lastPendingRef.current = null
      return
    }
    if (lastPendingRef.current === pendingOpenConversationId) return
    lastPendingRef.current = pendingOpenConversationId

    const id = pendingOpenConversationId
    setActiveId(id)
    setIsModalOpen(true)
    void (async () => {
      const share = takePendingOrderShare(id)
      if (share) setPendingOrderShare(id, share)
      await openConversation(id)
    })()
    setPendingOpenConversationId(null)
  }, [pendingOpenConversationId, openConversation, setPendingOpenConversationId, setPendingOrderShare])

  const handleSendText = useCallback(
    (text: string) => {
      if (activeId == null) return
      void sendComposer(activeId, text)
    },
    [activeId, sendComposer],
  )

  const handleSendFile = useCallback(
    (file: File) => {
      if (activeId == null) return
      void uploadAndSend(activeId, file)
    },
    [activeId, uploadAndSend],
  )

  const handleSendProduct = useCallback(
    (productId: number) => {
      if (activeId == null) return
      void sendRich(activeId, "product", "", { productId })
    },
    [activeId, sendRich],
  )

  const handleSendOrder = useCallback(
    (orderId: number) => {
      if (activeId == null) return
      void sendRich(activeId, "order", "", { orderId })
    },
    [activeId, sendRich],
  )

  const handleSetReply = useCallback(
    (msg: ChatMessage | null) => {
      if (activeId == null) return
      setReplyTo(activeId, msg)
    },
    [activeId, setReplyTo],
  )

  const handleLoadMore = useCallback(() => {
    if (activeId == null) return
    void loadMoreMessages(activeId)
  }, [activeId, loadMoreMessages])

  const unreadBadge = unreadTotal > 0 ? (unreadTotal > 9 ? "9+" : unreadTotal) : null

  if (!isAuthenticated) return null

  return (
    <>
      <Button
        variant="ghost"
        size="icon"
        className={className ?? "relative"}
        onClick={() => {
          setIsListOpen(true)
          void loadConversations(false)
        }}
        title="Messages"
      >
        <Icon name="envelope" size={iconSize} />
        {unreadBadge && (
          <span className="absolute -top-0.5 -right-0.5 min-w-[1.125rem] h-[1.125rem] px-1 bg-primary text-primary-foreground text-[10px] font-semibold rounded-full flex items-center justify-center ring-2 ring-background">
            {unreadBadge}
          </span>
        )}
        <span className="sr-only">
          Messages{unreadBadge ? `, ${unreadBadge} unread` : ""}
        </span>
      </Button>

      <ChatListSheet
        open={isListOpen}
        conversations={conversations}
        filters={filters}
        isLoading={isLoadingList}
        showSupportAction={canOpenSupport(role)}
        onClose={() => setIsListOpen(false)}
        onOpenConversation={(c) => void openConv(c)}
        onMarkAsRead={(id) => void markConversationRead(id)}
        onDelete={(id) => {
          void deleteConversation(id)
          if (activeId === id) {
            setActiveId(null)
            setIsModalOpen(false)
          }
        }}
        onToggleArchive={(id, archived) => void archiveConversation(id, archived)}
        onTogglePin={(c) => void togglePin(c)}
        onOpenSupport={() => {
          void (async () => {
            try {
              const conv = await openSupport()
              await openConv(conv)
            } catch {
              toast.error("Support chat unavailable")
            }
          })()
        }}
        onReload={(archived) => void loadConversations(archived)}
      />

      {activeId != null && (
        <ChatConversationModal
          open={isModalOpen}
          conversationId={activeId}
          conversation={activeConversation}
          thread={thread}
          role={role}
          onClose={handleCloseModal}
          onSendText={handleSendText}
          onSendFile={handleSendFile}
          onSendProduct={handleSendProduct}
          onSendOrder={handleSendOrder}
          onClearPendingOrder={() => setPendingOrderShare(activeId, null)}
          onDeleteConversation={() => {
            void deleteConversation(activeId)
            setIsModalOpen(false)
            setActiveId(null)
          }}
          onLoadMore={handleLoadMore}
          onSetReply={handleSetReply}
        />
      )}
    </>
  )
}
