"use client"

import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from "react"
import { useAuth } from "./auth-context"
import { cartApi, resolveImageUrl, buyerApi, shippingApi } from "@/lib/api"
import type { Cart, CartItem, Product, ProductVariation } from "@/lib/types"
import { getCartShippingEstimate, FREE_SHIPPING_THRESHOLD, FALLBACK_SHIPPING_FEE, type ShippingCalculation } from "@/lib/shipping"
import { assertNotOwnStoreProduct } from "@/lib/seller-store-guard"
import { toast } from "sonner"

interface CartContextType {
  cart: Cart
  isLoading: boolean
  addToCart: (product: Product, quantity: number, variation: ProductVariation) => void
  updateQuantity: (itemId: string, quantity: number) => void
  removeFromCart: (itemId: string) => void
  removeItemsByIds: (itemIds: string[]) => void
  clearCart: () => void
  itemCount: number
  shippingCalculation: ShippingCalculation | null
  shippingBySeller: Record<string, ShippingCalculation>
  isCalculatingShipping: boolean
  updateShippingEstimate: () => void
  calculateShippingForItems: (itemIds: string[]) => Promise<Record<string, ShippingCalculation>>
  calculateShippingForCheckoutItems: (items: CartItem[]) => Promise<Record<string, ShippingCalculation>>
}

const CartContext = createContext<CartContextType | undefined>(undefined)

/** True when id is a database cart_items.id (not a client-side temp id). */
function isBackendCartItemId(id: string): boolean {
  return /^\d+$/.test(id)
}

function parseBackendCartItemId(id: string): number | null {
  if (!isBackendCartItemId(id)) return null
  const n = Number(id)
  return Number.isFinite(n) ? n : null
}

// Calculate totals with estimated shipping
const calculateTotals = (items: CartItem[], shippingCalculation: ShippingCalculation | null): Pick<Cart, "subtotal" | "shipping" | "total"> => {
  const subtotal = items.reduce((sum, item) => {
    const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
    return sum + price * item.quantity
  }, 0)

  const shipping = shippingCalculation?.fee ?? 0
  const total = subtotal + shipping

  return { subtotal, shipping, total }
}

