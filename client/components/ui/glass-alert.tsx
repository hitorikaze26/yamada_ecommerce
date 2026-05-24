"use client"

import * as React from "react"
import { cn } from "@/lib/utils"

export type GlassAlertVariant = "success" | "error" | "info" | "warning"

export interface GlassAlertProps extends React.HTMLAttributes<HTMLDivElement> {
  open: boolean
  title?: string
  description?: string
  variant?: GlassAlertVariant
  onClose?: () => void
  /** Auto-close after ms. Set to 0 or undefined to disable */
  autoHideDuration?: number
}

const variantStyles: Record<GlassAlertVariant, string> = {
  success: "border-emerald-500 bg-emerald-500/18 shadow-emerald-500/50",
  error: "border-rose-500 bg-rose-500/18 shadow-rose-500/50",
  info: "border-sky-500 bg-sky-500/18 shadow-sky-500/50",
  warning: "border-amber-500 bg-amber-500/20 shadow-amber-500/50",
}

export function GlassAlert({
  open,
  title,
  description,
  variant = "info",
  onClose,
  autoHideDuration = 3000,
  className,
  ...props
}: GlassAlertProps) {
  const [internalOpen, setInternalOpen] = React.useState(open)

  React.useEffect(() => {
    setInternalOpen(open)
  }, [open])

  React.useEffect(() => {
    if (!internalOpen || !autoHideDuration) return

    const id = window.setTimeout(() => {
      setInternalOpen(false)
      onClose?.()
    }, autoHideDuration)

    return () => window.clearTimeout(id)
  }, [internalOpen, autoHideDuration, onClose])

  if (!internalOpen) return null

  const handleClose = () => {
    setInternalOpen(false)
    onClose?.()
  }

  return (
    <div
      className={cn(
        "pointer-events-none fixed inset-x-0 top-3 z-[60] flex justify-center px-4 sm:px-0",
      )}
    >
      <div
        role="status"
        className={cn(
          "pointer-events-auto relative flex max-w-md items-start gap-3 rounded-2xl border px-4 py-3 text-sm",
          "backdrop-blur-xl bg-slate-900/80 dark:bg-slate-900/80",
          "shadow-[0_18px_60px_rgba(15,23,42,0.75)] ring-1 ring-white/10",
          "before:pointer-events-none before:absolute before:inset-px before:rounded-2xl before:bg-gradient-to-br before:from-white/25 before:via-white/5 before:to-white/5 before:opacity-60 before:mix-blend-soft-light",
          "after:pointer-events-none after:absolute after:-inset-0.5 after:rounded-3xl after:bg-[radial-gradient(circle_at_0_0,rgba(248,250,252,0.9),transparent_55%),radial-gradient(circle_at_100%_0,rgba(56,189,248,0.35),transparent_55%)] after:opacity-30",
          "[&_>*]:relative [&_>*]:z-10",
          variantStyles[variant],
          className,
        )}
        {...props}
      >
        <div className="flex-1 space-y-1">
          {title && (
            <p className="text-xs font-semibold tracking-wide uppercase text-slate-50 drop-shadow-md">
              {title}
            </p>
          )}
          {description && (
            <p className="text-[13px] leading-snug text-slate-50/95">
              {description}
            </p>
          )}
        </div>

        {onClose && (
          <button
            type="button"
            onClick={handleClose}
            className="ml-2 inline-flex h-7 w-7 items-center justify-center rounded-full border border-white/60 bg-white/15 text-[11px] font-medium text-slate-900 dark:text-slate-50 shadow-sm transition hover:bg-white/25"
          >
            ✕
          </button>
        )}
      </div>
    </div>
  )
}
