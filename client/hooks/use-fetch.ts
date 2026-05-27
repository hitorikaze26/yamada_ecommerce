"use client"

import { useState, useEffect, useCallback, useRef } from "react"
import type { AxiosResponse, AxiosError } from "axios"
import axios from "axios"

interface UseFetchState<T> {
  data: T | null
  isLoading: boolean
  error: Error | null
}

interface UseFetchOptions {
  immediate?: boolean
  onSuccess?: (data: unknown) => void
  onError?: (error: Error) => void
}

type Fetcher<T> = (signal?: AbortSignal) => Promise<AxiosResponse<T>>

export function useFetch<T>(
  fetcher: Fetcher<T>,
  dependencies: unknown[] = [],
  options: UseFetchOptions = {},
) {
  const { immediate = true, onSuccess, onError } = options
  const [state, setState] = useState<UseFetchState<T>>({
    data: null,
    isLoading: immediate,
    error: null,
  })
  const mountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const execute = useCallback(async () => {
    abortRef.current?.abort()
    const controller = new AbortController()
    abortRef.current = controller

    if (!mountedRef.current) return
    setState(prev => ({ ...prev, isLoading: true, error: null }))

    try {
      const response = await fetcher(controller.signal)
      if (mountedRef.current && !controller.signal.aborted) {
        setState({ data: response.data, isLoading: false, error: null })
        onSuccess?.(response.data)
      }
      return response.data
    } catch (err) {
      if (axios.isCancel(err) || (err as Error)?.name === "AbortError") return
      if (!mountedRef.current) return
      const error = err as AxiosError
      const errorObj = new Error(error.message || "An error occurred")
      setState({ data: null, isLoading: false, error: errorObj })
      onError?.(errorObj)
      throw err
    }
  }, [fetcher, onSuccess, onError])

  useEffect(() => {
    mountedRef.current = true
    if (immediate) {
      execute()
    }
    return () => {
      mountedRef.current = false
      abortRef.current?.abort()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, dependencies)

  const refetch = useCallback(() => execute(), [execute])

  return { ...state, refetch, execute }
}
