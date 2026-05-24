"use client"

import { Icon } from "@/components/ui/icon"
import { resolveImageUrl } from "@/lib/api"
import type { ChatMessage } from "@/lib/chat/types"
import { formatFullTime } from "@/components/chat/chat-ui"
import { chatPreviewFromMessage } from "@/lib/chat/mappers"

interface ChatMessageBubbleProps {
  message: ChatMessage
  replyTo?: ChatMessage | null
  showTime?: boolean
}

export function ChatMessageBubble({ message, replyTo, showTime = true }: ChatMessageBubbleProps) {
  if (message.messageType === "system") {
    return (
      <div className="flex justify-center py-1">
        <span className="text-[11px] text-muted-foreground bg-muted/80 px-3 py-1 rounded-full max-w-[90%] text-center">
          {message.body}
        </span>
      </div>
    )
  }

  const isMine = message.isMine

  return (
    <div className={`flex ${isMine ? "justify-end" : "justify-start"} group`}>
      <div
        className={`max-w-[min(85%,320px)] ${
          isMine ? "items-end" : "items-start"
        } flex flex-col gap-0.5`}
      >
        <div
          className={`rounded-2xl px-3.5 py-2.5 text-sm shadow-sm transition-shadow ${
            isMine
              ? "bg-primary text-primary-foreground rounded-br-md"
              : "bg-card border border-border/60 rounded-bl-md"
          }`}
        >
          {replyTo && (
            <div
              className={`mb-2 pl-2 border-l-2 text-[11px] opacity-90 line-clamp-2 ${
                isMine ? "border-primary-foreground/50" : "border-primary/40"
              }`}
            >
              {chatPreviewFromMessage(replyTo)}
            </div>
          )}

          <MessageBody message={message} isMine={isMine} />
        </div>

        {showTime && (
          <span
            className={`text-[10px] px-1 opacity-0 group-hover:opacity-100 transition-opacity ${
              isMine ? "text-right text-muted-foreground" : "text-muted-foreground"
            }`}
          >
            {formatFullTime(message.createdAt)}
          </span>
        )}
      </div>
    </div>
  )
}

function MessageBody({ message, isMine }: { message: ChatMessage; isMine: boolean }) {
  const meta = message.metadata

  switch (message.messageType) {
    case "image": {
      const url = resolveImageUrl(String(meta.fileUrl ?? meta.url ?? ""))
      if (url) {
        return (
          <a
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="block overflow-hidden rounded-lg -mx-0.5"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={url}
              alt="Shared image"
              className="max-h-52 w-full object-cover hover:opacity-95 transition-opacity"
            />
          </a>
        )
      }
      return (
        <p className="flex items-center gap-2 whitespace-pre-wrap break-words">
          <Icon name="image" size="sm" />
          Photo
        </p>
      )
    }
    case "file": {
      const url = String(meta.fileUrl ?? "")
      const name = String(meta.fileName ?? message.body ?? "Attachment")
      const href = url.startsWith("http") ? url : resolveImageUrl(url) ?? url
      return (
        <a
          href={href}
          target="_blank"
          rel="noopener noreferrer"
          className={`flex items-center gap-2.5 rounded-lg p-2 -mx-0.5 ${
            isMine ? "bg-primary-foreground/10 hover:bg-primary-foreground/15" : "bg-muted/50 hover:bg-muted"
          } transition-colors`}
        >
          <span
            className={`flex h-9 w-9 items-center justify-center rounded-lg shrink-0 ${
              isMine ? "bg-primary-foreground/15" : "bg-primary/10"
            }`}
          >
            <Icon name="paperclip" size="sm" />
          </span>
          <span className="truncate font-medium text-xs">{name}</span>
        </a>
      )
    }
    case "product": {
      const img = resolveImageUrl(String(meta.imageUrl ?? ""))
      return (
        <div
          className={`rounded-xl overflow-hidden border min-w-[200px] -mx-0.5 ${
            isMine ? "border-primary-foreground/20 bg-primary-foreground/5" : "border-border bg-background"
          }`}
        >
          {img && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={img} alt="" className="w-full h-28 object-cover" />
          )}
          <div className="p-2.5">
            <p className="text-[10px] uppercase tracking-wide opacity-70 mb-0.5">Product</p>
            <p className={`font-semibold text-sm leading-tight ${isMine ? "" : "text-foreground"}`}>
              {String(meta.name ?? "Product")}
            </p>
            <p className={`text-sm mt-1 font-medium ${isMine ? "opacity-90" : "text-primary"}`}>
              ₱{Number(meta.price ?? 0).toLocaleString()}
            </p>
          </div>
        </div>
      )
    }
    case "order": {
      const img = resolveImageUrl(String(meta.productImageUrl ?? ""))
      return (
        <div
          className={`rounded-xl overflow-hidden border min-w-[200px] -mx-0.5 ${
            isMine ? "border-primary-foreground/20 bg-primary-foreground/5" : "border-border bg-background"
          }`}
        >
          {img && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={img} alt="" className="w-full h-24 object-cover" />
          )}
          <div className="p-2.5">
            <p className="text-[10px] uppercase tracking-wide opacity-70 mb-0.5">Order</p>
            <p className={`font-semibold text-sm leading-tight ${isMine ? "" : "text-foreground"}`}>
              {String(meta.productName ?? meta.displayId ?? "Order")}
            </p>
            <p className="text-[11px] opacity-75 capitalize mt-0.5">{String(meta.status ?? "")}</p>
            <p className={`text-sm mt-1.5 font-medium ${isMine ? "opacity-90" : "text-primary"}`}>
              ₱{Number(meta.totalAmount ?? 0).toLocaleString()}
            </p>
          </div>
        </div>
      )
    }
    default:
      return <p className="whitespace-pre-wrap break-words leading-relaxed">{message.body}</p>
  }
}
