"use client"

import { useState, useEffect, useCallback } from "react"
import type { AxiosResponse, AxiosError, CancelTokenSource } from "axios"
import { createCancelToken } from "@/lib/api"

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

export function useFetch<T>(
  fetcher: (cancelToken?: CancelTokenSource) => Promise<AxiosResponse<T>>,
  dependencies: unknown[] = [],
  options: UseFetchOptions = {},
) {
  const { immediate = true, onSuccess, onError } = options

  const [state, setState] = useState<UseFetchState<T>>({
    data: null,
    isLoading: immediate,
    error: null,
  })

  const execute = useCallback(async () => {
    const cancelToken = createCancelToken()
    setState((prev) => ({ ...prev, isLoading: true, error: null }))

    try {
      const response = await fetcher(cancelToken)
      setState({ data: response.data, isLoading: false, error: null })
      onSuccess?.(response.data)
      return response.data
    } catch (err) {
      const error = err as AxiosError
      if (!error.message?.includes("canceled")) {
        const errorObj = new Error(error.message || "An error occurred")
        setState({ data: null, isLoading: false, error: errorObj })
        onError?.(errorObj)
      }
      throw err
    }
  }, [fetcher, onSuccess, onError])

  useEffect(() => {
    if (immediate) {
      execute()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, dependencies)

  const refetch = useCallback(() => execute(), [execute])

  return { ...state, refetch, execute }
}
