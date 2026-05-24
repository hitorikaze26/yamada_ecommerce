"use client"

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react"
import { notificationsApi, riderApi, type NotificationDto } from "@/lib/api"
import type { NotificationItem } from "@/components/notifications/notification-modal"
import { useAuth } from "@/context/auth-context"

interface NotificationContextType {
  notifications: NotificationItem[]
  unreadCount: number
  isLoading: boolean
  markAsRead: (id: string) => Promise<void>
  markAllAsRead: () => Promise<void>
  refresh: () => Promise<void>
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined)

export function NotificationProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, getRole } = useAuth()
  const [notifications, setNotifications] = useState<NotificationItem[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const role = getRole()

  const fetchNotifications = useCallback(async () => {
    if (!isAuthenticated) {
      setNotifications([])
      return
    }

    setIsLoading(true)
    try {
      // Fetch ALL notifications for this user — no role/page filter
      // so the same list is shared across homepage and buyer dashboard.
      const response = await notificationsApi.getAll()
      let items: NotificationItem[] = (response.data.notifications || []).map(
        (n: NotificationDto): NotificationItem => ({
          id: String(n.id),
          title: n.title,
          description: n.description,
          createdAt: n.createdAt ?? "",
          read: n.read,
        }),
      )

      // For riders, also merge delivery-based notifications
      if (role === "rider") {
        try {
          const deliveriesRes = await riderApi.getDeliveries()
          const deliveries = (deliveriesRes.data as any)?.deliveries || []

          const deliveryNotifications: NotificationItem[] = deliveries
            .filter((d: any) => d.status && d.status !== "delivered")
            .map((d: any) => {
              let title = "Delivery Update"
              let description = "Order #" + d.orderId + ": Status updated"

              if (d.status === "pending") {
                title = "Delivery Assigned"
                description = "Order #" + d.orderId + ": New delivery assigned to you"
              } else if (d.status === "pickup") {
                title = "Ready for Pickup"
                description =
                  "Order #" + d.orderId + ": Ready for pickup from " + (d.store?.name || "store")
              } else if (d.status === "transit") {
                title = "In Transit"
                description = "Order #" + d.orderId + ": In transit to customer"
              }

              return {
                id: "delivery-" + d.id,
                title,
                description,
                createdAt: d.createdAt ?? new Date().toISOString(),
                read: d.status === "delivered",
              }
            })

          items = [...items, ...deliveryNotifications]
        } catch {
          // Silently ignore delivery fetch errors
        }
      }

      // Sort newest first
      items = items.sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      )
      setNotifications(items)
    } catch {
      setNotifications([])
    } finally {
      setIsLoading(false)
    }
  }, [isAuthenticated, role])

  useEffect(() => {
    void fetchNotifications()
  }, [fetchNotifications])

  const markAsRead = useCallback(async (id: string) => {
    // Optimistic update
    setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: true } : n)))
    try {
      await notificationsApi.markAsRead(Number(id))
    } catch {
      // Revert on error
      setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: false } : n)))
    }
  }, [])

  const markAllAsRead = useCallback(async () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
    try {
      await notificationsApi.markAllAsRead()
    } catch {
      // Silently ignore — UI already updated optimistically
    }
  }, [])

  const unreadCount = notifications.filter((n) => !n.read).length

  return (
    <NotificationContext.Provider
      value={{
        notifications,
        unreadCount,
        isLoading,
        markAsRead,
        markAllAsRead,
        refresh: fetchNotifications,
      }}
    >
      {children}
    </NotificationContext.Provider>
  )
}

export function useNotifications() {
  const context = useContext(NotificationContext)
  if (!context) {
    throw new Error("useNotifications must be used within a NotificationProvider")
  }
  return context
}
