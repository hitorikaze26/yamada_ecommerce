import { io, type Socket } from "socket.io-client"
import { Env } from "@/lib/env"

const TOKEN_STORAGE_KEY = "yamada-access-token"

function getStoredToken(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem(TOKEN_STORAGE_KEY)
}

export type NotificationCallback = (payload: Record<string, unknown>) => void

class NotificationSocketService {
  private socket: Socket | null = null
  private token: string | null = null
  private onNotification: NotificationCallback | null = null
  private onNotificationsRead: NotificationCallback | null = null

  get isConnected(): boolean {
    return this.socket?.connected ?? false
  }

  connect(
    token: string,
    handlers: {
      onNotification?: NotificationCallback
      onNotificationsRead?: NotificationCallback
    },
  ): void {
    if (this.socket?.connected && this.token === token) {
      this.onNotification = handlers.onNotification ?? null
      this.onNotificationsRead = handlers.onNotificationsRead ?? null
      return
    }

    this.disconnect()
    this.token = token
    this.onNotification = handlers.onNotification ?? null
    this.onNotificationsRead = handlers.onNotificationsRead ?? null

    const url = Env.API_BASE_ORIGIN.replace(/\/static$/, "")

    this.socket = io(url, {
      transports: ["websocket", "polling"],
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 5000,
      auth: { token },
    })

    this.socket.on("connect_error", () => {
      const fresh = getStoredToken()
      if (fresh && this.socket) {
        this.socket.auth = { token: fresh }
      }
    })

    this.socket.on("notification", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onNotification?.(data as Record<string, unknown>)
      }
    })

    this.socket.on("notifications_read", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onNotificationsRead?.(data as Record<string, unknown>)
      }
    })
  }

  disconnect(): void {
    this.socket?.disconnect()
    this.socket = null
    this.token = null
    this.onNotification = null
    this.onNotificationsRead = null
  }
}

export const notificationSocket = new NotificationSocketService()
