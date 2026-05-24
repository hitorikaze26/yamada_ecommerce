import type { ChatConversationDto, ChatMessageDto, ChatPeerDto } from "@/lib/api"
import type { ChatConversation, ChatMessage, ChatPeer } from "@/lib/chat/types"

export function mapPeer(dto?: ChatPeerDto | null): ChatPeer {
  return {
    userId: dto?.userId ?? 0,
    name: dto?.name ?? "User",
    role: dto?.role ?? "user",
    isVerified: dto?.isVerified ?? false,
    avatarUrl: dto?.avatarUrl ?? null,
    isOnline: dto?.isOnline ?? false,
  }
}

export function mapConversation(dto: ChatConversationDto): ChatConversation {
  return {
    id: dto.id,
    kind: dto.kind ?? "",
    storeId: dto.storeId ?? null,
    orderId: dto.orderId ?? null,
    title: dto.title ?? dto.peer?.name ?? "Conversation",
    lastMessagePreview: dto.lastMessagePreview ?? "",
    lastMessageAt: dto.lastMessageAt ?? null,
    unreadCount: dto.unreadCount ?? 0,
    isPinned: dto.isPinned ?? false,
    isArchived: dto.isArchived ?? false,
    peer: mapPeer(dto.peer),
  }
}

export function mapMessage(dto: ChatMessageDto): ChatMessage {
  return {
    id: dto.id,
    conversationId: dto.conversationId,
    senderUserId: dto.senderUserId ?? null,
    senderRole: dto.senderRole ?? "user",
    body: dto.body ?? "",
    messageType: dto.messageType ?? "text",
    metadata: dto.metadata ?? {},
    createdAt: dto.createdAt ?? null,
    isMine: dto.isMine ?? false,
  }
}

export function mapMessageFromPayload(payload: Record<string, unknown>): ChatMessage {
  return mapMessage({
    id: Number(payload.id),
    conversationId: Number(payload.conversationId),
    senderUserId: (payload.senderUserId as number | null) ?? null,
    senderRole: String(payload.senderRole ?? "user"),
    body: String(payload.body ?? ""),
    messageType: String(payload.messageType ?? "text"),
    metadata: (payload.metadata as Record<string, unknown>) ?? {},
    createdAt: (payload.createdAt as string | null) ?? null,
    isMine: Boolean(payload.isMine),
  })
}

export function chatPreviewFromMessage(msg: ChatMessage): string {
  switch (msg.messageType) {
    case "image":
      return "Photo"
    case "file":
      return "Attachment"
    case "product": {
      const name = String(msg.metadata.name ?? "").trim()
      return name ? `Product · ${name}` : "Shared a product"
    }
    case "order": {
      const name = String(msg.metadata.productName ?? "").trim()
      return name ? `Order · ${name}` : "Shared an order"
    }
    default: {
      const body = msg.body.trim()
      return body || "Message"
    }
  }
}

export function formatMessageTime(iso: string | null): string {
  if (!iso) return ""
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ""
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  if (diffMins < 1) return "Just now"
  if (diffMins < 60) return `${diffMins}m ago`
  const diffHours = Math.floor(diffMins / 60)
  if (diffHours < 24) return `${diffHours}h ago`
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" })
}

export function formatListTime(iso: string | null): string {
  if (!iso) return ""
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ""
  const now = new Date()
  const isToday = date.toDateString() === now.toDateString()
  if (isToday) {
    return date.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
  }
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  if (date.toDateString() === yesterday.toDateString()) return "Yesterday"
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" })
}

export function displayNameForConversation(conv: ChatConversation): string {
  if (conv.peer.name) return conv.peer.name
  return conv.title || "Conversation"
}
