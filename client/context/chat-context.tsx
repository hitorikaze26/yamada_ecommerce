"use client"

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react"
import { API_BASE_ORIGIN, chatApi } from "@/lib/api"
import {
  chatPreviewFromMessage,
  mapConversation,
  mapMessage,
  mapMessageFromPayload,
  mapPeer,
} from "@/lib/chat/mappers"
import { chatSocket } from "@/lib/chat/socket"
import type {
  ChatConversation,
  ChatMessage,
  ChatPeer,
  PendingOrderShare,
  ThreadState,
} from "@/lib/chat/types"
import { useAuth } from "@/context/auth-context"

interface ChatContextType {
  conversations: ChatConversation[]
  unreadTotal: number
  isLoadingList: boolean
  listError: string | null
  threadTick: number
  loadConversations: (archived?: boolean) => Promise<void>
  refreshUnread: () => Promise<void>
  openSupport: () => Promise<ChatConversation>
  openBuyerSeller: (storeId: number, orderId?: number) => Promise<ChatConversation>
  openOrderChatAsSeller: (orderId: number) => Promise<ChatConversation>
  openRiderSeller: (storeId: number, orderId?: number) => Promise<ChatConversation>
  getThread: (conversationId: number) => ThreadState
  loadThread: (conversationId: number) => Promise<void>
  loadMoreMessages: (conversationId: number) => Promise<void>
  openConversation: (conversationId: number) => Promise<void>
  setPendingOpenConversationId: (id: number | null) => void
  pendingOpenConversationId: number | null
  sendText: (conversationId: number, text: string) => Promise<void>
  /** Send typed message and any queued order share (mobile parity). */
  sendComposer: (conversationId: number, text: string) => Promise<void>
  sendRich: (
    conversationId: number,
    messageType: string,
    body?: string,
    metadata?: Record<string, unknown>,
  ) => Promise<void>
  uploadAndSend: (conversationId: number, file: File) => Promise<void>
  setReplyTo: (conversationId: number, msg: ChatMessage | null) => void
  setPendingOrderShare: (conversationId: number, share: PendingOrderShare | null) => void
  sendPendingOrderShare: (conversationId: number) => Promise<void>
  togglePin: (conv: ChatConversation) => Promise<void>
  archiveConversation: (conversationId: number, archive: boolean) => Promise<boolean>
  deleteConversation: (conversationId: number) => Promise<void>
  markConversationRead: (conversationId: number) => Promise<void>
}

const emptyThread = (): ThreadState => ({
  messages: [],
  conversation: null,
  peer: null,
  isLoading: false,
  isSending: false,
  hasMore: false,
  nextCursor: null,
  error: null,
  replyTo: null,
  pendingOrderShare: null,
})

const ChatContext = createContext<ChatContextType | undefined>(undefined)

function getStoredToken(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem("yamada-access-token")
}

