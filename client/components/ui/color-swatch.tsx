"use client"

import { Icon } from "@/components/ui/icon"

interface ColorSwatchProps {
  hex: string
  name?: string
  size?: "sm" | "md" | "lg"
  selected?: boolean
  onClick?: () => void
  className?: string
}

export function ColorSwatch({
  hex,
  name,
  size = "md",
  selected,
  onClick,
  className = "",
}: ColorSwatchProps) {
  const sizeClass =
    size === "sm" ? "w-6 h-6" : size === "lg" ? "w-10 h-10" : "w-8 h-8"

  return (
    <button
      type="button"
      onClick={onClick}
      title={name ? `${name} (${hex})` : hex}
      className={`
        relative inline-flex items-center justify-center rounded-full
        transition-all duration-150 focus:outline-none focus:ring-2 focus:ring-primary/40
        ${sizeClass} ${className}
      `}
      style={{ backgroundColor: hex }}
    >
      {selected && (
        <span className="absolute inset-0 rounded-full ring-2 ring-primary ring-offset-2 ring-offset-background" />
      )}
      {(hex === "#FFFFFF" || hex === "#FAF9F6" || hex === "#FFFDD0" || hex === "#F5F5DC" || hex === "#FFDAB9") && (
        <span className="absolute inset-0 rounded-full border border-border" />
      )}
      {selected && (
        <span className="relative z-10">
          <Icon name="check" size="sm" className="text-white drop-shadow" />
        </span>
      )}
    </button>
  )
}
