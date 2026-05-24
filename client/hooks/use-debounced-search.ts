"use client"

import { useState, useEffect, useCallback } from "react"

export function useDebouncedSearch<T>(searchFn: (query: string) => Promise<T>, delay = 300) {
  const [query, setQuery] = useState("")
  const [debouncedQuery, setDebouncedQuery] = useState("")
  const [results, setResults] = useState<T | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)

  // Debounce the query
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(query)
    }, delay)

    return () => clearTimeout(timer)
  }, [query, delay])

  // Execute search when debounced query changes
  useEffect(() => {
    if (!debouncedQuery) {
      setResults(null)
      return
    }

    const search = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const data = await searchFn(debouncedQuery)
        setResults(data)
      } catch (err) {
        setError(err as Error)
      } finally {
        setIsLoading(false)
      }
    }

    search()
  }, [debouncedQuery, searchFn])

  const clearSearch = useCallback(() => {
    setQuery("")
    setDebouncedQuery("")
    setResults(null)
    setError(null)
  }, [])

  return {
    query,
    setQuery,
    results,
    isLoading,
    error,
    clearSearch,
  }
}
