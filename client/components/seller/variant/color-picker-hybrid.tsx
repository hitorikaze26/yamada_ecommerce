"use client"

import { useState, useRef, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { ColorSwatch } from "@/components/ui/color-swatch"
import { COLOR_PRESET_GRID, PRESET_COLORS, type ColorOption } from "@/data/colors"

interface ColorPickerHybridProps {
  selected: ColorOption[]
  onChange: (colors: ColorOption[]) => void
  max?: number
}

const HEX_REGEX = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/

export function ColorPickerHybrid({
  selected,
  onChange,
  max = 10,
}: ColorPickerHybridProps) {
  const [showDropdown, setShowDropdown] = useState(false)
  const [hexInput, setHexInput] = useState("")
  const [hexError, setHexError] = useState("")
  const dropdownRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setShowDropdown(false)
      }
    }
    document.addEventListener("mousedown", handleClickOutside)
    return () => document.removeEventListener("mousedown", handleClickOutside)
  }, [])

  const isSelected = (color: ColorOption) =>
    selected.some((s) => s.hex === color.hex && s.name === color.name)

  const togglePreset = (color: ColorOption) => {
    if (isSelected(color)) {
      onChange(selected.filter((s) => !(s.hex === color.hex && s.name === color.name)))
    } else {
      if (selected.length >= max) return
      onChange([...selected, color])
    }
  }

  const addFromDropdown = (color: ColorOption) => {
    if (selected.length >= max) return
    if (!isSelected(color)) {
      onChange([...selected, color])
    }
    setShowDropdown(false)
  }

  const handleAddHex = () => {
    const raw = hexInput.trim()
    if (!raw) return

    const normalized = raw.startsWith("#") ? raw : `#${raw}`
    if (!HEX_REGEX.test(normalized)) {
      setHexError("Invalid hex code (e.g. #FF0000)")
      return
    }

    if (selected.length >= max) return

    const newColor: ColorOption = { name: normalized, hex: normalized.toUpperCase() }
    if (!isSelected(newColor)) {
      onChange([...selected, newColor])
    }
    setHexInput("")
    setHexError("")
  }

  const removeColor = (color: ColorOption) => {
    onChange(selected.filter((s) => !(s.hex === color.hex && s.name === color.name)))
  }

  return (
    <div className="space-y-3">
      {/* Selected colors display */}
      {selected.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {selected.map((color) => (
            <div
              key={`${color.name}-${color.hex}`}
              className="group relative flex items-center gap-2 rounded-full bg-muted pl-1 pr-2 py-1 text-sm border"
            >
              <ColorSwatch hex={color.hex} name={color.name} size="sm" />
              <span className="text-xs font-medium">{color.name}</span>
              <button
                type="button"
                onClick={() => removeColor(color)}
                className="ml-1 text-muted-foreground hover:text-foreground transition-colors"
              >
                <Icon name="times" size="sm" />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Quick preset grid */}
      <div>
        <label className="block text-xs font-medium text-muted-foreground mb-2">
          Quick colors
        </label>
        <div className="flex flex-wrap gap-2">
          {COLOR_PRESET_GRID.map((color) => (
            <ColorSwatch
              key={color.hex}
              hex={color.hex}
              name={color.name}
              size="md"
              selected={isSelected(color)}
              onClick={() => togglePreset(color)}
            />
          ))}
        </div>
      </div>

      {/* Bottom row: dropdown + hex input */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative" ref={dropdownRef}>
          <button
            type="button"
            onClick={() => setShowDropdown(!showDropdown)}
            className="flex items-center gap-2 px-3 py-1.5 rounded-lg border bg-background text-sm hover:bg-muted transition-colors"
          >
            <Icon name="chevron-down" size="sm" />
            More colors
          </button>
          {showDropdown && (
            <div className="absolute left-0 top-full mt-1 z-50 w-56 max-h-60 overflow-y-auto rounded-xl border bg-popover p-2 shadow-lg">
              {PRESET_COLORS.map((color) => {
                const active = isSelected(color)
                return (
                  <button
                    key={color.hex}
                    type="button"
                    disabled={active}
                    onClick={() => addFromDropdown(color)}
                    className={`flex w-full items-center gap-3 px-2 py-1.5 rounded-lg text-sm transition-colors ${
                      active
                        ? "bg-muted text-muted-foreground cursor-not-allowed"
                        : "hover:bg-muted cursor-pointer"
                    }`}
                  >
                    <ColorSwatch hex={color.hex} size="sm" />
                    <span className="flex-1 text-left">{color.name}</span>
                    <span className="text-xs text-muted-foreground">{color.hex}</span>
                    {active && <Icon name="check" size="sm" className="text-primary" />}
                  </button>
                )
              })}
            </div>
          )}
        </div>

        <div className="flex items-center gap-1">
          <span className="text-muted-foreground text-sm">#</span>
          <input
            type="text"
            value={hexInput}
            onChange={(e) => {
              setHexInput(e.target.value)
              setHexError("")
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleAddHex()
            }}
            placeholder="FF0000"
            maxLength={6}
            className="w-20 px-2 py-1.5 rounded-lg border bg-background text-sm font-mono focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
          />
          <button
            type="button"
            onClick={handleAddHex}
            disabled={!hexInput.trim() || selected.length >= max}
            className="px-2 py-1.5 rounded-lg bg-primary text-primary-foreground text-xs font-medium disabled:opacity-50"
          >
            Add
          </button>
        </div>

        {selected.length >= max && (
          <span className="text-xs text-muted-foreground">Max {max} colors</span>
        )}
      </div>

      {hexError && <p className="text-xs text-destructive">{hexError}</p>}
    </div>
  )
}
