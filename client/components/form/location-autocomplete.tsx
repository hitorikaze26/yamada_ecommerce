"use client"

import { useState, useRef, useEffect, useCallback } from "react"
import { shippingApi, type AutocompleteResult } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

interface LocationAutocompleteProps {
  onSelect: (result: AutocompleteResult) => void
  placeholder?: string
  className?: string
}

export function LocationAutocomplete({
  onSelect,
  placeholder = "Search for a location…",
  className = "",
}: LocationAutocompleteProps) {
  const [query, setQuery] = useState("")
  const [results, setResults] = useState<AutocompleteResult[]>([])
  const [loading, setLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [selectedLabel, setSelectedLabel] = useState("")
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const inputRef = useRef<HTMLInputElement>(null)
  const dropdownRef = useRef<HTMLDivElement>(null)

  const doSearch = useCallback(async (q: string) => {
    if (q.trim().length < 3) {
      setResults([])
      setOpen(false)
      return
    }
    setLoading(true)
    try {
      const res = await shippingApi.autocomplete(q)
      setResults(res.data.results ?? [])
      setOpen(res.data.results?.length > 0)
    } catch {
      setResults([])
      setOpen(false)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => doSearch(query), 300)
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [query, doSearch])

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(e.target as Node) &&
        inputRef.current &&
        !inputRef.current.contains(e.target as Node)
      ) {
        setOpen(false)
      }
    }
    document.addEventListener("mousedown", handleClick)
    return () => document.removeEventListener("mousedown", handleClick)
  }, [])

  const handleSelect = (result: AutocompleteResult) => {
    setSelectedLabel(result.label)
    setQuery("")
    setResults([])
    setOpen(false)
    onSelect(result)
  }

  return (
    <div className={`relative ${className}`}>
      <div className="relative">
        <Icon
          name="search"
          className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none"
          size="sm"
        />
        <input
          ref={inputRef}
          type="text"
          value={open ? query : selectedLabel || query}
          onChange={(e) => {
            setQuery(e.target.value)
            setSelectedLabel("")
          }}
          onFocus={() => {
            if (results.length > 0) setOpen(true)
          }}
          placeholder={placeholder}
          className="w-full pl-9 pr-4 py-2 border rounded-xl text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary/30"
        />
        {loading && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2">
            <div className="w-4 h-4 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        )}
      </div>
      {open && results.length > 0 && (
        <div
          ref={dropdownRef}
          className="absolute z-50 mt-1 w-full bg-card border rounded-xl shadow-lg overflow-hidden max-h-64 overflow-y-auto"
        >
          {results.map((r, i) => (
            <button
              key={`${r.osmId}-${i}`}
              type="button"
              onClick={() => handleSelect(r)}
              className="w-full text-left px-4 py-3 text-sm hover:bg-muted transition-colors border-b last:border-b-0"
            >
              <span className="font-medium">{r.label}</span>
              {r.type && (
                <span className="ml-2 text-xs text-muted-foreground capitalize">({r.type})</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
