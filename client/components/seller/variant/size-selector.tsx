"use client"

import { Icon } from "@/components/ui/icon"

interface SizeSelectorProps {
  options: string[]
  selected: string[]
  onChange: (sizes: string[]) => void
}

export function SizeSelector({ options, selected, onChange }: SizeSelectorProps) {
  const toggle = (size: string) => {
    if (selected.includes(size)) {
      onChange(selected.filter((s) => s !== size))
    } else {
      onChange([...selected, size])
    }
  }

  const selectAll = () => onChange([...options])
  const clearAll = () => onChange([])

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-muted-foreground">Available sizes</span>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={selectAll}
            className="text-xs text-primary hover:underline"
          >
            Select all
          </button>
          <button
            type="button"
            onClick={clearAll}
            className="text-xs text-muted-foreground hover:underline"
          >
            Clear
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {options.map((size) => {
          const isSelected = selected.includes(size)
          return (
            <button
              key={size}
              type="button"
              onClick={() => toggle(size)}
              className={`
                px-4 py-2 rounded-lg text-sm font-medium border transition-all duration-150
                ${
                  isSelected
                    ? "bg-primary text-primary-foreground border-primary shadow-sm"
                    : "bg-background text-foreground border-border hover:border-primary/50 hover:bg-muted"
                }
              `}
            >
              {size}
            </button>
          )
        })}
      </div>

      {selected.length > 0 && (
        <p className="text-xs text-muted-foreground">
          <Icon name="check" size="sm" className="inline mr-1" />
          {selected.length} size{selected.length > 1 ? "s" : ""} selected
        </p>
      )}
    </div>
  )
}
