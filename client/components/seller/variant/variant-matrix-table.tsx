"use client"

import { Icon } from "@/components/ui/icon"
import { ColorSwatch } from "@/components/ui/color-swatch"
import type { VariantEntry } from "./types"

interface VariantMatrixTableProps {
  variants: VariantEntry[]
  onUpdate: (id: string, field: keyof VariantEntry, value: unknown) => void
  onRemove: (id: string) => void
  onAddCustom: () => void
}

export function VariantMatrixTable({
  variants,
  onUpdate,
  onRemove,
  onAddCustom,
}: VariantMatrixTableProps) {
  if (variants.length === 0) {
    return (
      <div className="text-center py-8 border-2 border-dashed rounded-xl bg-muted/20">
        <Icon name="grid" size="xl" className="mx-auto text-muted-foreground mb-2" />
        <p className="text-muted-foreground text-sm">
          Select colors and sizes, then click Generate Variants
        </p>
      </div>
    )
  }

  const hasDuplicates = checkDuplicates(variants)

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium">
          {variants.length} variant{variants.length > 1 ? "s" : ""}
        </p>
        <button
          type="button"
          onClick={onAddCustom}
          className="flex items-center gap-1 text-xs text-primary hover:underline"
        >
          <Icon name="plus" size="sm" />
          Add custom variant
        </button>
      </div>

      <div className="overflow-x-auto rounded-xl border">
        <table className="min-w-full text-sm">
          <thead className="bg-muted/50">
            <tr>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground w-12">#</th>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground">Color</th>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground">Size</th>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground w-24">Stock</th>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground w-28">SKU</th>
              <th className="px-3 py-2 text-left font-medium text-xs text-muted-foreground w-24">Price</th>
              <th className="px-3 py-2 w-10" />
            </tr>
          </thead>
          <tbody>
            {variants.map((variant, index) => {
              const duplicate = hasDuplicates && isDuplicate(variants, variant)
              return (
                <tr
                  key={variant.id}
                  className={`border-t transition-colors ${
                    duplicate ? "bg-destructive/5" : "hover:bg-muted/30"
                  }`}
                >
                  <td className="px-3 py-2 text-xs text-muted-foreground">{index + 1}</td>

                  <td className="px-3 py-2">
                    <div className="flex items-center gap-2">
                      <ColorSwatch hex={variant.color.hex} size="sm" />
                      <span className="text-xs">{variant.color.name}</span>
                    </div>
                  </td>

                  <td className="px-3 py-2">
                    <span className="text-sm font-medium">{variant.size}</span>
                  </td>

                  <td className="px-3 py-2">
                    <input
                      type="number"
                      min={0}
                      value={variant.stock}
                      onChange={(e) =>
                        onUpdate(variant.id, "stock", Number(e.target.value) || 0)
                      }
                      className="w-full px-2 py-1 rounded-lg border bg-background text-sm focus:ring-2 focus:ring-primary outline-none"
                    />
                  </td>

                  <td className="px-3 py-2">
                    <input
                      type="text"
                      value={variant.sku}
                      onChange={(e) => onUpdate(variant.id, "sku", e.target.value)}
                      placeholder="Optional"
                      className="w-full px-2 py-1 rounded-lg border bg-background text-sm focus:ring-2 focus:ring-primary outline-none"
                    />
                  </td>

                  <td className="px-3 py-2">
                    <input
                      type="number"
                      min={0}
                      step="0.01"
                      value={variant.price ?? ""}
                      onChange={(e) =>
                        onUpdate(
                          variant.id,
                          "price",
                          e.target.value ? Number(e.target.value) : null,
                        )
                      }
                      placeholder="Same as base"
                      className="w-full px-2 py-1 rounded-lg border bg-background text-sm focus:ring-2 focus:ring-primary outline-none"
                    />
                  </td>

                  <td className="px-3 py-2">
                    <button
                      type="button"
                      onClick={() => onRemove(variant.id)}
                      className="p-1 rounded-md text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                    >
                      <Icon name="trash" size="sm" />
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {hasDuplicates && (
        <p className="text-xs text-destructive flex items-center gap-1">
          <Icon name="alert-triangle" size="sm" />
          Duplicate variant combinations detected
        </p>
      )}
    </div>
  )
}

function checkDuplicates(variants: VariantEntry[]): boolean {
  const seen = new Set<string>()
  for (const v of variants) {
    const key = `${v.color.hex}|${v.size}`
    if (seen.has(key)) return true
    seen.add(key)
  }
  return false
}

function isDuplicate(variants: VariantEntry[], variant: VariantEntry): boolean {
  const key = `${variant.color.hex}|${variant.size}`
  return variants.filter((v) => `${v.color.hex}|${v.size}` === key).length > 1
}
