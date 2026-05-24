"use client"

import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { ChatMessageBubble } from "@/components/chat/chat-message-bubble"
import {
  buildThreadListItems,
  ChatAvatar,
  ChatEmptyState,
  ChatRoleBadge,
  ChatThreadSkeleton,
  DateSeparator,
} from "@/components/chat/chat-ui"
import { resolveImageUrl } from "@/lib/api"
import { displayNameForConversation, chatPreviewFromMessage } from "@/lib/chat/mappers"
import type { ChatConversation, ChatMessage, PendingOrderShare } from "@/lib/chat/types"
import type { ThreadState } from "@/lib/chat/types"
import type { ShareOrderItem, ShareProductItem } from "@/lib/chat/types"
import { chatApi } from "@/lib/api"
import type { UserRole } from "@/lib/types"
import { canShareOrders, canShareProducts } from "@/lib/chat/types"

interface ChatConversationModalProps {
  open: boolean
  conversationId: number | null
  conversation: ChatConversation | null
  thread: ThreadState
  role: UserRole | null
  onClose: () => void
  onSendText: (text: string) => void
  onSendFile: (file: File) => void
  onSendProduct: (productId: number) => void
  onSendOrder: (orderId: number) => void
  onClearPendingOrder: () => void
  onDeleteConversation: () => void
  onLoadMore: () => void
  onSetReply: (msg: ChatMessage | null) => void
}

