"use client"

import { useState } from "react"
import { Slider } from "@/components/ui/slider"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { CATEGORIES } from "@/lib/types"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"

interface ProductFiltersProps {
  filters: {
    category: string
    sizes: string[]
    colors: string[]
    priceRange: [number, number]
    sellers: string[]
  }
  onChange: (filters: ProductFiltersProps["filters"]) => void
}

const sizes = ["XS", "S", "M", "L", "XL", "XXL", "36", "37", "38", "39", "40"]

const colors = [
  { name: "Black", hex: "#2E2E2E" },
  { name: "White", hex: "#FAF7F9" },
  { name: "Blush Pink", hex: "#F4C9D6" },
  { name: "Rose", hex: "#C97A8C" },
  { name: "Navy", hex: "#1E2A3A" },
  { name: "Beige", hex: "#F3E7DD" },
  { name: "Lilac", hex: "#D7C8F2" },
]

export function ProductFilters({ filters, onChange }: ProductFiltersProps) {
  const [openSections, setOpenSections] = useState({
    category: true,
    size: true,
    color: true,
    price: true,
  })

  const toggleSection = (section: keyof typeof openSections) => {
    setOpenSections((prev) => ({ ...prev, [section]: !prev[section] }))
  }

  const toggleSize = (size: string) => {
    const newSizes = filters.sizes.includes(size) ? filters.sizes.filter((s) => s !== size) : [...filters.sizes, size]
    onChange({ ...filters, sizes: newSizes })
  }

  const toggleColor = (color: string) => {
    const newColors = filters.colors.includes(color)
      ? filters.colors.filter((c) => c !== color)
      : [...filters.colors, color]
    onChange({ ...filters, colors: newColors })
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
      maximumFractionDigits: 0,
    }).format(price)
  }

  const clearAllFilters = () => {
    onChange({
      category: "",
      sizes: [],
      colors: [],
      priceRange: [0, 5000],
      sellers: [],
    })
  }

  const hasActiveFilters =
    filters.category ||
    filters.sizes.length > 0 ||
    filters.colors.length > 0 ||
    filters.priceRange[0] > 0 ||
    filters.priceRange[1] < 5000

  return (
    <div className="space-y-6">
      {hasActiveFilters && (
        <Button variant="ghost" size="sm" onClick={clearAllFilters} className="w-full justify-start">
          <Icon name="cross" className="mr-2" />
          Clear all filters
        </Button>
      )}

      {/* Categories */}
      <Collapsible open={openSections.category} onOpenChange={() => toggleSection("category")}>
        <CollapsibleTrigger className="flex items-center justify-between w-full py-2 font-semibold">
          Category
          <Icon name={openSections.category ? "angle-small-up" : "angle-small-down"} />
        </CollapsibleTrigger>
        <CollapsibleContent className="space-y-2 pt-2">
          {CATEGORIES.map((category) => (
            <button
              key={category.id}
              onClick={() => onChange({ ...filters, category: filters.category === category.id ? "" : category.id })}
              className={`flex items-center gap-2 w-full p-2 rounded-lg text-sm text-left transition-colors ${
                filters.category === category.id ? "bg-primary/10 text-primary" : "hover:bg-muted"
              }`}
            >
              <Icon name={category.icon} />
              {category.name}
            </button>
          ))}
        </CollapsibleContent>
      </Collapsible>

      {/* Size */}
      <Collapsible open={openSections.size} onOpenChange={() => toggleSection("size")}>
        <CollapsibleTrigger className="flex items-center justify-between w-full py-2 font-semibold">
          Size
          {filters.sizes.length > 0 && (
            <span className="text-xs bg-primary text-primary-foreground px-2 py-0.5 rounded-full mr-2">
              {filters.sizes.length}
            </span>
          )}
          <Icon name={openSections.size ? "angle-small-up" : "angle-small-down"} />
        </CollapsibleTrigger>
        <CollapsibleContent className="pt-2">
          <div className="flex flex-wrap gap-2">
            {sizes.map((size) => (
              <button
                key={size}
                onClick={() => toggleSize(size)}
                className={`min-w-[2.5rem] px-3 py-2 text-sm rounded-lg border transition-all ${
                  filters.sizes.includes(size)
                    ? "border-primary bg-primary text-primary-foreground"
                    : "border-border hover:border-primary"
                }`}
              >
                {size}
              </button>
            ))}
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Color */}
      <Collapsible open={openSections.color} onOpenChange={() => toggleSection("color")}>
        <CollapsibleTrigger className="flex items-center justify-between w-full py-2 font-semibold">
          Color
          {filters.colors.length > 0 && (
            <span className="text-xs bg-primary text-primary-foreground px-2 py-0.5 rounded-full mr-2">
              {filters.colors.length}
            </span>
          )}
          <Icon name={openSections.color ? "angle-small-up" : "angle-small-down"} />
        </CollapsibleTrigger>
        <CollapsibleContent className="pt-2">
          <div className="grid grid-cols-4 gap-2">
            {colors.map((color) => (
              <button
                key={color.name}
                onClick={() => toggleColor(color.name)}
                className={`group relative w-full aspect-square rounded-lg border-2 transition-all ${
                  filters.colors.includes(color.name)
                    ? "border-primary ring-2 ring-primary/20"
                    : "border-transparent hover:border-primary/50"
                }`}
                style={{ backgroundColor: color.hex }}
                title={color.name}
              >
                {filters.colors.includes(color.name) && (
                  <div className="absolute inset-0 flex items-center justify-center">
                    <Icon
                      name="check"
                      className={color.name === "White" || color.name === "Beige" ? "text-foreground" : "text-white"}
                    />
                  </div>
                )}
              </button>
            ))}
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Price Range */}
      <Collapsible open={openSections.price} onOpenChange={() => toggleSection("price")}>
        <CollapsibleTrigger className="flex items-center justify-between w-full py-2 font-semibold">
          Price Range
          <Icon name={openSections.price ? "angle-small-up" : "angle-small-down"} />
        </CollapsibleTrigger>
        <CollapsibleContent className="pt-4 space-y-4">
          <Slider
            value={filters.priceRange}
            min={0}
            max={5000}
            step={100}
            onValueChange={(value) => onChange({ ...filters, priceRange: value as [number, number] })}
            className="w-full"
          />
          <div className="flex items-center justify-between text-sm">
            <span className="text-muted-foreground">{formatPrice(filters.priceRange[0])}</span>
            <span className="text-muted-foreground">{formatPrice(filters.priceRange[1])}</span>
          </div>
        </CollapsibleContent>
      </Collapsible>
    </div>
  )
}
