"use client"

import { useMemo } from "react"
import type { ProductVariation } from "@/lib/types"
import { cn } from "@/lib/utils"

interface VariantPickerProps {
  variations: ProductVariation[]
  selected: ProductVariation | null
  onSelect: (variation: ProductVariation) => void
  onViewSizeChart?: () => void
}

export function VariantPicker({ variations, selected, onSelect, onViewSizeChart }: VariantPickerProps) {
  // Extract unique colors
  const colors = useMemo(() => {
    const colorMap = new Map<string, string>()

    variations.forEach((v) => {
      if (!colorMap.has(v.color)) {
        colorMap.set(v.color, v.colorHex || "#000")
      }
    })

    return Array.from(colorMap.entries()).map(([name, hex]) => ({ name, hex }))
  }, [variations])

  const selectedSize = selected?.size || ""
  const selectedColor = selected?.color || ""

  // Sizes are scoped to the currently selected color – color is the primary dimension
  const sizes = useMemo(() => {
    if (!selectedColor) return []

    const sizeSet = new Set<string>()
    variations.forEach((v) => {
      if (v.color === selectedColor) {
        sizeSet.add(v.size)
      }
    })
    return Array.from(sizeSet)
  }, [variations, selectedColor])

  const handleSizeSelect = (size: string) => {
    if (!selectedColor) return

    const variation = variations.find((v) => v.size === size && v.color === selectedColor)

    if (variation) onSelect(variation)
  }

  const handleColorSelect = (color: string) => {
    // When changing color, always stay within that single color and pick a sensible default size
    const variationForColor =
      variations.find((v) => v.color === color && v.inventory > 0) ||
      variations.find((v) => v.color === color)

    if (variationForColor) onSelect(variationForColor)
  }

  // Check if a size/color combination is available
  const isAvailable = (size: string, color: string) => {
    return variations.some((v) => v.size === size && v.color === color && v.inventory > 0)
  }

  return (
    <div className="space-y-4">
      {/* Size Selector (depends on selected color) */}
      <div>
        <label className="text-sm font-medium mb-2 flex items-center gap-2">
          <span>
            Size: <span className="text-muted-foreground">{selectedSize || (selectedColor ? "" : "Select a color first")}</span>
          </span>
          {onViewSizeChart && (
            <button
              type="button"
              onClick={onViewSizeChart}
              className="text-xs text-primary underline-offset-2 hover:underline"
            >
              View size chart
            </button>
          )}
        </label>
        <div className="flex flex-wrap gap-2">
          {!selectedColor && (
            <span className="text-xs text-muted-foreground">Choose a color to see available sizes.</span>
          )}
          {selectedColor &&
            sizes.map((size) => {
              const hasStock = isAvailable(size, selectedColor)

              return (
                <button
                  key={size}
                  onClick={() => handleSizeSelect(size)}
                  disabled={!hasStock}
                  className={cn(
                    "relative min-w-[3rem] h-10 px-3 rounded-lg border text-sm font-medium transition-all",
                    selectedSize === size
                      ? "border-primary bg-primary text-primary-foreground"
                      : hasStock
                        ? "border-border hover:border-primary"
                        : "border-border bg-muted text-muted-foreground cursor-not-allowed opacity-50",
                  )}
                >
                  <span>{size}</span>
                  {!hasStock && (
                    <span className="absolute -top-1 -right-1 rounded-full bg-destructive text-destructive-foreground text-[10px] px-1 py-px">
                      Out
                    </span>
                  )}
                </button>
              )
            })}
        </div>
      </div>

      {/* Color Selector */}
      <div>
        <label className="text-sm font-medium mb-2 block">
          Color: <span className="text-muted-foreground">{selectedColor}</span>
        </label>
        <div className="flex flex-wrap gap-2">
          {colors.map(({ name, hex }) => {
            const hasStock = selectedSize
              ? isAvailable(selectedSize, name)
              : variations.some((v) => v.color === name && v.inventory > 0)

            return (
              <button
                key={name}
                onClick={() => handleColorSelect(name)}
                disabled={!hasStock}
                className={cn(
                  "w-10 h-10 rounded-full border-2 transition-all relative",
                  selectedColor === name
                    ? "border-primary ring-2 ring-primary ring-offset-2 ring-offset-background"
                    : hasStock
                      ? "border-transparent hover:border-primary/50"
                      : "opacity-50 cursor-not-allowed",
                )}
                style={{ backgroundColor: hex }}
                title={name}
                aria-label={`Select ${name} color`}
              >
                {!hasStock && (
                  <>
                    <span className="absolute inset-0 flex items-center justify-center">
                      <span className="w-full h-0.5 bg-destructive rotate-45 absolute" />
                    </span>
                    <span className="absolute -bottom-1 -right-1 rounded-full bg-destructive text-destructive-foreground text-[10px] px-1 py-px">
                      Out
                    </span>
                  </>
                )}
              </button>
            )
          })}
        </div>
      </div>

      {/* Stock info */}
      {selected && (
        <p className="text-sm text-muted-foreground">
          {selected.inventory > 0 ? `${selected.inventory} items in stock` : "Out of stock"}
        </p>
      )}
    </div>
  )
}
