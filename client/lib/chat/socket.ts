import { io, type Socket } from "socket.io-client"
import { API_BASE_ORIGIN } from "@/lib/api"

const TOKEN_STORAGE_KEY = "yamada-access-token"

function getStoredToken(): string | null {
  if (typeof window === "undefined") return null
  return localStorage.getItem(TOKEN_STORAGE_KEY)
}

export type ChatMessageCallback = (payload: Record<string, unknown>) => void
export type ChatReadCallback = (payload: Record<string, unknown>) => void
export type ChatPresenceCallback = (payload: Record<string, unknown>) => void

class ChatSocketService {
  private socket: Socket | null = null
  private token: string | null = null
  private onMessage: ChatMessageCallback | null = null
  private onRead: ChatReadCallback | null = null
  private onPresence: ChatPresenceCallback | null = null

  get isConnected(): boolean {
    return this.socket?.connected ?? false
  }

  connect(
    token: string,
    handlers: {
      onMessage?: ChatMessageCallback
      onRead?: ChatReadCallback
      onPresence?: ChatPresenceCallback
    },
  ): void {
    if (this.socket?.connected && this.token === token) {
      this.onMessage = handlers.onMessage ?? null
      this.onRead = handlers.onRead ?? null
      this.onPresence = handlers.onPresence ?? null
      return
    }

    this.disconnect()
    this.token = token
    this.onMessage = handlers.onMessage ?? null
    this.onRead = handlers.onRead ?? null
    this.onPresence = handlers.onPresence ?? null

    const url = API_BASE_ORIGIN.replace(/\/static$/, "")

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

    this.socket.on("chat_message", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onMessage?.(data as Record<string, unknown>)
      }
    })

    this.socket.on("chat_read", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onRead?.(data as Record<string, unknown>)
      }
    })

    this.socket.on("chat_presence", (data: unknown) => {
      if (data && typeof data === "object") {
        this.onPresence?.(data as Record<string, unknown>)
      }
    })
  }

  joinConversation(conversationId: number): void {
    this.socket?.emit("join_conversation", { conversationId })
  }

  disconnect(): void {
    this.socket?.disconnect()
    this.socket = null
    this.token = null
    this.onMessage = null
    this.onRead = null
    this.onPresence = null
  }
}

export const chatSocket = new ChatSocketService()
