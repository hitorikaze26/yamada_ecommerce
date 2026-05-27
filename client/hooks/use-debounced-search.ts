"use client"

import { useState, useEffect, useCallback, useRef } from "react"

export function useDebouncedSearch<T>(searchFn: (query: string, signal?: AbortSignal) => Promise<T>, delay = 300) {
  const [query, setQuery] = useState("")
  const [debouncedQuery, setDebouncedQuery] = useState("")
  const [results, setResults] = useState<T | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<Error | null>(null)
  const abortRef = useRef<AbortController | null>(null)

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

    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller
    let cancelled = false

    const search = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const data = await searchFn(debouncedQuery, controller.signal)
        if (!cancelled && !controller.signal.aborted) {
          setResults(data)
        }
      } catch (err) {
        if (cancelled || (err as Error)?.name === "AbortError") return
        if (!cancelled) {
          setError(err as Error)
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false)
        }
      }
    }

    search()

    return () => {
      cancelled = true
      controller.abort()
    }
  }, [debouncedQuery, searchFn])

  const clearSearch = useCallback(() => {
    abortRef.current?.abort()
    setQuery("")
    setDebouncedQuery("")
    setResults(null)
    setError(null)
    setIsLoading(false)
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