export function CartProvider({ children }: { children: ReactNode }) {
  const { user, isAuthenticated } = useAuth()

  const [cart, setCart] = useState<Cart>({
    items: [],
    subtotal: 0,
    shipping: 0,
    total: 0,
  })
  const [isLoading, setIsLoading] = useState(true)
  const [shippingCalculation, setShippingCalculation] = useState<ShippingCalculation | null>(null)
  const [shippingBySeller, setShippingBySeller] = useState<Record<string, ShippingCalculation>>({})
  const [isCalculatingShipping, setIsCalculatingShipping] = useState(false)
  const [buyerAddress, setBuyerAddress] = useState<any>(null)

  // Normalize product image URLs coming from the backend so Next/Image
  // can resolve them correctly (backend may return relative "/static/..." paths
  // or a single `image_url` field).
  const normalizeProduct = (p: any): Product => {
    const prod = { ...p } as any
    const imagesFromArray = Array.isArray(prod.images) ? prod.images : []
    const rawSingle = prod.image_url ?? prod.imageUrl ?? prod.imageURL ?? prod.image

    const normalizedImages: string[] = []
    if (rawSingle) {
      const resolved = resolveImageUrl(String(rawSingle))
      if (resolved) normalizedImages.push(resolved)
    }

    imagesFromArray.forEach((img: any) => {
      const resolved = resolveImageUrl(String(img))
      if (resolved) normalizedImages.push(resolved)
    })

    prod.images = normalizedImages
    return prod as Product
  }

  const mapBackendCartItem = useCallback(
    (item: {
      id: number
      sellerId?: number
      sellerName?: string
      product?: Record<string, unknown>
      quantity: number
      variation?: ProductVariation
    }): CartItem => ({
      id: String(item.id),
      product: {
        ...normalizeProduct(item.product),
        sellerId: item.sellerId?.toString() || (item.product?.storeId as number | undefined)?.toString() || "",
        sellerName: item.sellerName || (item.product?.sellerName as string | undefined) || "Unknown Seller",
      },
      quantity: item.quantity,
      selectedVariation: item.variation as ProductVariation,
    }),
    [],
  )

  const applyCartFromBackend = useCallback(
    (backendCart: { items?: unknown[] } | null | undefined) => {
      const items = (backendCart?.items ?? []).map((item) => mapBackendCartItem(item as Parameters<typeof mapBackendCartItem>[0]))
      const initialShipping = getCartShippingEstimate(
        items.reduce((sum, item) => {
          const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
          return sum + price * item.quantity
        }, 0),
      )
      setShippingCalculation(initialShipping)
      setCart({ items, ...calculateTotals(items, initialShipping) })
    },
    [mapBackendCartItem],
  )

  const reloadCartFromBackend = useCallback(async () => {
    const response = await cartApi.get()
    applyCartFromBackend(response.data?.cart)
  }, [applyCartFromBackend])

  // Update shipping estimate based on cart total
  const updateShippingEstimate = () => {
    const subtotal = cart.items.reduce((sum, item) => {
      const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
      return sum + price * item.quantity
    }, 0)

    const calculation = getCartShippingEstimate(subtotal)
    setShippingCalculation(calculation)
    
    // Update cart totals
    setCart(prev => ({
      ...prev,
      ...calculateTotals(prev.items, calculation)
    }))
  }

  // Load cart from backend when user authenticates
  useEffect(() => {
    const loadCart = async () => {
      try {
        if (isAuthenticated && user) {
          // Fetch cart from backend
          const response = await cartApi.get()
          const backendCart = response.data?.cart
          
          if (backendCart && backendCart.items) {
            applyCartFromBackend(backendCart)
          } else {
            setCart({ items: [], subtotal: 0, shipping: 0, total: 0 })
            setShippingCalculation(null)
          }
        } else {
          // Not authenticated - reset cart
          setCart({ items: [], subtotal: 0, shipping: 0, total: 0 })
          setShippingCalculation(null)
        }
      } catch (error) {
        console.error("Failed to load cart:", error)
        setCart({ items: [], subtotal: 0, shipping: 0, total: 0 })
        setShippingCalculation(null)
      } finally {
        setIsLoading(false)
      }
    }

    loadCart()
  }, [isAuthenticated, user, applyCartFromBackend])

  // Fetch buyer address for shipping calculation
  useEffect(() => {
    const fetchBuyerAddress = async () => {
      if (!isAuthenticated || !user) return
      try {
        const response = await buyerApi.getProfile()
        const profile = response.data?.profile || response.data
        setBuyerAddress(profile?.address || null)
      } catch (error) {
        console.error('Failed to fetch buyer address:', error)
        setBuyerAddress(null)
      }
    }
    fetchBuyerAddress()
  }, [isAuthenticated, user])

  const computeShippingForItemList = useCallback(async (items: CartItem[]): Promise<Record<string, ShippingCalculation>> => {
    if (items.length === 0) return {}

    setIsCalculatingShipping(true)
    
    // Group items by seller
    const itemsBySeller = items.reduce((acc, item) => {
      const sellerId = item.product.sellerId || 'unknown'
      if (!acc[sellerId]) acc[sellerId] = []
      acc[sellerId].push(item)
      return acc
    }, {} as Record<string, CartItem[]>)

    const shippingMap: Record<string, ShippingCalculation> = {}

    for (const [sellerId, sellerItems] of Object.entries(itemsBySeller)) {
      const subtotal = sellerItems.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)

      const shopId = parseInt(sellerId)
      if (isNaN(shopId) || shopId <= 0) {
        const isFree = subtotal >= FREE_SHIPPING_THRESHOLD
        shippingMap[sellerId] = {
          fee: isFree ? 0 : FALLBACK_SHIPPING_FEE,
          isFree,
          isEstimated: true,
          note: isFree ? `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD}` : 'Shipping calculated at checkout'
        }
        continue
      }

      let calculation: ShippingCalculation
      
      if (buyerAddress) {
        try {
          const response = await shippingApi.calculateFee({
            shop_id: shopId,
            order_total: subtotal,
            buyer_region_code: buyerAddress.regionCode,
            buyer_province_code: buyerAddress.provinceCode,
            buyer_municipality_code: buyerAddress.municipalityCode
          })
          
          const backendResult = response.data
          calculation = {
            fee: backendResult.shipping_fee ?? FALLBACK_SHIPPING_FEE,
            isFree: backendResult.free_shipping ?? false,
            isEstimated: false,
            note: backendResult.note ?? 'Shipping fee calculated'
          }
        } catch (error) {
          const isFree = subtotal >= FREE_SHIPPING_THRESHOLD
          calculation = {
            fee: isFree ? 0 : FALLBACK_SHIPPING_FEE,
            isFree,
            isEstimated: true,
            note: isFree ? `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD}` : 'Shipping calculated at checkout'
          }
        }
      } else {
        const isFree = subtotal >= FREE_SHIPPING_THRESHOLD
        calculation = {
          fee: isFree ? 0 : FALLBACK_SHIPPING_FEE,
          isFree,
          isEstimated: true,
          note: isFree ? `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD}` : 'Shipping calculated at checkout'
        }
      }

      shippingMap[sellerId] = calculation
    }

    setShippingBySeller(shippingMap)
    
    // Update total shipping calculation
    const totalFee = Object.values(shippingMap).reduce((sum, calc) => sum + calc.fee, 0)
    const isFree = totalFee === 0 && Object.values(shippingMap).every(c => c.isFree)
    const isEstimated = Object.values(shippingMap).some(c => c.isEstimated)
    
    setShippingCalculation({
      fee: totalFee,
      isFree,
      isEstimated,
      note: isEstimated ? 'Shipping fees calculated based on locations' : undefined
    })
    
    setIsCalculatingShipping(false)
    return shippingMap
  }, [buyerAddress])

  const calculateShippingForItems = useCallback(
    async (itemIds: string[]): Promise<Record<string, ShippingCalculation>> => {
      const items = cart.items.filter((item) => itemIds.includes(item.id))
      return computeShippingForItemList(items)
    },
    [cart.items, computeShippingForItemList],
  )

  const calculateShippingForCheckoutItems = useCallback(
    async (items: CartItem[]): Promise<Record<string, ShippingCalculation>> => {
      return computeShippingForItemList(items)
    },
    [computeShippingForItemList],
  )

  // Clear shipping when cart is empty (per-line shipping is calculated from cart/checkout pages)
  useEffect(() => {
    if (!isLoading && cart.items.length === 0) {
      setShippingCalculation(null)
      setShippingBySeller({})
      setCart((prev) => ({ ...prev, shipping: 0, total: prev.subtotal }))
    }
  }, [cart.items.length, isLoading])

  const addToCart = (product: Product, quantity: number, variation: ProductVariation) => {
    if (!isAuthenticated || !user) {
      console.error("User must be authenticated to add to cart")
      return
    }

    if (user.role === "seller") {
      void assertNotOwnStoreProduct(product.sellerId)
        .then(() => {
          addToCartInner(product, quantity, variation)
        })
        .catch((e: Error) => {
          toast.error(e.message || "You cannot purchase from your own store.")
        })
      return
    }

    addToCartInner(product, quantity, variation)
  }

  const addToCartInner = (product: Product, quantity: number, variation: ProductVariation) => {
    // Optimistically update UI
    setCart((prev) => {
      const existingIndex = prev.items.findIndex(
        (item) => item.product.id === product.id && item.selectedVariation.id === variation.id,
      )

      let newItems: CartItem[]

      if (existingIndex >= 0) {
        newItems = prev.items.map((item, index) =>
          index === existingIndex ? { ...item, quantity: item.quantity + quantity } : item,
        )
      } else {
        const newItem: CartItem = {
          id: `pending-${product.id}-${variation.id}`,
          product,
          quantity,
          selectedVariation: variation,
        }
        newItems = [...prev.items, newItem]
      }

      const newSubtotal = newItems.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)

      const newShipping = getCartShippingEstimate(newSubtotal)
      setShippingCalculation(newShipping)

      return { items: newItems, ...calculateTotals(newItems, newShipping) }
    })

    // Send to backend and sync real cart item ids
    cartApi
      .add(parseInt(product.id, 10), parseInt(variation.id, 10), quantity)
      .then((response) => {
        applyCartFromBackend(response.data?.cart)
      })
      .catch((error) => {
        console.error("Failed to add to cart:", error)
        void reloadCartFromBackend()
      })
  }

  const updateQuantity = (itemId: string, quantity: number) => {
    if (!isAuthenticated) return

    if (quantity < 1) {
      removeFromCart(itemId)
      return
    }

    const targetItem = cart.items.find((item) => item.id === itemId)

    // Optimistically update UI
    setCart((prev) => {
      const newItems = prev.items.map((item) => (item.id === itemId ? { ...item, quantity } : item))
      
      const newSubtotal = newItems.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)

      const newShipping = getCartShippingEstimate(newSubtotal)
      setShippingCalculation(newShipping)

      return { items: newItems, ...calculateTotals(newItems, newShipping) }
    })

    const persistUpdate = async () => {
      let numericId = parseBackendCartItemId(itemId)
      if (numericId == null && targetItem) {
        try {
          const response = await cartApi.get()
          const backendItems = response.data?.cart?.items ?? []
          const match = backendItems.find(
            (bi: { productId: number; variationId: number }) =>
              String(bi.productId) === targetItem.product.id &&
              String(bi.variationId) === targetItem.selectedVariation.id,
          )
          if (match) numericId = match.id
        } catch {
          /* reload below */
        }
      }
      if (numericId == null) {
        void reloadCartFromBackend()
        return
      }
      try {
        const response = await cartApi.updateItem(numericId, quantity)
        applyCartFromBackend(response.data?.cart)
      } catch (error) {
        console.error("Failed to update cart item:", error)
        void reloadCartFromBackend()
      }
    }
    void persistUpdate()
  }

  const removeFromCart = (itemId: string) => {
    if (!isAuthenticated) return

    const removedItem = cart.items.find((item) => item.id === itemId)

    // Optimistically update UI
    setCart((prev) => {
      const newItems = prev.items.filter((item) => item.id !== itemId)
      
      if (newItems.length === 0) {
        setShippingCalculation(null)
        return { items: newItems, subtotal: 0, shipping: 0, total: 0 }
      }

      const newSubtotal = newItems.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)

      const newShipping = getCartShippingEstimate(newSubtotal)
      setShippingCalculation(newShipping)

      return { items: newItems, ...calculateTotals(newItems, newShipping) }
    })

    const persistRemove = async () => {
      let numericId = parseBackendCartItemId(itemId)
      if (numericId == null && removedItem) {
        try {
          const response = await cartApi.get()
          const backendItems = response.data?.cart?.items ?? []
          const match = backendItems.find(
            (bi: { productId: number; variationId: number }) =>
              String(bi.productId) === removedItem.product.id &&
              String(bi.variationId) === removedItem.selectedVariation.id,
          )
          if (match) numericId = match.id
        } catch {
          /* reload below */
        }
      }
      if (numericId == null) {
        void reloadCartFromBackend()
        return
      }
      try {
        const response = await cartApi.removeItem(numericId)
        applyCartFromBackend(response.data?.cart)
      } catch (error) {
        console.error("Failed to remove from cart:", error)
        void reloadCartFromBackend()
      }
    }
    void persistRemove()
  }

  const removeItemsByIds = (itemIds: string[]) => {
    if (!isAuthenticated || itemIds.length === 0) return
    const idSet = new Set(itemIds)
    setCart((prev) => {
      const newItems = prev.items.filter((item) => !idSet.has(item.id))
      if (newItems.length === 0) {
        setShippingCalculation(null)
        setShippingBySeller({})
        return { items: newItems, subtotal: 0, shipping: 0, total: 0 }
      }
      const newSubtotal = newItems.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)
      const newShipping = getCartShippingEstimate(newSubtotal)
      setShippingCalculation(newShipping)
      return { items: newItems, ...calculateTotals(newItems, newShipping) }
    })
    void (async () => {
      for (const itemId of itemIds) {
        const numericId = parseBackendCartItemId(itemId)
        if (numericId != null) {
          try {
            await cartApi.removeItem(numericId)
          } catch (error) {
            console.error("Failed to remove cart item:", error)
          }
        }
      }
      try {
        await reloadCartFromBackend()
      } catch (error) {
        console.error("Failed to reload cart:", error)
      }
    })()
  }

  const clearCart = () => {
    if (!isAuthenticated) return

    // Optimistically update UI
    setCart({ items: [], subtotal: 0, shipping: 0, total: 0 })
    setShippingCalculation(null)
    setShippingBySeller({})

    // Send to backend
    cartApi.clear().catch((error) => {
      console.error("Failed to clear cart:", error)
    })
  }

  const itemCount = cart.items.reduce((sum, item) => sum + item.quantity, 0)

  return (
    <CartContext.Provider
      value={{
        cart,
        isLoading,
        addToCart,
        updateQuantity,
        removeFromCart,
        removeItemsByIds,
        clearCart,
        itemCount,
        shippingCalculation,
        shippingBySeller,
        isCalculatingShipping,
        updateShippingEstimate,
        calculateShippingForItems,
        calculateShippingForCheckoutItems,
      }}
    >
      {children}
    </CartContext.Provider>
  )
}

export function useCart() {
  const context = useContext(CartContext)
  if (!context) {
    throw new Error("useCart must be used within a CartProvider")
  }
  return context
}
