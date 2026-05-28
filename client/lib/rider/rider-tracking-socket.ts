import { io, type Socket } from "socket.io-client"
import { Env } from "@/lib/env"

const TOKEN_STORAGE_KEY = "yamada-access-token"

function getStoredToken(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem(TOKEN_STORAGE_KEY)
}

export type RiderLocationUpdate = {
  riderId: number
  orderId: number
  latitude: number
  longitude: number
  timestamp: string
}

export type RiderLocationCallback = (data: RiderLocationUpdate) => void

class RiderTrackingSocketService {
  private socket: Socket | null = null
  private subscribedOrderId: number | null = null
  private onLocationUpdate: RiderLocationCallback | null = null

  get isConnected(): boolean {
    return this.socket?.connected ?? false
  }

  connect(token: string, onLocationUpdate: RiderLocationCallback): void {
    if (this.socket?.connected) {
      this.onLocationUpdate = onLocationUpdate
      return
    }

    this.disconnect()
    this.onLocationUpdate = onLocationUpdate

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

    this.socket.on("rider:location_update", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onLocationUpdate?.(data as RiderLocationUpdate)
      }
    })
  }

  subscribeOrder(orderId: number): void {
    if (this.subscribedOrderId === orderId) return
    this.subscribedOrderId = orderId
    this.socket?.emit("rider:subscribe_order", { orderId })
  }

  disconnect(): void {
    this.socket?.disconnect()
    this.socket = null
    this.subscribedOrderId = null
    this.onLocationUpdate = null
  }
}

export const riderTrackingSocket = new RiderTrackingSocketService()
