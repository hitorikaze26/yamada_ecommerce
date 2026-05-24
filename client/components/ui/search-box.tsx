"use client"

import type React from "react"

import { useState, useRef, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Input } from "@/components/ui/input"

interface SearchBoxProps {
  onSearch: (query: string) => void
  placeholder?: string
}

// Mock suggestions - in production, fetch from API
const mockSuggestions = ["Summer dresses", "Yoga pants", "Blouse collection", "Evening gowns", "Casual tops"]

export function SearchBox({ onSearch, placeholder = "Search products..." }: SearchBoxProps) {
  const [isFocused, setIsFocused] = useState(false)
  const [localQuery, setLocalQuery] = useState("")
  const inputRef = useRef<HTMLInputElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)

  const suggestions = localQuery
    ? mockSuggestions.filter((s) => s.toLowerCase().includes(localQuery.toLowerCase()))
    : mockSuggestions.slice(0, 3)

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsFocused(false)
      }
    }
    document.addEventListener("mousedown", handleClickOutside)
    return () => document.removeEventListener("mousedown", handleClickOutside)
  }, [])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (localQuery.trim()) {
      onSearch(localQuery.trim())
      setIsFocused(false)
    }
  }

  const handleSuggestionClick = (suggestion: string) => {
    setLocalQuery(suggestion)
    onSearch(suggestion)
    setIsFocused(false)
  }

  return (
    <div ref={containerRef} className="relative w-full">
      <form onSubmit={handleSubmit}>
        <div className="relative">
          <Icon name="search" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <Input
            ref={inputRef}
            type="search"
            placeholder={placeholder}
            value={localQuery}
            onChange={(e) => setLocalQuery(e.target.value)}
            onFocus={() => setIsFocused(true)}
            className="pl-10 pr-4 bg-muted/50 border-0 focus:bg-background focus:ring-2 focus:ring-primary/20"
          />
        </div>
      </form>

      <AnimatePresence>
        {isFocused && suggestions.length > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="absolute top-full left-0 right-0 mt-2 bg-popover border rounded-lg shadow-lg overflow-hidden z-50"
          >
            <div className="p-2">
              <p className="text-xs text-muted-foreground px-2 py-1">
                {localQuery ? "Suggestions" : "Popular searches"}
              </p>
              {suggestions.map((suggestion, index) => (
                <button
                  key={index}
                  onClick={() => handleSuggestionClick(suggestion)}
                  className="w-full text-left px-2 py-2 text-sm hover:bg-muted rounded-md flex items-center gap-2 transition-colors"
                >
                  <Icon name="search" size="sm" className="text-muted-foreground" />
                  {suggestion}
                </button>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
