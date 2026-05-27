"use client"

import { useState, useEffect, useCallback, useRef } from "react"
import axios from "axios"
import type { AxiosResponse, AxiosError } from "axios"

type QueryKey = string

interface QueryState<T> {
  data: T | null
  isLoading: boolean
  isStale: boolean
  error: Error | null
  isCached: boolean
}

interface QueryOptions<T> {
  enabled?: boolean
  staleTime?: number
  retry?: number
  retryDelay?: number
  onSuccess?: (data: T) => void
  onError?: (error: Error) => void
  /** Compare function for deduplication (default: strict equality on key) */
  dedupKey?: string
}

interface CacheEntry<T> {
  data: T
  timestamp: number
  promise?: Promise<T>
}

const queryCache = new Map<string, CacheEntry<unknown>>()
const inflightRequests = new Map<string, Promise<unknown>>()

function getCached<T>(key: string): CacheEntry<T> | undefined {
  return queryCache.get(key) as CacheEntry<T> | undefined
}

function setCache<T>(key: string, data: T): void {
  queryCache.set(key, { data, timestamp: Date.now() })
}

type QueryFetcher<T> = (signal?: AbortSignal) => Promise<AxiosResponse<T>>

const DEFAULT_RETRIES = 2
const DEFAULT_RETRY_DELAY = 1000

async function executeWithRetry<T>(
  fetcher: QueryFetcher<T>,
  retries: number,
  delay: number,
  signal?: AbortSignal,
): Promise<T> {
  let lastError: Error | undefined
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      if (signal?.aborted) throw new DOMException("Aborted", "AbortError")
      const response = await fetcher(signal)
      return response.data as T
    } catch (err) {
      if (axios.isCancel(err) || (err as Error)?.name === "AbortError") throw err
      lastError = err as Error
      if (attempt < retries) {
        await new Promise(r => setTimeout(r, delay * Math.pow(2, attempt)))
      }
    }
  }
  throw lastError ?? new Error("Request failed")
}

export function useQuery<T>(
  key: QueryKey,
  fetcher: QueryFetcher<T>,
  options: QueryOptions<T> = {},
) {
  const {
    enabled = true,
    staleTime = 0,
    retry = DEFAULT_RETRIES,
    retryDelay = DEFAULT_RETRY_DELAY,
    onSuccess,
    onError,
  } = options

  const cached = getCached<T>(key)
  const isStale = cached ? Date.now() - cached.timestamp > staleTime : true

  const [state, setState] = useState<QueryState<T>>({
    data: cached?.data ?? null,
    isLoading: enabled && (!cached || isStale),
    isStale: isStale && !!cached,
    error: null,
    isCached: !!cached,
  })

  const mountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const execute = useCallback(async () => {
    if (!enabled) return

    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller

    if (!mountedRef.current) return
    setState(prev => ({ ...prev, isLoading: true, error: null }))

    const dedupKey = options.dedupKey ?? key
    const inflight = inflightRequests.get(dedupKey)
    if (inflight) {
      try {
        const data = await inflight
        if (mountedRef.current) {
          setState({ data: data as T, isLoading: false, isStale: false, error: null, isCached: true })
          onSuccess?.(data as T)
        }
      } catch {
        // fall through to re-fetch
      }
      return
    }

    const promise = executeWithRetry(fetcher, retry, retryDelay, controller.signal)
    inflightRequests.set(dedupKey, promise)

    try {
      const data = await promise
      setCache(key, data)
      if (mountedRef.current && !controller.signal.aborted) {
        setState({ data, isLoading: false, isStale: false, error: null, isCached: false })
        onSuccess?.(data)
      }
    } catch (err) {
      if (axios.isCancel(err) || (err as Error)?.name === "AbortError") return
      if (!mountedRef.current) return
      const errorObj = err instanceof Error ? err : new Error("Request failed")
      setState(prev => ({ ...prev, isLoading: false, error: errorObj }))
      onError?.(errorObj)
    } finally {
      inflightRequests.delete(dedupKey)
    }
  }, [key, fetcher, enabled, retry, retryDelay, onSuccess, onError, options.dedupKey])

  useEffect(() => {
    mountedRef.current = true
    if (enabled && (!cached || isStale)) {
      execute()
    }
    return () => {
      mountedRef.current = false
      abortRef.current?.abort()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, enabled])

  const refetch = useCallback(() => execute(), [execute])
  const invalidateCache = useCallback(() => {
    queryCache.delete(key)
  }, [key])

  return { ...state, refetch, execute, invalidateCache }
}

export function invalidateQuery(key: string): void {
  queryCache.delete(key)
}

export function clearQueryCache(): void {
  queryCache.clear()
}
