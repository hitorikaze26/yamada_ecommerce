import type { UserRole } from "@/lib/types"

export type ChatListFilter =
  | "all"
  | "unread"
  | "buyer"
  | "seller"
  | "support"
  | "rider"
  | "archived"

export interface ChatPeer {
  userId: number
  name: string
  role: string
  isVerified: boolean
  avatarUrl: string | null
  isOnline: boolean
}

export interface ChatConversation {
  id: number
  kind: string
  storeId: number | null
  orderId: number | null
  title: string
  lastMessagePreview: string
  lastMessageAt: string | null
  unreadCount: number
  isPinned: boolean
  isArchived: boolean
  peer: ChatPeer
}

export interface ChatMessage {
  id: number
  conversationId: number
  senderUserId: number | null
  senderRole: string
  body: string
  messageType: string
  metadata: Record<string, unknown>
  createdAt: string | null
  isMine: boolean
}

export interface PendingOrderShare {
  orderId: number
  productName: string
  productImageUrl?: string | null
  status: string
  totalAmount: number
  displayId: string
}

export interface ThreadState {
  messages: ChatMessage[]
  conversation: ChatConversation | null
  peer: ChatPeer | null
  isLoading: boolean
  isSending: boolean
  hasMore: boolean
  nextCursor: number | null
  error: string | null
  replyTo: ChatMessage | null
  pendingOrderShare: PendingOrderShare | null
}

export interface ShareProductItem {
  id: number
  name: string
  price: number
  imageUrl: string | null
}

export interface ShareOrderItem {
  orderId: number
  orderNumber: string
  status: string
  productName: string
  productImageUrl: string | null
  totalAmount: number
}

export function filtersForRole(role: UserRole | null): ChatListFilter[] {
  switch (role) {
    case "seller":
      return ["all", "unread", "buyer", "rider", "support", "archived"]
    case "rider":
      return ["all", "unread", "seller", "archived"]
    case "buyer":
      return ["all", "unread", "seller", "support", "archived"]
    case "admin":
      return ["all", "unread", "buyer", "seller", "archived"]
    default:
      return ["all", "unread", "archived"]
  }
}

export function filterLabel(filter: ChatListFilter): string {
  switch (filter) {
    case "all":
      return "All"
    case "unread":
      return "Unread"
    case "buyer":
      return "Buyers"
    case "seller":
      return "Sellers"
    case "support":
      return "Support"
    case "rider":
      return "Riders"
    case "archived":
      return "Archived"
    default:
      return filter
  }
}

export function matchesFilter(conv: ChatConversation, filter: ChatListFilter): boolean {
  if (filter === "archived") return true
  switch (filter) {
    case "unread":
      return conv.unreadCount > 0
    case "buyer":
      return conv.peer.role === "buyer"
    case "seller":
      return conv.peer.role === "seller"
    case "support":
      return conv.kind.includes("admin") || conv.peer.role === "admin"
    case "rider":
      return conv.peer.role === "rider"
    default:
      return true
  }
}

export function canShareProducts(role: UserRole | null): boolean {
  return role === "buyer" || role === "seller"
}

export function canShareOrders(role: UserRole | null): boolean {
  return role === "buyer" || role === "seller" || role === "rider"
}

export function canOpenSupport(role: UserRole | null): boolean {
  return role === "buyer" || role === "seller"
}
