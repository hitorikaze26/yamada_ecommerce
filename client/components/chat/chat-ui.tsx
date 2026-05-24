"use client"

import { resolveImageUrl } from "@/lib/api"
import { Icon } from "@/components/ui/icon"
import type { ChatMessage } from "@/lib/chat/types"

export function roleLabel(role: string): string {
  switch (role) {
    case "buyer":
      return "Buyer"
    case "seller":
      return "Seller"
    case "rider":
      return "Rider"
    case "admin":
      return "Support"
    default:
      return role.charAt(0).toUpperCase() + role.slice(1)
  }
}

export function roleBadgeClass(role: string): string {
  switch (role) {
    case "buyer":
      return "bg-sky-100 text-sky-800 dark:bg-sky-950/50 dark:text-sky-300"
    case "seller":
      return "bg-primary/15 text-primary dark:bg-primary/25"
    case "rider":
      return "bg-violet-100 text-violet-800 dark:bg-violet-950/50 dark:text-violet-300"
    case "admin":
      return "bg-amber-100 text-amber-900 dark:bg-amber-950/50 dark:text-amber-300"
    default:
      return "bg-muted text-muted-foreground"
  }
}

export function ChatAvatar({
  name,
  imageUrl,
  size = "md",
  online,
}: {
  name: string
  imageUrl?: string | null
  size?: "sm" | "md" | "lg"
  online?: boolean
}) {
  const resolved = resolveImageUrl(imageUrl ?? null)
  const dim = size === "sm" ? "w-9 h-9 text-xs" : size === "lg" ? "w-12 h-12 text-base" : "w-11 h-11 text-sm"
  const dot =
    size === "sm" ? "w-2.5 h-2.5 border-[1.5px]" : "w-3 h-3 border-2"

  return (
    <div className="relative shrink-0">
      <div
        className={`${dim} rounded-full bg-gradient-to-br from-primary/20 to-primary/5 border border-primary/10 flex items-center justify-center font-semibold text-primary overflow-hidden`}
      >
        {resolved ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={resolved} alt="" className="w-full h-full object-cover" />
        ) : (
          name.charAt(0).toUpperCase()
        )}
      </div>
      {online !== undefined && (
        <span
          className={`absolute bottom-0 right-0 ${dot} rounded-full border-background ${
            online ? "bg-emerald-500" : "bg-muted-foreground/40"
          }`}
          aria-hidden
        />
      )}
    </div>
  )
}

export function ChatRoleBadge({ role }: { role: string }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium capitalize ${roleBadgeClass(role)}`}
    >
      {roleLabel(role)}
    </span>
  )
}

export function ChatEmptyState({
  icon = "envelope",
  title,
  description,
}: {
  icon?: string
  title: string
  description?: string
}) {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-6 text-center">
      <div className="w-14 h-14 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
        <Icon name={icon} className="text-primary w-7 h-7" />
      </div>
      <p className="text-sm font-medium text-foreground">{title}</p>
      {description && (
        <p className="text-xs text-muted-foreground mt-1 max-w-[240px]">{description}</p>
      )}
    </div>
  )
}

export function ChatListSkeleton() {
  return (
    <div className="space-y-2 px-3 py-2 animate-pulse">
      {Array.from({ length: 6 }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 rounded-xl p-3">
          <div className="w-11 h-11 rounded-full bg-muted shrink-0" />
          <div className="flex-1 space-y-2">
            <div className="h-3 bg-muted rounded w-2/3" />
            <div className="h-2.5 bg-muted rounded w-full" />
          </div>
        </div>
      ))}
    </div>
  )
}

export function ChatThreadSkeleton() {
  return (
    <div className="space-y-4 px-4 py-6 animate-pulse">
      <div className="flex justify-start">
        <div className="h-10 w-48 bg-muted rounded-2xl rounded-bl-sm" />
      </div>
      <div className="flex justify-end">
        <div className="h-8 w-36 bg-primary/20 rounded-2xl rounded-br-sm" />
      </div>
      <div className="flex justify-start">
        <div className="h-14 w-56 bg-muted rounded-2xl rounded-bl-sm" />
      </div>
    </div>
  )
}

function sameDay(a: Date, b: Date): boolean {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}

export function formatDateSeparator(iso: string | null): string {
  if (!iso) return "Earlier"
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return "Earlier"
  const now = new Date()
  if (sameDay(d, now)) return "Today"
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  if (sameDay(d, yesterday)) return "Yesterday"
  return d.toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  })
}

export type ThreadListItem =
  | { kind: "date"; key: string; label: string }
  | { kind: "message"; key: string; message: ChatMessage; showTime: boolean }

export function buildThreadListItems(messages: ChatMessage[]): ThreadListItem[] {
  const items: ThreadListItem[] = []
  let lastDate: string | null = null

  messages.forEach((msg, index) => {
    const dateKey = msg.createdAt
      ? new Date(msg.createdAt).toDateString()
      : "unknown"
    if (dateKey !== lastDate) {
      items.push({
        kind: "date",
        key: `date-${dateKey}`,
        label: formatDateSeparator(msg.createdAt),
      })
      lastDate = dateKey
    }
    const next = messages[index + 1]
    const showTime = Boolean(
      !next ||
        next.isMine !== msg.isMine ||
        (msg.createdAt &&
          next.createdAt &&
          new Date(next.createdAt).getTime() - new Date(msg.createdAt).getTime() > 300000),
    )
    items.push({
      kind: "message",
      key: `msg-${msg.id}`,
      message: msg,
      showTime,
    })
  })

  return items
}

export function DateSeparator({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-3 py-2">
      <div className="flex-1 h-px bg-border/80" />
      <span className="text-[10px] font-medium uppercase tracking-wider text-muted-foreground shrink-0">
        {label}
      </span>
      <div className="flex-1 h-px bg-border/80" />
    </div>
  )
}

export function formatFullTime(iso: string | null): string {
  if (!iso) return ""
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ""
  return d.toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })
}
