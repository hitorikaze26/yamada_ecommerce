"use client"

import { useReducer } from "react"
import { Icon } from "@/components/ui/icon"
import { ColorPickerHybrid } from "./color-picker-hybrid"
import { SizeSelector } from "./size-selector"
import { VariantMatrixTable } from "./variant-matrix-table"
import {
  variantReducer,
  generateVariantId,
  SIZE_OPTIONS,
  SHOE_SIZE_OPTIONS,
  type VariantEntry,
  type VariantFormState,
} from "./types"
import type { ColorOption } from "@/data/colors"

interface VariantBuilderProps {
  value: VariantEntry[]
  onChange: (variants: VariantEntry[]) => void
  sizeOptions?: "clothing" | "shoes" | "accessory"
}

export function ProductVariantBuilder({
  value,
  onChange,
  sizeOptions = "clothing",
}: VariantBuilderProps) {
  const [state, dispatch] = useReducer(variantReducer, {
    selectedColors: extractColors(value),
    selectedSizes: extractSizes(value),
    variants: value,
  })

  const sizes =
    sizeOptions === "shoes"
      ? SHOE_SIZE_OPTIONS
      : sizeOptions === "accessory"
        ? ["Free Size"]
        : SIZE_OPTIONS

  const handleColorsChange = (colors: ColorOption[]) => {
    dispatch({ type: "SET_COLORS", colors })
  }

  const handleSizesChange = (sizes: string[]) => {
    dispatch({ type: "SET_SIZES", sizes })
  }

  const handleGenerate = () => {
    dispatch({ type: "GENERATE_VARIANTS" })
  }

  const handleUpdate = (id: string, field: keyof VariantEntry, val: unknown) => {
    dispatch({ type: "UPDATE_VARIANT", id, field, value: val })
  }

  const handleRemove = (id: string) => {
    dispatch({ type: "REMOVE_VARIANT", id })
  }

  const handleAddCustom = () => {
    const firstColor = state.selectedColors[0] || { name: "Black", hex: "#000000" }
    const firstSize = state.selectedSizes[0] || sizes[0] || "M"
    dispatch({
      type: "ADD_CUSTOM_VARIANT",
      variant: {
        id: generateVariantId(),
        color: firstColor,
        size: firstSize,
        stock: 0,
        sku: "",
        price: null,
      },
    })
  }

  const syncToParent = () => {
    onChange(state.variants)
  }

  const totalStock = state.variants.reduce((sum, v) => sum + (v.stock || 0), 0)

  return (
    <div className="bg-card border rounded-2xl p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">Variants</h2>
          <p className="text-sm text-muted-foreground">
            Add colors, sizes, and manage inventory per variant
          </p>
        </div>
        {totalStock > 0 && (
          <span className="text-xs text-muted-foreground bg-muted px-3 py-1 rounded-full">
            Total stock: {totalStock}
          </span>
        )}
      </div>

      {/* Step 1: Pick Colors */}
      <div className="space-y-2">
        <label className="block text-sm font-medium">
          Colors
          {state.selectedColors.length > 0 && (
            <span className="text-muted-foreground font-normal ml-1">
              ({state.selectedColors.length} selected)
            </span>
          )}
        </label>
        <ColorPickerHybrid
          selected={state.selectedColors}
          onChange={handleColorsChange}
        />
      </div>

      {/* Step 2: Pick Sizes */}
      <SizeSelector
        options={sizes}
        selected={state.selectedSizes}
        onChange={handleSizesChange}
      />

      {/* Step 3: Generate Matrix */}
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={handleGenerate}
          disabled={state.selectedColors.length === 0 || state.selectedSizes.length === 0}
          className="flex items-center gap-2 px-5 py-2.5 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Icon name="grid" size="sm" />
          Generate Variants (
          {state.selectedColors.length * state.selectedSizes.length} combinations)
        </button>

        {state.variants.length > 0 && (
          <button
            type="button"
            onClick={syncToParent}
            className="text-xs text-muted-foreground hover:text-foreground underline"
          >
            Sync to form
          </button>
        )}
      </div>

      {/* Step 4: Manage Variants Table */}
      <VariantMatrixTable
        variants={state.variants}
        onUpdate={handleUpdate}
        onRemove={handleRemove}
        onAddCustom={handleAddCustom}
      />
    </div>
  )
}

function extractColors(variants: VariantEntry[]): ColorOption[] {
  const map = new Map<string, ColorOption>()
  for (const v of variants) {
    const key = `${v.color.name}|${v.color.hex}`
    if (!map.has(key)) map.set(key, v.color)
  }
  return Array.from(map.values())
}

function extractSizes(variants: VariantEntry[]): string[] {
  return Array.from(new Set(variants.map((v) => v.size)))
}
