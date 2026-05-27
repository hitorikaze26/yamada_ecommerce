"use client"

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react"
import { buyerApi } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import type { Product } from "@/lib/types"
import { useAuth } from "@/context/auth-context"

interface WishlistContextType {
  items: Product[]
  productIds: Set<number>
  isLoading: boolean
  error: string | null
  isWishlisted: (productId: number | string) => boolean
  fetchWishlist: () => Promise<void>
  toggleWishlist: (product: Product) => Promise<boolean>
  removeFromWishlist: (productId: number | string) => Promise<void>
  clear: () => void
}

const WishlistContext = createContext<WishlistContextType | undefined>(undefined)

function toProductId(productId: number | string): number | null {
  const n = Number(productId)
  return Number.isFinite(n) ? n : null
}

export function WishlistProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, getRole, user } = useAuth()
  const role = user?.role ?? getRole()
  const [items, setItems] = useState<Product[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const productIds = useMemo(() => {
    const set = new Set<number>()
    for (const item of items) {
      const id = toProductId(item.id)
      if (id != null) set.add(id)
    }
    return set
  }, [items])

  const clear = useCallback(() => {
    setItems([])
    setError(null)
  }, [])

  const fetchWishlist = useCallback(async () => {
    if (!isAuthenticated || role !== "buyer") {
      clear()
      return
    }
    setIsLoading(true)
    setError(null)
    try {
      const res = await buyerApi.getWishlist()
      const products = unwrapBuyerList<Product>(res.data, ["products"])
      setItems(products)
    } catch (e) {
      console.error(e)
      setError(getBuyerFetchError(e, "Failed to load wishlist"))
    } finally {
      setIsLoading(false)
    }
  }, [isAuthenticated, role, clear])

  useEffect(() => {
    let cancelled = false
    if (isAuthenticated && role === "buyer") {
      void fetchWishlist().then(() => { if (cancelled) clear() })
    } else {
      clear()
    }
    return () => { cancelled = true }
  }, [isAuthenticated, role, user?.id, fetchWishlist, clear])

  const isWishlisted = useCallback(
    (productId: number | string) => {
      const id = toProductId(productId)
      return id != null && productIds.has(id)
    },
    [productIds],
  )

  const removeFromWishlist = useCallback(
    async (productId: number | string) => {
      const id = toProductId(productId)
      if (id == null) return
      const previous = items
      setItems((prev) => prev.filter((p) => toProductId(p.id) !== id))
      try {
        await buyerApi.removeFromWishlist(id)
      } catch (e) {
        setItems(previous)
        throw e
      }
    },
    [items],
  )

  const toggleWishlist = useCallback(
    async (product: Product): Promise<boolean> => {
      const id = toProductId(product.id)
      if (id == null) return false

      if (isWishlisted(id)) {
        await removeFromWishlist(id)
        return false
      }

      const previous = items
      setItems((prev) => [...prev, product])
      try {
        await buyerApi.addToWishlist(id)
        return true
      } catch (e) {
        setItems(previous)
        throw e
      }
    },
    [items, isWishlisted, removeFromWishlist],
  )

  return (
    <WishlistContext.Provider
      value={{
        items,
        productIds,
        isLoading,
        error,
        isWishlisted,
        fetchWishlist,
        toggleWishlist,
        removeFromWishlist,
        clear,
      }}
    >
      {children}
    </WishlistContext.Provider>
  )
}

export function useWishlist() {
  const context = useContext(WishlistContext)
  if (!context) {
    throw new Error("useWishlist must be used within a WishlistProvider")
  }
  return context
}
