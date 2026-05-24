"use client"

import { useEffect, useMemo, useRef, useState } from "react"
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { Input } from "@/components/ui/input"
import { ScrollArea } from "@/components/ui/scroll-area"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  ChatAvatar,
  ChatEmptyState,
  ChatListSkeleton,
  ChatRoleBadge,
} from "@/components/chat/chat-ui"
import { displayNameForConversation, formatListTime } from "@/lib/chat/mappers"
import type { ChatConversation, ChatListFilter } from "@/lib/chat/types"
import { filterLabel, matchesFilter } from "@/lib/chat/types"

interface ChatListSheetProps {
  open: boolean
  conversations: ChatConversation[]
  filters: ChatListFilter[]
  isLoading?: boolean
  showSupportAction?: boolean
  onClose: () => void
  onOpenConversation: (conversation: ChatConversation) => void
  onMarkAsRead: (id: number) => void
  onDelete: (id: number) => void
  onToggleArchive: (id: number, archived: boolean) => void
  onTogglePin: (conversation: ChatConversation) => void
  onOpenSupport?: () => void
  onFilterChange?: (filter: ChatListFilter) => void
  onReload?: (archived: boolean) => void
}

export function ChatListSheet({
  open,
  conversations,
  filters,
  isLoading,
  showSupportAction,
  onClose,
  onOpenConversation,
  onMarkAsRead,
  onDelete,
  onToggleArchive,
  onTogglePin,
  onOpenSupport,
  onFilterChange,
  onReload,
}: ChatListSheetProps) {
  const [filter, setFilter] = useState<ChatListFilter>("all")
  const [query, setQuery] = useState("")
  const onReloadRef = useRef(onReload)
  onReloadRef.current = onReload

  useEffect(() => {
    if (!open) setQuery("")
  }, [open])

  useEffect(() => {
    if (filter === "archived") {
      onReloadRef.current?.(true)
    } else if (open) {
      onReloadRef.current?.(false)
    }
  }, [filter, open])

  const handleFilter = (f: ChatListFilter) => {
    setFilter(f)
    onFilterChange?.(f)
  }

  const { filtered, unreadTotal } = useMemo(() => {
    const isArchivedView = filter === "archived"
    let list = conversations.filter((c) =>
      isArchivedView ? c.isArchived : !c.isArchived,
    )

    if (filter !== "all" && filter !== "archived") {
      list = list.filter((c) => matchesFilter(c, filter))
    }

    const q = query.trim().toLowerCase()
    if (q) {
      list = list.filter((c) => {
        const name = displayNameForConversation(c).toLowerCase()
        const preview = (c.lastMessagePreview ?? "").toLowerCase()
        return name.includes(q) || preview.includes(q)
      })
    }

    list = [...list].sort((a, b) => {
      if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1
      const ta = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0
      const tb = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0
      return tb - ta
    })

    const unread = conversations.reduce((sum, c) => sum + c.unreadCount, 0)
    return { filtered: list, unreadTotal: unread }
  }, [conversations, filter, query])

  return (
    <Sheet open={open} onOpenChange={(v) => !v && onClose()}>
      <SheetContent
        side="right"
        className="w-full sm:max-w-md flex flex-col p-0 gap-0 border-l shadow-xl"
      >
        <SheetTitle className="sr-only">Messages</SheetTitle>

        {/* Header */}
        <header className="shrink-0 px-5 pt-5 pb-4 border-b bg-gradient-to-b from-primary/5 to-transparent">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h2 className="text-xl font-semibold tracking-tight">Messages</h2>
              <p className="text-xs text-muted-foreground mt-0.5">
                {unreadTotal > 0
                  ? `${unreadTotal} unread message${unreadTotal === 1 ? "" : "s"}`
                  : "All caught up"}
              </p>
            </div>
            <Button variant="ghost" size="icon" className="shrink-0 -mr-2" onClick={onClose}>
              <Icon name="cross" />
              <span className="sr-only">Close</span>
            </Button>
          </div>

          {showSupportAction && onOpenSupport && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3 w-full justify-center gap-2 border-primary/20 hover:bg-primary/5"
              onClick={onOpenSupport}
            >
              <Icon name="headset" size="sm" />
              Chat with Yamada Support
            </Button>
          )}

          <div className="relative mt-3">
            <Icon
              name="search"
              size="sm"
              className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none"
            />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search conversations..."
              className="pl-9 h-10 bg-background/80"
            />
          </div>
        </header>

        {/* Filters */}
        <div className="shrink-0 px-3 py-2.5 border-b bg-muted/30">
          <div className="flex gap-1.5 overflow-x-auto scrollbar-hide pb-0.5">
            {filters.map((f) => (
              <button
                key={f}
                type="button"
                onClick={() => handleFilter(f)}
                className={`shrink-0 rounded-full px-3.5 py-1.5 text-xs font-medium transition-colors ${
                  filter === f
                    ? "bg-primary text-primary-foreground shadow-sm"
                    : "bg-background text-muted-foreground hover:text-foreground border border-border/60"
                }`}
              >
                {filterLabel(f)}
              </button>
            ))}
          </div>
        </div>

        {/* List */}
        <ScrollArea className="flex-1 min-h-0">
          {isLoading && <ChatListSkeleton />}

          {!isLoading && filtered.length === 0 && (
            <ChatEmptyState
              icon={filter === "archived" ? "archive" : "envelope"}
              title={query ? "No matches" : filter === "archived" ? "No archived chats" : "No conversations yet"}
              description={
                query
                  ? "Try a different search term."
                  : filter === "archived"
                    ? "Archived threads will appear here."
                    : "Start a chat from a store page or order."
              }
            />
          )}

          {!isLoading && filtered.length > 0 && (
            <div className="p-2 space-y-1">
              {filtered.map((conv) => {
                const name = displayNameForConversation(conv)
                const hasUnread = conv.unreadCount > 0
                return (
                  <div
                    key={conv.id}
                    className={`group relative flex items-stretch rounded-xl transition-colors ${
                      hasUnread
                        ? "bg-primary/5 hover:bg-primary/10 border border-primary/10"
                        : "hover:bg-muted/80 border border-transparent"
                    }`}
                  >
                    <button
                      type="button"
                      className="flex flex-1 items-center gap-3 p-3 text-left min-w-0"
                      onClick={() => onOpenConversation(conv)}
                    >
                      <ChatAvatar
                        name={name}
                        imageUrl={conv.peer.avatarUrl}
                        online={conv.peer.isOnline}
                      />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <p
                            className={`text-sm truncate ${hasUnread ? "font-semibold" : "font-medium"}`}
                          >
                            {conv.isPinned && (
                              <Icon
                                name="thumbtack"
                                size="sm"
                                className="inline mr-1 text-primary/70"
                              />
                            )}
                            {name}
                          </p>
                          <span className="text-[10px] text-muted-foreground whitespace-nowrap ml-auto shrink-0">
                            {formatListTime(conv.lastMessageAt)}
                          </span>
                        </div>
                        <p
                          className={`text-xs truncate mt-0.5 ${
                            hasUnread ? "text-foreground/80 font-medium" : "text-muted-foreground"
                          }`}
                        >
                          {conv.lastMessagePreview || "No messages yet"}
                        </p>
                        <div className="mt-1.5 flex items-center gap-2 flex-wrap">
                          <ChatRoleBadge role={conv.peer.role} />
                          {hasUnread && (
                            <span className="inline-flex items-center justify-center min-w-[1.25rem] h-5 rounded-full bg-primary text-primary-foreground text-[10px] font-semibold px-1.5">
                              {conv.unreadCount > 99 ? "99+" : conv.unreadCount}
                            </span>
                          )}
                        </div>
                      </div>
                    </button>

                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="shrink-0 self-center mr-1 h-8 w-8 opacity-0 group-hover:opacity-100 focus:opacity-100"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Icon name="menu-dots" size="sm" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end" className="w-44">
                        <DropdownMenuItem
                          onClick={(e) => {
                            e.stopPropagation()
                            onMarkAsRead(conv.id)
                          }}
                        >
                          <Icon name="check" className="mr-2" />
                          Mark as read
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={(e) => {
                            e.stopPropagation()
                            onTogglePin(conv)
                          }}
                        >
                          <Icon name="thumbtack" className="mr-2" />
                          {conv.isPinned ? "Unpin" : "Pin"}
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={(e) => {
                            e.stopPropagation()
                            onToggleArchive(conv.id, !conv.isArchived)
                          }}
                        >
                          <Icon name={conv.isArchived ? "folder-open" : "archive"} className="mr-2" />
                          {conv.isArchived ? "Unarchive" : "Archive"}
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          className="text-destructive focus:text-destructive"
                          onClick={(e) => {
                            e.stopPropagation()
                            onDelete(conv.id)
                          }}
                        >
                          <Icon name="trash" className="mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                )
              })}
            </div>
          )}
        </ScrollArea>
      </SheetContent>
    </Sheet>
  )
}
