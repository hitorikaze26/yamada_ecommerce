"use client"

import { useEffect, useState, useCallback, useMemo } from "react"
import { useRouter } from "next/navigation"
import Image from "next/image"
import { motion, AnimatePresence } from "framer-motion"
import { useCart } from "@/context/cart-context"
import { useAuth } from "@/context/auth-context"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import { formatShippingDisplay, FREE_SHIPPING_THRESHOLD, FALLBACK_SHIPPING_FEE, type ShippingCalculation } from "@/lib/shipping"
import { shippingApi } from "@/lib/api"
import { buyerApi } from "@/lib/api"
import { StoreNameLink } from "@/components/store/store-name-link"

interface CartDrawerProps {
  open: boolean
  onClose: () => void
}

export function CartDrawer({ open, onClose }: CartDrawerProps) {
  const { cart, updateQuantity, removeFromCart, itemCount } = useCart()
  const { user } = useAuth()
  const router = useRouter()

  const [selectedItems, setSelectedItems] = useState<string[]>([])
  const [buyerProfile, setBuyerProfile] = useState<any>(null)
  const [shippingBySeller, setShippingBySeller] = useState<Record<string, ShippingCalculation>>({})
  const [isCalculatingShipping, setIsCalculatingShipping] = useState(false)

  useEffect(() => {
    setSelectedItems((prev) => {
      const currentIds = cart.items.map((item) => item.id)
      // Keep selections that still exist, default-select new items
      const persisted = prev.filter((id) => currentIds.includes(id))
      const newOnes = currentIds.filter((id) => !persisted.includes(id))
      return [...persisted, ...newOnes]
    })
  }, [cart.items])

  const toggleItemSelection = (itemId: string) => {
    setSelectedItems((prev) =>
      prev.includes(itemId) ? prev.filter((id) => id !== itemId) : [...prev, itemId],
    )
  }

  const allSelected = cart.items.length > 0 && selectedItems.length === cart.items.length

  const toggleSelectAll = () => {
    if (allSelected) {
      setSelectedItems([])
    } else {
      setSelectedItems(cart.items.map((item) => item.id))
    }
  }

  const handleDeleteSelected = () => {
    selectedItems.forEach((id) => removeFromCart(id))
    setSelectedItems([])
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  const handleCheckout = () => {
    onClose()

    if (selectedItems.length > 0) {
      const params = new URLSearchParams()
      params.set("items", selectedItems.join(","))
      router.push(`/checkout?${params.toString()}`)
    } else {
      router.push("/checkout")
    }
  }

  const handleViewCart = () => {
    onClose()
    router.push("/cart")
  }

  // Memoize selected cart items to prevent unnecessary recalculations
  const selectedCartItems = useMemo(() =>
    cart.items.filter((item) => selectedItems.includes(item.id)),
    [cart.items, selectedItems]
  )

  const selectedSubtotal = selectedCartItems.reduce((sum, item) => {
    const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
    return sum + price * item.quantity
  }, 0)

  // Fetch buyer profile for shipping calculation
  useEffect(() => {
    const fetchBuyerProfile = async () => {
      if (!user) return
      try {
        const response = await buyerApi.getProfile()
        // API returns { profile: {...} } structure
        const profile = response.data?.profile || response.data
        setBuyerProfile(profile)
      } catch (error) {
        console.error("Failed to load buyer profile:", error)
      }
    }
    fetchBuyerProfile()
  }, [user])

  // Debounced shipping calculation for real-time updates
  const calculateShippingForCart = useCallback(async () => {
    if (selectedCartItems.length === 0) {
      setShippingBySeller({})
      return
    }

    setIsCalculatingShipping(true)

    // Group items by seller and calculate shipping per seller
    const itemsBySeller = selectedCartItems.reduce((acc, item) => {
      const sellerId = item.product.sellerId || 'unknown'
      if (!acc[sellerId]) acc[sellerId] = []
      acc[sellerId].push(item)
      return acc
    }, {} as Record<string, typeof selectedCartItems>)

    const shippingMap: Record<string, ShippingCalculation> = {}

    // Calculate shipping for each seller
    for (const [sellerId, items] of Object.entries(itemsBySeller)) {
      // Calculate subtotal first
      const subtotal = items.reduce((sum, item) => {
        const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
        return sum + price * item.quantity
      }, 0)

      // Skip invalid seller IDs
      const shopId = parseInt(sellerId)
      if (isNaN(shopId) || shopId <= 0) {
        shippingMap[sellerId] = {
          fee: subtotal >= FREE_SHIPPING_THRESHOLD ? 0 : FALLBACK_SHIPPING_FEE,
          isFree: subtotal >= FREE_SHIPPING_THRESHOLD,
          note: 'Shipping calculated (invalid seller)'
        }
        continue
      }

      // Calculate shipping using backend API
      let calculation: ShippingCalculation

      if (buyerProfile?.address) {
        try {
          const response = await shippingApi.calculateFee({
            shop_id: shopId,
            order_total: subtotal,
            buyer_region_code: buyerProfile.address.regionCode,
            buyer_province_code: buyerProfile.address.provinceCode,
            buyer_municipality_code: buyerProfile.address.municipalityCode
          })

          const backendResult = response.data
          // Use nullish coalescing (??) instead of OR (||) because 0 is valid for free shipping
          calculation = {
            fee: backendResult.shipping_fee ?? FALLBACK_SHIPPING_FEE,
            isFree: backendResult.free_shipping ?? false,
            note: backendResult.note ?? 'Shipping fee calculated'
          }
        } catch (error: any) {
          // Fallback to mobile-matching calculation
          const isFree = subtotal >= FREE_SHIPPING_THRESHOLD
          calculation = {
            fee: isFree ? 0 : FALLBACK_SHIPPING_FEE,
            isFree: isFree,
            note: isFree ? `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD}` : 'Shipping fee calculated (fallback)'
          }
        }
      } else {
        // No buyer address available - use mobile-matching estimate
        const isFree = subtotal >= FREE_SHIPPING_THRESHOLD
        calculation = {
          fee: isFree ? 0 : FALLBACK_SHIPPING_FEE,
          isFree: isFree,
          note: isFree ? `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD}` : 'Shipping calculated at checkout'
        }
      }

      shippingMap[sellerId] = calculation
    }

    setShippingBySeller(shippingMap)
    setIsCalculatingShipping(false)
  }, [selectedCartItems, buyerProfile])

  // Recalculate shipping when cart items, selection, or buyer profile changes
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      calculateShippingForCart()
    }, 300) // 300ms debounce

    return () => clearTimeout(timeoutId)
  }, [cart.items, selectedItems, buyerProfile, calculateShippingForCart])

  // Group all cart items by seller for display
  const itemsBySeller = cart.items.reduce((acc, item) => {
    const sellerId = item.product.sellerId || 'unknown'
    const sellerName = item.product.sellerName || 'Unknown Seller'
    if (!acc[sellerId]) {
      acc[sellerId] = { sellerId, sellerName, items: [] }
    }
    acc[sellerId].items.push(item)
    return acc
  }, {} as Record<string, { sellerId: string; sellerName: string; items: typeof cart.items }>)

  // Calculate total shipping from per-seller calculations
  const totalShipping = Object.values(shippingBySeller).reduce((sum, calc) => sum + calc.fee, 0)
  const selectedTotal = selectedSubtotal + totalShipping

  return (
    <Sheet open={open} onOpenChange={onClose}>
      <SheetContent className="w-full sm:max-w-md flex flex-col">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            <Icon name="shopping-cart" />
            Shopping Cart ({itemCount})
          </SheetTitle>
        </SheetHeader>

        {cart.items.length === 0 ? (
          <div className="flex-1 flex flex-col items-center justify-center gap-4 text-center">
            <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center">
              <Icon name="shopping-cart" size="xl" className="text-muted-foreground" />
            </div>
            <div>
              <p className="font-medium">Your cart is empty</p>
              <p className="text-sm text-muted-foreground">Add items to get started</p>
            </div>
            <Button onClick={onClose}>Continue Shopping</Button>
          </div>
        ) : (
          <>
            <div className="flex-1 overflow-y-auto py-4 px-4 space-y-4">
              <div className="flex items-center justify-between mb-2 text-sm">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-primary text-primary focus:ring-primary"
                    checked={allSelected}
                    onChange={toggleSelectAll}
                  />
                  <span className="text-muted-foreground">Select all</span>
                </label>
                {selectedItems.length > 0 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-destructive hover:text-destructive/80 hover:bg-destructive/5"
                    onClick={handleDeleteSelected}
                  >
                    Delete
                  </Button>
                )}
              </div>

              <AnimatePresence mode="popLayout">
                {Object.values(itemsBySeller).map((sellerGroup) => (
                  <motion.div
                    key={sellerGroup.sellerId}
                    layout
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, x: -20 }}
                    className="bg-muted/30 rounded-xl overflow-hidden"
                  >
                    {/* Shop Name Header - Themed color */}
                    <div className="bg-primary px-3 py-2 flex items-center gap-2 text-primary-foreground">
                      <Icon name="store" className="w-4 h-4 shrink-0" />
                      <StoreNameLink
                        storeId={sellerGroup.sellerId}
                        storeName={sellerGroup.sellerName}
                        onPrimary
                        className="text-sm font-medium min-w-0"
                      />
                      {shippingBySeller[sellerGroup.sellerId] && (
                        <span className="ml-auto text-xs text-primary-foreground/80">
                          {formatShippingDisplay(shippingBySeller[sellerGroup.sellerId])}
                        </span>
                      )}
                    </div>

                    {/* Items from this seller */}
                    <div className="divide-y divide-muted">
                      {sellerGroup.items.map((item) => (
                        <div key={item.id} className="flex gap-3 p-3">
                          <div className="flex items-center">
                            <input
                              type="checkbox"
                              className="h-4 w-4 rounded border-primary text-primary focus:ring-primary"
                              checked={selectedItems.includes(item.id)}
                              onChange={() => toggleItemSelection(item.id)}
                            />
                          </div>
                          <div className="relative w-16 h-16 rounded-lg overflow-hidden bg-muted flex-shrink-0">
                            <Image
                              src={item.product?.images?.[0] || item.product?.imageUrl || "/placeholder.svg?height=80&width=80&query=fashion"}
                              alt={item.product?.name || "Product"}
                              fill
                              className="object-cover"
                            />
                          </div>
                          <div className="flex-1 min-w-0">
                            <h4 className="font-medium text-sm truncate">{item.product.name}</h4>
                            <p className="text-xs text-muted-foreground">
                              {item.selectedVariation.size} / {item.selectedVariation.color}
                            </p>
                            <p className="text-sm font-semibold text-primary">
                              {formatPrice(item.selectedVariation.price ?? item.product.salePrice ?? item.product.price)}
                            </p>
                            <div className="flex items-center gap-2 mt-1">
                              <button
                                onClick={() => updateQuantity(item.id, item.quantity - 1)}
                                className="w-6 h-6 rounded-full bg-background border flex items-center justify-center hover:bg-muted transition-colors"
                                aria-label="Decrease quantity"
                              >
                                <Icon name="minus" size="sm" />
                              </button>
                              <span className="text-sm w-8 text-center">{item.quantity}</span>
                              <button
                                onClick={() => updateQuantity(item.id, item.quantity + 1)}
                                className="w-6 h-6 rounded-full bg-background border flex items-center justify-center hover:bg-muted transition-colors"
                                aria-label="Increase quantity"
                              >
                                <Icon name="plus" size="sm" />
                              </button>
                              <button
                                onClick={() => removeFromCart(item.id)}
                                className="ml-auto text-destructive hover:text-destructive/80 transition-colors"
                                aria-label="Remove item"
                              >
                                <Icon name="trash" size="sm" />
                              </button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>

            <div className="border-t pt-4 px-4 pb-4 space-y-4">
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Subtotal</span>
                  <span>{formatPrice(selectedSubtotal)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Shipping</span>
                  <span className={totalShipping === 0 && selectedCartItems.length > 0 ? "text-green-600" : ""}>
                    {isCalculatingShipping ? "Calculating..." : totalShipping === 0 && selectedCartItems.length > 0 ? "Free" : formatPrice(totalShipping)}
                  </span>
                </div>
                {selectedSubtotal < FREE_SHIPPING_THRESHOLD && selectedCartItems.length > 0 && (
                  <p className="text-xs text-muted-foreground">
                    Shipping calculated based on seller and buyer locations
                  </p>
                )}
                <div className="border-t pt-2 flex justify-between font-semibold">
                  <span>Total</span>
                  <span className="text-primary">{formatPrice(selectedTotal)}</span>
                </div>
              </div>

              <div className="flex gap-2">
                <Button variant="outline" className="flex-1 bg-transparent" onClick={handleViewCart}>
                  View Cart
                </Button>
                <Button className="flex-1" onClick={handleCheckout}>
                  Checkout
                </Button>
              </div>
            </div>
          </>
        )}
      </SheetContent>
    </Sheet>
  )
}
