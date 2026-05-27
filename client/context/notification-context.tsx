"use client"

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  useRef,
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
  const mountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const role = getRole()

  const fetchNotifications = useCallback(async () => {
    if (!isAuthenticated) {
      setNotifications([])
      return
    }

    setIsLoading(true)
    try {
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

      items = items.sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      )
      if (mountedRef.current) {
        setNotifications(items)
      }
    } catch {
      if (mountedRef.current) {
        setNotifications([])
      }
    } finally {
      if (mountedRef.current) {
        setIsLoading(false)
      }
    }
  }, [isAuthenticated, role])

  useEffect(() => {
    mountedRef.current = true
    void fetchNotifications()
    return () => {
      mountedRef.current = false
      abortRef.current?.abort()
    }
  }, [fetchNotifications])

  const markAsRead = useCallback(async (id: string) => {
    setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: true } : n)))
    try {
      await notificationsApi.markAsRead(Number(id))
    } catch {
      setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: false } : n)))
    }
  }, [])

  const markAllAsRead = useCallback(async () => {
    const previous = notifications
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
    try {
      await notificationsApi.markAllAsRead()
    } catch {
      setNotifications(previous)
    }
  }, [notifications])

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