export function ChatProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth()
  const [conversations, setConversations] = useState<ChatConversation[]>([])
  const [unreadTotal, setUnreadTotal] = useState(0)
  const [isLoadingList, setIsLoadingList] = useState(false)
  const [listError, setListError] = useState<string | null>(null)
  const [threadTick, setThreadTick] = useState(0)
  const [pendingOpenConversationId, setPendingOpenConversationId] = useState<number | null>(
    null,
  )
  const threadsRef = useRef<Map<number, ThreadState>>(new Map())
  const listArchivedRef = useRef(false)

  const tickThreads = useCallback(() => setThreadTick((n) => n + 1), [])

  const getThread = useCallback((conversationId: number): ThreadState => {
    return threadsRef.current.get(conversationId) ?? emptyThread()
  }, [threadTick])

  const setThread = useCallback(
    (conversationId: number, patch: Partial<ThreadState> | ((t: ThreadState) => ThreadState)) => {
      const prev = threadsRef.current.get(conversationId) ?? emptyThread()
      const next = typeof patch === "function" ? patch(prev) : { ...prev, ...patch }
      threadsRef.current.set(conversationId, next)
      tickThreads()
    },
    [tickThreads],
  )

  const bumpConversationPreview = useCallback((convId: number, msg: ChatMessage) => {
    const preview = chatPreviewFromMessage(msg)
    setConversations((list) => {
      const idx = list.findIndex((c) => c.id === convId)
      if (idx < 0) return list
      const updated = [...list]
      const c = updated[idx]
      updated[idx] = {
        ...c,
        lastMessagePreview: preview,
        lastMessageAt: msg.createdAt ?? new Date().toISOString(),
        unreadCount: msg.isMine ? c.unreadCount : c.unreadCount + 1,
      }
      return updated
    })
  }, [])

  const clearUnread = useCallback((convId: number) => {
    setConversations((list) =>
      list.map((c) => (c.id === convId ? { ...c, unreadCount: 0 } : c)),
    )
  }, [])

  const handleSocketMessage = useCallback(
    (payload: Record<string, unknown>) => {
      try {
        const msg = mapMessageFromPayload(payload)
        const convId = msg.conversationId
        const thread = threadsRef.current.get(convId)
        if (thread && !thread.messages.some((m) => m.id === msg.id)) {
          setThread(convId, { messages: [...thread.messages, msg] })
        }
        bumpConversationPreview(convId, msg)
        if (!msg.isMine) {
          setUnreadTotal((t) => t + 1)
        }
      } catch {
        /* ignore malformed */
      }
    },
    [bumpConversationPreview, setThread],
  )

  const handleSocketPresence = useCallback(
    (payload: Record<string, unknown>) => {
      const userId = payload.userId as number | undefined
      const online = (payload.isOnline as boolean) ?? false
      if (userId == null) return

      const updatePeer = (peer: ChatPeer): ChatPeer =>
        peer.userId === userId ? { ...peer, isOnline: online } : peer

      setConversations((list) =>
        list.map((c) => ({ ...c, peer: updatePeer(c.peer) })),
      )

      for (const [id, thread] of threadsRef.current.entries()) {
        if (thread.peer?.userId === userId) {
          setThread(id, { peer: thread.peer ? updatePeer(thread.peer) : null })
        }
      }
    },
    [setThread],
  )

  const refreshUnread = useCallback(async () => {
    try {
      const res = await chatApi.getUnreadTotal()
      setUnreadTotal(res.data.unreadTotal ?? 0)
    } catch {
      // Keep existing badge count if the unread endpoint fails.
    }
  }, [])

  const loadConversations = useCallback(
    async (archived = false) => {
      listArchivedRef.current = archived
      setIsLoadingList(true)
      setListError(null)
      try {
        const res = await chatApi.listConversations(archived)
        const list = (res.data.conversations ?? []).map(mapConversation)
        setConversations(list)
        const total =
          res.data.unreadTotal ?? list.reduce((s, c) => s + c.unreadCount, 0)
        setUnreadTotal(total)
      } catch (e) {
        setListError(e instanceof Error ? e.message : "Failed to load conversations")
      } finally {
        setIsLoadingList(false)
      }
    },
    [],
  )

  const handleSocketMessageRef = useRef(handleSocketMessage)
  const handleSocketPresenceRef = useRef(handleSocketPresence)
  handleSocketMessageRef.current = handleSocketMessage
  handleSocketPresenceRef.current = handleSocketPresence

  useEffect(() => {
    const token = getStoredToken()
    if (!isAuthenticated || !token) {
      chatSocket.disconnect()
      threadsRef.current.clear()
      setConversations([])
      setUnreadTotal(0)
      setListError(null)
      setThreadTick((n) => n + 1)
      return
    }

    chatSocket.connect(token, {
      onMessage: (payload) => handleSocketMessageRef.current(payload),
      onRead: () => {},
      onPresence: (payload) => handleSocketPresenceRef.current(payload),
    })

    let cancelled = false
    void (async () => {
      try {
        const res = await chatApi.getUnreadTotal()
        if (!cancelled) setUnreadTotal(res.data.unreadTotal ?? 0)
      } catch {
        /* ignore */
      }
      listArchivedRef.current = false
      if (!cancelled) {
        setIsLoadingList(true)
        setListError(null)
      }
      try {
        const res = await chatApi.listConversations(false)
        if (cancelled) return
        const list = (res.data.conversations ?? []).map(mapConversation)
        setConversations(list)
        setUnreadTotal(
          res.data.unreadTotal ?? list.reduce((s, c) => s + c.unreadCount, 0),
        )
      } catch (e) {
        if (!cancelled) {
          setListError(e instanceof Error ? e.message : "Failed to load conversations")
        }
      } finally {
        if (!cancelled) setIsLoadingList(false)
      }
    })()

    return () => {
      cancelled = true
      chatSocket.disconnect()
    }
  }, [isAuthenticated])

  const upsertConversation = useCallback((conv: ChatConversation) => {
    setConversations((list) => {
      const idx = list.findIndex((c) => c.id === conv.id)
      if (idx >= 0) {
        const next = [...list]
        next[idx] = conv
        return next
      }
      return [conv, ...list]
    })
  }, [])

  const openSupport = useCallback(async () => {
    const res = await chatApi.getSupportConversation()
    const conv = mapConversation(res.data.conversation)
    upsertConversation(conv)
    return conv
  }, [upsertConversation])

  const openBuyerSeller = useCallback(
    async (storeId: number, orderId?: number) => {
      const res = await chatApi.createConversation({
        kind: "buyer_seller",
        storeId,
        orderId,
      })
      const conv = mapConversation(res.data.conversation)
      upsertConversation(conv)
      return conv
    },
    [upsertConversation],
  )

  const openOrderChatAsSeller = useCallback(
    async (orderId: number) => {
      const res = await chatApi.openOrderChat(orderId)
      const conv = mapConversation(res.data.conversation)
      upsertConversation(conv)
      return conv
    },
    [upsertConversation],
  )

  const openRiderSeller = useCallback(
    async (storeId: number, orderId?: number) => {
      const res = await chatApi.createConversation({
        kind: "rider_seller",
        storeId,
        orderId,
      })
      const conv = mapConversation(res.data.conversation)
      upsertConversation(conv)
      return conv
    },
    [upsertConversation],
  )

  const loadThread = useCallback(
    async (conversationId: number) => {
      chatSocket.joinConversation(conversationId)
      setThread(conversationId, { isLoading: true, error: null })
      try {
        const res = await chatApi.fetchMessages(conversationId)
        const messages = (res.data.messages ?? []).map(mapMessage)
        const prevPending = threadsRef.current.get(conversationId)?.pendingOrderShare ?? null
        const conv = res.data.conversation
          ? mapConversation(res.data.conversation)
          : null
        const peer = res.data.peer ? mapPeer(res.data.peer) : conv?.peer ?? null
        setThread(conversationId, {
          messages,
          conversation: conv,
          peer,
          hasMore: res.data.nextCursor != null,
          nextCursor: res.data.nextCursor ?? null,
          isLoading: false,
          pendingOrderShare: prevPending,
        })
        await chatApi.markRead(conversationId)
        clearUnread(conversationId)
        await refreshUnread()
      } catch (e) {
        setThread(conversationId, {
          isLoading: false,
          error: e instanceof Error ? e.message : "Failed to load messages",
        })
      }
    },
    [clearUnread, refreshUnread, setThread],
  )

  const loadMoreMessages = useCallback(
    async (conversationId: number) => {
      const thread = threadsRef.current.get(conversationId)
      if (!thread?.hasMore || thread.nextCursor == null || thread.isLoading) return
      setThread(conversationId, { isLoading: true })
      try {
        const res = await chatApi.fetchMessages(conversationId, {
          cursor: thread.nextCursor,
        })
        const current = threadsRef.current.get(conversationId) ?? thread
        const older = (res.data.messages ?? []).map(mapMessage)
        setThread(conversationId, {
          messages: [...older, ...current.messages],
          hasMore: res.data.nextCursor != null,
          nextCursor: res.data.nextCursor ?? null,
          isLoading: false,
        })
      } catch {
        setThread(conversationId, { isLoading: false })
      }
    },
    [setThread],
  )

  const openConversation = useCallback(
    async (conversationId: number) => {
      await loadThread(conversationId)
    },
    [loadThread],
  )

  const appendMessage = useCallback(
    (conversationId: number, msg: ChatMessage) => {
      const thread = threadsRef.current.get(conversationId)
      if (thread?.messages.some((m) => m.id === msg.id)) return
      setThread(conversationId, {
        messages: [...(thread?.messages ?? []), msg],
      })
      bumpConversationPreview(conversationId, msg)
    },
    [bumpConversationPreview, setThread],
  )

  const sendText = useCallback(
    async (conversationId: number, text: string) => {
      if (!text.trim()) return
      const thread = threadsRef.current.get(conversationId) ?? emptyThread()
      setThread(conversationId, { isSending: true, error: null })
      try {
        const meta: Record<string, unknown> = {}
        if (thread.replyTo) meta.replyToMessageId = thread.replyTo.id
        const res = await chatApi.sendMessage(conversationId, {
          body: text.trim(),
          messageType: "text",
          metadata: Object.keys(meta).length ? meta : undefined,
        })
        const msg = mapMessage(res.data.message)
        appendMessage(conversationId, msg)
        setThread(conversationId, { isSending: false, replyTo: null })
      } catch (e) {
        setThread(conversationId, {
          isSending: false,
          error: e instanceof Error ? e.message : "Failed to send",
        })
      }
    },
    [appendMessage, setThread],
  )

  const sendRich = useCallback(
    async (
      conversationId: number,
      messageType: string,
      body = "",
      metadata?: Record<string, unknown>,
    ) => {
      const thread = threadsRef.current.get(conversationId) ?? emptyThread()
      setThread(conversationId, { isSending: true, error: null })
      try {
        const meta = { ...(metadata ?? {}) }
        if (thread.replyTo) meta.replyToMessageId = thread.replyTo.id
        const res = await chatApi.sendMessage(conversationId, {
          body,
          messageType,
          metadata: Object.keys(meta).length ? meta : undefined,
        })
        const msg = mapMessage(res.data.message)
        appendMessage(conversationId, msg)
        setThread(conversationId, { isSending: false, replyTo: null })
      } catch (e) {
        setThread(conversationId, {
          isSending: false,
          error: e instanceof Error ? e.message : "Failed to send",
        })
      }
    },
    [appendMessage, setThread],
  )

  const uploadAndSend = useCallback(
    async (conversationId: number, file: File) => {
      const res = await chatApi.uploadFile(file)
      const base = API_BASE_ORIGIN.replace(/\/static$/, "")
      const url = res.data.url.startsWith("http")
        ? res.data.url
        : `${base}${res.data.url}`
      await sendRich(conversationId, res.data.messageType, res.data.fileName, {
        fileUrl: url,
        fileName: res.data.fileName,
      })
    },
    [sendRich],
  )

  const setReplyTo = useCallback(
    (conversationId: number, msg: ChatMessage | null) => {
      setThread(conversationId, { replyTo: msg })
    },
    [setThread],
  )

  const setPendingOrderShare = useCallback(
    (conversationId: number, share: PendingOrderShare | null) => {
      setThread(conversationId, { pendingOrderShare: share })
    },
    [setThread],
  )

  const sendPendingOrderShare = useCallback(
    async (conversationId: number) => {
      const pending = threadsRef.current.get(conversationId)?.pendingOrderShare
      if (!pending) return
      await sendRich(conversationId, "order", "", { orderId: pending.orderId })
      setThread(conversationId, { pendingOrderShare: null })
    },
    [sendRich, setThread],
  )

  const sendComposer = useCallback(
    async (conversationId: number, text: string) => {
      const thread = threadsRef.current.get(conversationId) ?? emptyThread()
      const trimmed = text.trim()
      const pending = thread.pendingOrderShare
      if (!trimmed && !pending) return

      setThread(conversationId, { isSending: true, error: null })
      try {
        if (trimmed) {
          const meta: Record<string, unknown> = {}
          if (thread.replyTo) meta.replyToMessageId = thread.replyTo.id
          const res = await chatApi.sendMessage(conversationId, {
            body: trimmed,
            messageType: "text",
            metadata: Object.keys(meta).length ? meta : undefined,
          })
          appendMessage(conversationId, mapMessage(res.data.message))
        }
        if (pending) {
          const res = await chatApi.sendMessage(conversationId, {
            body: "",
            messageType: "order",
            metadata: { orderId: pending.orderId },
          })
          appendMessage(conversationId, mapMessage(res.data.message))
        }
        setThread(conversationId, {
          isSending: false,
          replyTo: null,
          pendingOrderShare: null,
        })
      } catch (e) {
        setThread(conversationId, {
          isSending: false,
          error: e instanceof Error ? e.message : "Failed to send",
        })
      }
    },
    [appendMessage, setThread],
  )

  const togglePin = useCallback(async (conv: ChatConversation) => {
    const res = await chatApi.togglePin(conv.id, !conv.isPinned)
    setConversations((list) =>
      list.map((c) =>
        c.id === conv.id ? { ...c, isPinned: res.data.isPinned ?? !conv.isPinned } : c,
      ),
    )
  }, [])

  const archiveConversation = useCallback(
    async (conversationId: number, archive: boolean) => {
      const res = await chatApi.setArchived(conversationId, archive)
      setConversations((list) => list.filter((c) => c.id !== conversationId))
      threadsRef.current.delete(conversationId)
      tickThreads()
      await refreshUnread()
      return res.data.isArchived ?? archive
    },
    [refreshUnread, tickThreads],
  )

  const deleteConversation = useCallback(
    async (conversationId: number) => {
      await chatApi.deleteConversation(conversationId)
      setConversations((list) => list.filter((c) => c.id !== conversationId))
      threadsRef.current.delete(conversationId)
      tickThreads()
      await refreshUnread()
    },
    [refreshUnread, tickThreads],
  )

  const markConversationRead = useCallback(
    async (conversationId: number) => {
      await chatApi.markRead(conversationId)
      clearUnread(conversationId)
      await refreshUnread()
    },
    [clearUnread, refreshUnread],
  )

  const contextValue = useMemo(
    () => ({
      conversations,
      unreadTotal,
      isLoadingList,
      listError,
      threadTick,
      loadConversations,
      refreshUnread,
      openSupport,
      openBuyerSeller,
      openOrderChatAsSeller,
      openRiderSeller,
      getThread,
      loadThread,
      loadMoreMessages,
      openConversation,
      setPendingOpenConversationId,
      pendingOpenConversationId,
      sendText,
      sendComposer,
      sendRich,
      uploadAndSend,
      setReplyTo,
      setPendingOrderShare,
      sendPendingOrderShare,
      togglePin,
      archiveConversation,
      deleteConversation,
      markConversationRead,
    }),
    [
      conversations,
      unreadTotal,
      isLoadingList,
      listError,
      threadTick,
      loadConversations,
      refreshUnread,
      openSupport,
      openBuyerSeller,
      openOrderChatAsSeller,
      openRiderSeller,
      getThread,
      loadThread,
      loadMoreMessages,
      openConversation,
      pendingOpenConversationId,
      sendText,
      sendComposer,
      sendRich,
      uploadAndSend,
      setReplyTo,
      setPendingOrderShare,
      sendPendingOrderShare,
      togglePin,
      archiveConversation,
      deleteConversation,
      markConversationRead,
    ],
  )

  return <ChatContext.Provider value={contextValue}>{children}</ChatContext.Provider>
}

export function useChat() {
  const ctx = useContext(ChatContext)
  if (!ctx) throw new Error("useChat must be used within ChatProvider")
  return ctx
}
