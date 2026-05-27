"use client"

import { useState, useCallback, useRef } from "react"
import axios from "axios"
import type { AxiosResponse, AxiosError } from "axios"
import { invalidateQuery } from "./use-query"

interface MutationState<T> {
  data: T | null
  isPending: boolean
  error: Error | null
}

interface MutationOptions<TData, TVariables> {
  onMutate?: (variables: TVariables) => void
  onSuccess?: (data: TData, variables: TVariables) => void
  onError?: (error: Error, variables: TVariables) => void
  onSettled?: (data: TData | null, error: Error | null, variables: TVariables) => void
  /** Invalidate query keys after success */
  invalidateKeys?: string[]
}

type MutationFetcher<TData, TVariables> = (
  variables: TVariables,
  signal?: AbortSignal,
) => Promise<AxiosResponse<TData>>

export function useMutation<TData = unknown, TVariables = void>(
  fetcher: MutationFetcher<TData, TVariables>,
  options: MutationOptions<TData, TVariables> = {},
) {
  const { onMutate, onSuccess, onError, onSettled, invalidateKeys } = options
  const [state, setState] = useState<MutationState<TData>>({
    data: null,
    isPending: false,
    error: null,
  })
  const mountedRef = useRef(true)
  const abortRef = useRef<AbortController | null>(null)

  const mutate = useCallback(
    async (variables: TVariables) => {
      abortRef.current?.abort()
      const controller = new AbortController()
      abortRef.current = controller

      setState({ data: null, isPending: true, error: null })
      onMutate?.(variables)

      try {
        const response = await fetcher(variables, controller.signal)
        const data = response.data as TData
        if (mountedRef.current) {
          setState({ data, isPending: false, error: null })
          onSuccess?.(data, variables)
        }
        if (invalidateKeys) {
          invalidateKeys.forEach(invalidateQuery)
        }
        onSettled?.(data, null, variables)
        return data
      } catch (err) {
        if (axios.isCancel(err) || (err as Error)?.name === "AbortError") return
        const errorObj = err instanceof Error ? err : new Error("Request failed")
        if (mountedRef.current) {
          setState({ data: null, isPending: false, error: errorObj })
          onError?.(errorObj, variables)
        }
        onSettled?.(null, errorObj, variables)
        throw errorObj
      }
    },
    [fetcher, onMutate, onSuccess, onError, onSettled, invalidateKeys],
  )

  const reset = useCallback(() => {
    setState({ data: null, isPending: false, error: null })
  }, [])

  return { ...state, mutate, reset }
}