export function ChatConversationModal({
  open,
  conversationId,
  conversation,
  thread,
  role,
  onClose,
  onSendText,
  onSendFile,
  onSendProduct,
  onSendOrder,
  onClearPendingOrder,
  onDeleteConversation,
  onLoadMore,
  onSetReply,
}: ChatConversationModalProps) {
  const [input, setInput] = useState("")
  const [file, setFile] = useState<File | null>(null)
  const [shareOpen, setShareOpen] = useState<"product" | "order" | null>(null)
  const [shareProducts, setShareProducts] = useState<ShareProductItem[]>([])
  const [shareOrders, setShareOrders] = useState<ShareOrderItem[]>([])
  const scrollRef = useRef<HTMLDivElement>(null)
  const topSentinelRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const peerName = conversation
    ? displayNameForConversation(conversation)
    : thread.peer?.name ?? "Chat"
  const peerRole = conversation?.peer.role ?? thread.peer?.role ?? "user"
  const peerAvatar = conversation?.peer.avatarUrl ?? thread.peer?.avatarUrl
  const isOnline = thread.peer?.isOnline ?? conversation?.peer.isOnline ?? false

  const threadItems = useMemo(
    () => buildThreadListItems(thread.messages),
    [thread.messages],
  )

  const onSetReplyRef = useRef(onSetReply)
  const onLoadMoreRef = useRef(onLoadMore)
  onSetReplyRef.current = onSetReply
  onLoadMoreRef.current = onLoadMore

  useEffect(() => {
    if (!open) {
      setInput("")
      setFile(null)
      setShareOpen(null)
      onSetReplyRef.current(null)
    }
  }, [open])

  useEffect(() => {
    if (!open || !scrollRef.current) return
    const el = scrollRef.current
    requestAnimationFrame(() => {
      el.scrollTop = el.scrollHeight
    })
  }, [open, thread.messages.length, thread.isSending])

  useEffect(() => {
    const el = topSentinelRef.current
    const root = scrollRef.current
    if (!el || !root || !open) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && thread.hasMore && !thread.isLoading) {
          onLoadMoreRef.current()
        }
      },
      { root, threshold: 0.1 },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [open, thread.hasMore, thread.isLoading])

  const loadSharePickers = useCallback(async () => {
    if (shareOpen === "product" && canShareProducts(role)) {
      try {
        const res = await chatApi.shareProducts(conversation?.storeId ?? undefined)
        setShareProducts(
          (res.data.products ?? []).map((p) => ({
            id: p.id,
            name: p.name,
            price: p.price,
            imageUrl: p.imageUrl ?? null,
          })),
        )
      } catch {
        setShareProducts([])
      }
    }
    if (shareOpen === "order" && canShareOrders(role)) {
      try {
        const res = await chatApi.shareOrders()
        setShareOrders(
          (res.data.orders ?? []).map((o) => ({
            orderId: o.orderId,
            orderNumber: o.orderNumber,
            status: o.status,
            productName: o.productName,
            productImageUrl: o.productImageUrl ?? null,
            totalAmount: o.totalAmount,
          })),
        )
      } catch {
        setShareOrders([])
      }
    }
  }, [shareOpen, role, conversation?.storeId])

  useEffect(() => {
    if (shareOpen) void loadSharePickers()
  }, [shareOpen, loadSharePickers])

  const adjustTextareaHeight = useCallback(() => {
    const ta = textareaRef.current
    if (!ta) return
    ta.style.height = "0px"
    const next = Math.min(ta.scrollHeight, 120)
    ta.style.height = `${Math.max(next, 40)}px`
    ta.style.overflowY = next >= 120 ? "auto" : "hidden"
  }, [])

  useEffect(() => {
    if (open) adjustTextareaHeight()
  }, [open, input, adjustTextareaHeight])

  const handleSubmit = (e?: React.FormEvent) => {
    e?.preventDefault()
    if (thread.isSending || !conversationId) return
    if (file) {
      onSendFile(file)
      setFile(null)
      setInput("")
      requestAnimationFrame(() => adjustTextareaHeight())
      return
    }
    const hasText = Boolean(input.trim())
    const hasPending = Boolean(thread.pendingOrderShare)
    if (!hasText && !hasPending) return
    onSendText(input.trim())
    setInput("")
    requestAnimationFrame(() => adjustTextareaHeight())
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent
        showCloseButton={false}
        className="w-[96vw] max-w-lg h-[min(90vh,720px)] flex flex-col p-0 gap-0 overflow-hidden sm:rounded-2xl"
      >
        <DialogTitle className="sr-only">Chat with {peerName}</DialogTitle>

        {/* Header */}
        <header className="shrink-0 flex items-center gap-3 px-4 py-3 border-b bg-card/95 backdrop-blur-sm">
          <Button
            variant="ghost"
            size="icon"
            className="shrink-0 -ml-1"
            onClick={onClose}
            aria-label="Back to inbox"
          >
            <Icon name="arrow-left" />
          </Button>

          <ChatAvatar name={peerName} imageUrl={peerAvatar} online={isOnline} size="md" />

          <div className="flex-1 min-w-0">
            <p className="text-sm font-semibold truncate leading-tight">{peerName}</p>
            <div className="flex items-center gap-2 mt-0.5">
              <ChatRoleBadge role={peerRole} />
              <span
                className={`text-[11px] ${isOnline ? "text-emerald-600 dark:text-emerald-400" : "text-muted-foreground"}`}
              >
                {isOnline ? "Online" : "Offline"}
              </span>
            </div>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="shrink-0">
                <Icon name="menu-dots" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={onDeleteConversation}
              >
                <Icon name="trash" className="mr-2" />
                Delete conversation
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        {thread.replyTo && (
          <div className="shrink-0 px-4 py-2.5 bg-muted/60 border-b flex items-start gap-2">
            <div className="w-1 rounded-full bg-primary shrink-0 self-stretch min-h-[2rem]" />
            <div className="flex-1 min-w-0">
              <p className="text-[10px] font-medium text-muted-foreground uppercase tracking-wide">
                Replying to
              </p>
              <p className="text-xs truncate mt-0.5">
                {chatPreviewFromMessage(thread.replyTo)}
              </p>
            </div>
            <Button
              variant="ghost"
              size="icon"
              className="h-7 w-7 shrink-0"
              onClick={() => onSetReply(null)}
            >
              <Icon name="cross" size="sm" />
            </Button>
          </div>
        )}

        {/* Messages */}
        <div
          ref={scrollRef}
          className="flex-1 min-h-0 overflow-y-auto bg-gradient-to-b from-muted/30 via-muted/20 to-muted/40"
        >
          <div className="px-4 py-4 space-y-3 min-h-full flex flex-col">
            <div ref={topSentinelRef} className="h-px shrink-0" />
            {thread.hasMore && !thread.isLoading && (
              <button
                type="button"
                onClick={onLoadMore}
                className="mx-auto text-xs text-primary hover:underline py-1"
              >
                Load earlier messages
              </button>
            )}

            {thread.isLoading && thread.messages.length === 0 && <ChatThreadSkeleton />}

            {thread.error && (
              <div className="rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs text-destructive text-center">
                {thread.error}
              </div>
            )}

            {!thread.isLoading && thread.messages.length === 0 && (
              <div className="flex-1 flex items-center justify-center">
                <ChatEmptyState
                  icon="comment-alt"
                  title="Start the conversation"
                  description={`Send a message to ${peerName}. Long-press or right-click a message to reply.`}
                />
              </div>
            )}

            {threadItems.map((item) => {
              if (item.kind === "date") {
                return <DateSeparator key={item.key} label={item.label} />
              }
              const replyTarget =
                item.message.metadata.replyToMessageId != null
                  ? thread.messages.find(
                      (m) => m.id === Number(item.message.metadata.replyToMessageId),
                    )
                  : null
              return (
                <div
                  key={item.key}
                  onContextMenu={(e) => {
                    e.preventDefault()
                    onSetReply(item.message)
                  }}
                >
                  <ChatMessageBubble
                    message={item.message}
                    replyTo={replyTarget ?? null}
                    showTime={item.showTime}
                  />
                </div>
              )
            })}

            {thread.isSending && (
              <div className="flex justify-end">
                <div className="rounded-2xl rounded-br-md bg-primary/20 px-4 py-2.5 flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-primary animate-bounce [animation-delay:0ms]" />
                  <span className="w-1.5 h-1.5 rounded-full bg-primary animate-bounce [animation-delay:150ms]" />
                  <span className="w-1.5 h-1.5 rounded-full bg-primary animate-bounce [animation-delay:300ms]" />
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Composer + share picker (stacked at bottom, no overlap) */}
        <footer className="shrink-0 border-t bg-card flex flex-col min-h-0">
          {shareOpen && (
            <SharePicker
              type={shareOpen}
              products={shareProducts}
              orders={shareOrders}
              onSelectProduct={(id) => {
                onSendProduct(id)
                setShareOpen(null)
              }}
              onSelectOrder={(id) => {
                onSendOrder(id)
                setShareOpen(null)
              }}
              onClose={() => setShareOpen(null)}
            />
          )}

          <div className="p-3 space-y-2">
            {thread.pendingOrderShare && (
              <PendingOrderBanner
                share={thread.pendingOrderShare}
                onDismiss={onClearPendingOrder}
              />
            )}

            {file && (
              <div className="flex items-center gap-2 rounded-lg border bg-muted/50 px-3 py-2 text-xs">
                <Icon name="paperclip" className="text-primary shrink-0" />
                <span className="truncate flex-1 font-medium">{file.name}</span>
                <Button type="button" variant="ghost" size="icon" className="h-6 w-6" onClick={() => setFile(null)}>
                  <Icon name="cross" size="sm" />
                </Button>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-1.5">
              <div className="flex items-end gap-2">
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button
                      type="button"
                      variant="outline"
                      size="icon"
                      className="shrink-0 rounded-full h-10 w-10 border-dashed"
                      disabled={!conversationId}
                    >
                      <Icon name="plus" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="start" className="w-48">
                    <DropdownMenuItem asChild>
                      <label className="flex items-center cursor-pointer w-full py-2">
                        <Icon name="paperclip" className="mr-2 text-muted-foreground" />
                        Attach file
                        <input
                          type="file"
                          className="hidden"
                          accept="image/*,.pdf,.doc,.docx"
                          onChange={(e) => {
                            setFile(e.target.files?.[0] ?? null)
                            e.target.value = ""
                          }}
                        />
                      </label>
                    </DropdownMenuItem>
                    {canShareProducts(role) && (
                      <DropdownMenuItem onClick={() => setShareOpen("product")}>
                        <Icon name="box" className="mr-2 text-muted-foreground" />
                        Share product
                      </DropdownMenuItem>
                    )}
                    {canShareOrders(role) && (
                      <DropdownMenuItem onClick={() => setShareOpen("order")}>
                        <Icon name="shopping-bag" className="mr-2 text-muted-foreground" />
                        Share order
                      </DropdownMenuItem>
                    )}
                  </DropdownMenuContent>
                </DropdownMenu>

                <textarea
                  ref={textareaRef}
                  rows={1}
                  value={input}
                  onChange={(e) => {
                    setInput(e.target.value)
                    adjustTextareaHeight()
                  }}
                  onKeyDown={handleKeyDown}
                  placeholder="Type a message…"
                  disabled={thread.isSending || !conversationId}
                  className="flex-1 min-w-0 resize-none overflow-hidden rounded-2xl border border-border/80 bg-muted/30 px-4 py-2.5 text-sm leading-5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30 focus-visible:border-primary/40 disabled:opacity-50"
                  style={{ height: 40, maxHeight: 120 }}
                />

                <Button
                  type="submit"
                  size="icon"
                  className="rounded-full h-10 w-10 shrink-0 shadow-sm"
                  disabled={
                    (!input.trim() && !file && !thread.pendingOrderShare) ||
                    thread.isSending ||
                    !conversationId
                  }
                  aria-label="Send message"
                >
                  <Icon name="paper-plane" />
                </Button>
              </div>
              {!shareOpen && (
                <p className="text-[10px] text-muted-foreground px-1 hidden sm:block">
                  Enter to send · Shift+Enter for new line
                </p>
              )}
            </form>
          </div>
        </footer>
      </DialogContent>
    </Dialog>
  )
}

function PendingOrderBanner({
  share,
  onDismiss,
}: {
  share: PendingOrderShare
  onDismiss: () => void
}) {
  const img = resolveImageUrl(share.productImageUrl ?? null)
  return (
    <div className="rounded-xl border border-primary/25 bg-primary/5 flex gap-3 items-center p-2.5">
      {img ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={img} alt="" className="w-11 h-11 rounded-lg object-cover shrink-0" />
      ) : (
        <div className="w-11 h-11 rounded-lg bg-primary/10 flex items-center justify-center shrink-0">
          <Icon name="shopping-bag" className="text-primary" size="sm" />
        </div>
      )}
      <div className="flex-1 min-w-0">
        <p className="text-[10px] font-medium text-primary uppercase tracking-wide">Order to share</p>
        <p className="text-sm font-medium truncate">{share.productName}</p>
        <p className="text-xs text-muted-foreground truncate">
          {share.displayId}
          {share.totalAmount > 0 ? ` · ₱${share.totalAmount.toLocaleString()}` : ""}
        </p>
      </div>
      <Button
        variant="ghost"
        size="icon"
        className="h-8 w-8 shrink-0"
        onClick={onDismiss}
        aria-label="Remove order from message"
      >
        <Icon name="cross" size="sm" />
      </Button>
    </div>
  )
}

function SharePicker({
  type,
  products,
  orders,
  onSelectProduct,
  onSelectOrder,
  onClose,
}: {
  type: "product" | "order"
  products: ShareProductItem[]
  orders: ShareOrderItem[]
  onSelectProduct: (id: number) => void
  onSelectOrder: (id: number) => void
  onClose: () => void
}) {
  const items = type === "product" ? products : orders
  const empty = items.length === 0

  return (
    <div className="flex flex-col border-b bg-muted/20 min-h-0 max-h-[min(36vh,260px)]">
      <div className="shrink-0 flex items-center justify-between gap-2 px-4 py-2.5 border-b bg-card">
        <p className="text-sm font-medium truncate">
          {type === "product" ? "Share a product" : "Share an order"}
        </p>
        <Button variant="ghost" size="sm" className="shrink-0 h-8" onClick={onClose}>
          Cancel
        </Button>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain">
        <div className="p-2 space-y-0.5">
          {empty && (
            <p className="text-xs text-muted-foreground text-center py-8">
              Nothing to share right now.
            </p>
          )}
          {type === "product" &&
            products.map((p) => (
              <button
                key={p.id}
                type="button"
                className="w-full flex items-center gap-3 rounded-lg p-2.5 hover:bg-muted/80 active:bg-muted text-left transition-colors"
                onClick={() => onSelectProduct(p.id)}
              >
                {p.imageUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={resolveImageUrl(p.imageUrl) ?? ""}
                    alt=""
                    className="w-11 h-11 rounded-md object-cover shrink-0 bg-muted"
                  />
                ) : (
                  <div className="w-11 h-11 rounded-md bg-muted flex items-center justify-center shrink-0">
                    <Icon name="box" className="text-muted-foreground" size="sm" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium truncate">{p.name}</p>
                  <p className="text-xs text-primary">₱{p.price.toLocaleString()}</p>
                </div>
              </button>
            ))}
          {type === "order" &&
            orders.map((o) => (
              <button
                key={o.orderId}
                type="button"
                className="w-full flex items-center gap-3 rounded-lg p-2.5 hover:bg-muted/80 active:bg-muted text-left transition-colors"
                onClick={() => onSelectOrder(o.orderId)}
              >
                {o.productImageUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={resolveImageUrl(o.productImageUrl) ?? ""}
                    alt=""
                    className="w-11 h-11 rounded-md object-cover shrink-0 bg-muted"
                  />
                ) : (
                  <div className="w-11 h-11 rounded-md bg-muted flex items-center justify-center shrink-0">
                    <Icon name="shopping-bag" className="text-muted-foreground" size="sm" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium truncate">{o.productName}</p>
                  <p className="text-xs text-muted-foreground truncate">
                    {o.orderNumber} · ₱{o.totalAmount.toLocaleString()}
                  </p>
                </div>
              </button>
            ))}
        </div>
      </div>
    </div>
  )
}
