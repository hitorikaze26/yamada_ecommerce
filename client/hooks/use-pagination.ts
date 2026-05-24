"use client"

import { useState, useCallback, useMemo } from "react"

interface UsePaginationOptions {
  initialPage?: number
  initialLimit?: number
  totalItems?: number
}

export function usePagination({ initialPage = 1, initialLimit = 12, totalItems = 0 }: UsePaginationOptions = {}) {
  const [page, setPage] = useState(initialPage)
  const [limit, setLimit] = useState(initialLimit)
  const [total, setTotal] = useState(totalItems)

  const totalPages = useMemo(() => Math.ceil(total / limit) || 1, [total, limit])

  const goToPage = useCallback(
    (newPage: number) => {
      setPage(Math.max(1, Math.min(newPage, totalPages)))
    },
    [totalPages],
  )

  const nextPage = useCallback(() => {
    goToPage(page + 1)
  }, [page, goToPage])

  const prevPage = useCallback(() => {
    goToPage(page - 1)
  }, [page, goToPage])

  const setTotalItems = useCallback((newTotal: number) => {
    setTotal(newTotal)
  }, [])

  const resetPagination = useCallback(() => {
    setPage(initialPage)
  }, [initialPage])

  return {
    page,
    limit,
    total,
    totalPages,
    goToPage,
    nextPage,
    prevPage,
    setLimit,
    setTotalItems,
    resetPagination,
    hasNextPage: page < totalPages,
    hasPrevPage: page > 1,
    offset: (page - 1) * limit,
  }
}
