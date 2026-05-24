"use client"

import { useMemo } from "react"
import { formatDistanceToNow } from "date-fns"
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"

export interface NotificationItem {
  id: string
  title: string
  description: string
  createdAt: string
  read: boolean
}

interface NotificationModalProps {
  open: boolean
  notifications: NotificationItem[]
  onClose: () => void
  onMarkAllAsRead: () => void
  onMarkAsRead?: (id: string) => void
}

function formatNotificationTime(createdAt: string): string {
  if (!createdAt) return ""
  try {
    return formatDistanceToNow(new Date(createdAt), { addSuffix: true })
  } catch {
    return createdAt
  }
}

export function NotificationModal({
  open,
  notifications,
  onClose,
  onMarkAllAsRead,
  onMarkAsRead,
}: NotificationModalProps) {
  const unreadCount = useMemo(
    () => notifications.filter((n) => !n.read).length,
    [notifications],
  )

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="w-[60vw] max-w-sm max-h-[75vh] p-0 overflow-hidden">
        <DialogTitle className="sr-only">Notifications</DialogTitle>
        <div className="flex flex-col h-full">
          <header className="flex items-center justify-between px-5 py-4 border-b">
            <div>
              <h2 className="text-lg font-semibold">Notifications</h2>
              <p className="text-xs text-muted-foreground">
                {unreadCount > 0 ? `${unreadCount} unread` : "You're all caught up"}
              </p>
            </div>
            {unreadCount > 0 && (
              <Button variant="ghost" size="sm" onClick={onMarkAllAsRead}>
                <Icon name="check-double" className="mr-2" />
                Mark all as read
              </Button>
            )}
          </header>

          <div className="flex-1 overflow-y-auto px-5 py-3 space-y-2 max-h-[50vh]">
            {notifications.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mb-3">
                  <Icon name="bell-slash" className="text-muted-foreground" size="lg" />
                </div>
                <p className="text-sm font-medium text-muted-foreground">No notifications yet</p>
                <p className="text-xs text-muted-foreground mt-1">
                  We&apos;ll notify you when something important happens
                </p>
              </div>
            ) : (
              notifications.map((notification) => (
                <div
                  key={notification.id}
                  onClick={() => !notification.read && onMarkAsRead?.(notification.id)}
                  className={`flex gap-3 rounded-xl border px-4 py-3 text-sm cursor-pointer transition-all duration-200 ${
                    notification.read
                      ? "bg-background hover:bg-muted/50"
                      : "bg-primary/5 border-primary/20 hover:bg-primary/10"
                  }`}
                >
                  <div className="mt-0.5 flex-shrink-0">
                    <span
                      className={`inline-block w-2.5 h-2.5 rounded-full ${
                        notification.read ? "bg-muted-foreground/30" : "bg-primary"
                      }`}
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className={`font-medium leading-snug ${notification.read ? "" : "text-foreground"}`}>
                      {notification.title}
                    </p>
                    <p className="text-xs text-muted-foreground mt-1 line-clamp-2">
                      {notification.description}
                    </p>
                    <p className="text-[10px] text-muted-foreground/70 mt-2">
                      {formatNotificationTime(notification.createdAt)}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
