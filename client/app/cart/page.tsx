"use client"

import Image from "next/image"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { useState, useEffect, useMemo } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { useCart } from "@/context/cart-context"
import { useAuth } from "@/context/auth-context"
import {
  BuyerVerificationBanner,
  shouldShowBuyerVerificationBanner,
} from "@/components/buyer/buyer-verification-banner"
import { formatShippingDisplay, FREE_SHIPPING_THRESHOLD } from "@/lib/shipping"
import { ShippingEstimator } from "@/components/cart/shipping-estimator"
import { formatPrice } from "@/lib/format"
import { resolveImageUrl } from "@/lib/api"
import { StoreNameLink } from "@/components/store/store-name-link"

export default function CartPage() {
  const { cart, updateQuantity, removeFromCart, clearCart, shippingBySeller, isCalculatingShipping, calculateShippingForItems } = useCart()
  const { user, isAuthenticated, getRole, isVerified } = useAuth()
  const router = useRouter()

  
  const [selectedItems, setSelectedItems] = useState<string[]>([])

  // Helper function to normalize image URLs
  const normalizeImageUrl = (imageUrl?: string | null): string => {
    if (!imageUrl) return "/placeholder.svg"
    
    const normalized = imageUrl.replace(/\\/g, "/")
    const trimmed = normalized.replace(/^\/+/, "")

    if (trimmed.startsWith("static/")) {
      return resolveImageUrl(`/${trimmed}`) ?? "/placeholder.svg"
    }
    
    if (!imageUrl.startsWith("http")) {
      return resolveImageUrl(`/static/${trimmed}`) ?? "/placeholder.svg"
    }
    
    return imageUrl
  }

  // Select all items by default when cart loads
  useEffect(() => {
    const itemIds = cart.items.map((item) => item.id)
    setSelectedItems(itemIds)
  }, [cart.items])

  const toggleItemSelection = (itemId: string) => {
    setSelectedItems((prev) =>
      prev.includes(itemId) ? prev.filter((id) => id !== itemId) : [...prev, itemId],
    )
  }

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

  const handleCheckout = () => {
    if (selectedItems.length === 0) return
    if (!isAuthenticated) {
      router.push("/auth/login?redirect=/checkout")
      return
    }

    const params = new URLSearchParams()
    params.set("items", selectedItems.join(","))
    router.push(`/checkout?${params.toString()}`)
  }

  const allSelected = cart.items.length > 0 && selectedItems.length === cart.items.length

  // Memoize selected cart items to prevent unnecessary recalculations
  const selectedCartItems = useMemo(() => 
    cart.items.filter((item) => selectedItems.includes(item.id)),
    [cart.items, selectedItems]
  )
  
  const selectedSubtotal = selectedCartItems.reduce((sum, item) => {
    const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
    return sum + price * item.quantity
  }, 0)

  if (cart.items.length === 0) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center px-4">
            <div className="w-32 h-32 rounded-full bg-muted flex items-center justify-center mx-auto mb-6">
              <Icon name="shopping-cart" size="xl" className="text-muted-foreground text-4xl" />
            </div>
            <h1 className="text-3xl font-bold mb-2">Your cart is empty</h1>
            <p className="text-muted-foreground mb-6">Looks like you haven&apos;t added any items yet</p>
            <Button asChild size="lg">
              <Link href="/search">Start Shopping</Link>
            </Button>
          </div>
        </main>
        <Footer />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-8">
          <div className="flex items-center justify-between mb-8">
            <h1 className="text-3xl font-bold">Shopping Cart</h1>
            <Button variant="ghost" onClick={clearCart} className="text-destructive hover:text-destructive">
              <Icon name="trash" className="mr-2" />
              Clear Cart
            </Button>
          </div>

          {shouldShowBuyerVerificationBanner(
            isAuthenticated,
            getRole(),
            isVerified(),
          ) && (
            <div className="mb-6">
              <BuyerVerificationBanner />
            </div>
          )}

          {selectedSellerIds.size > 1 && (
            <div className="mb-6 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-2xl p-4 text-sm flex items-start gap-2">
              <Icon name="info-circle" className="mt-0.5 text-blue-600 dark:text-blue-400 flex-shrink-0" />
              <p>
                You&apos;ll place <strong>{selectedSellerIds.size} separate orders</strong> (one per store) at
                checkout.
              </p>
            </div>
          )}

          <div className="grid lg:grid-cols-3 gap-8">
            {/* Cart Items */}
            <div className="lg:col-span-2 space-y-4">
              {/* Select All / Delete Selected */}
              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-primary text-primary focus:ring-primary"
                    checked={allSelected}
                    onChange={toggleSelectAll}
                  />
                  <span className="text-muted-foreground">Select all ({cart.items.length} items)</span>
                </label>
                {selectedItems.length > 0 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-destructive hover:text-destructive/80 hover:bg-destructive/5"
                    onClick={handleDeleteSelected}
                  >
                    <Icon name="trash" className="mr-1" size="sm" />
                    Delete Selected
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
                    exit={{ opacity: 0, x: -100 }}
                    className="bg-card border rounded-2xl overflow-hidden"
                  >
                    {/* Shop Name Header - Themed color */}
                    <div className="bg-primary px-4 py-3 flex items-center gap-2 text-primary-foreground">
                      <Icon name="store" className="w-4 h-4 shrink-0" />
                      <StoreNameLink
                        storeId={sellerGroup.sellerId}
                        storeName={sellerGroup.sellerName}
                        onPrimary
                        className="font-medium min-w-0"
                      />
                      {shippingBySeller[sellerGroup.sellerId] && (
                        <span className="ml-auto text-sm text-primary-foreground/80">
                          Shipping: {formatShippingDisplay(shippingBySeller[sellerGroup.sellerId])}
                        </span>
                      )}
                    </div>

                    {/* Items from this seller */}
                    <div className="divide-y">
                      {sellerGroup.items.map((item) => (
                        <div key={item.id} className="flex gap-4 p-4">
                          {/* Checkbox */}
                          <div className="flex items-center">
                            <input
                              type="checkbox"
                              className="h-4 w-4 rounded border-primary text-primary focus:ring-primary"
                              checked={selectedItems.includes(item.id)}
                              onChange={() => toggleItemSelection(item.id)}
                            />
                          </div>

                          <Link
                            href={`/product/${item.product.slug}`}
                            className="relative w-24 h-24 md:w-32 md:h-32 rounded-xl overflow-hidden bg-muted flex-shrink-0"
                          >
                            <Image
                              src={normalizeImageUrl(item.product?.images?.[0] || item.product?.imageUrl)}
                              alt={item.product?.name || "Product"}
                              fill
                              className="object-cover"
                            />
                          </Link>

                          <div className="flex-1 min-w-0">
                            <div className="flex justify-between gap-4">
                              <div>
                                <Link
                                  href={`/product/${item.product.slug}`}
                                  className="font-medium hover:text-primary transition-colors line-clamp-2"
                                >
                                  {item.product.name}
                                </Link>
                                <p className="text-sm text-muted-foreground mt-1">
                                  {item.selectedVariation.size} / {item.selectedVariation.color}
                                </p>
                              </div>
                              <button
                                onClick={() => removeFromCart(item.id)}
                                className="text-muted-foreground hover:text-destructive transition-colors flex-shrink-0"
                                aria-label="Remove item"
                              >
                                <Icon name="trash" />
                              </button>
                            </div>

                            <div className="flex items-center justify-between mt-4">
                              <div className="flex items-center gap-2">
                                <button
                                  onClick={() => updateQuantity(item.id, item.quantity - 1)}
                                  className="w-8 h-8 rounded-lg border flex items-center justify-center hover:bg-muted transition-colors"
                                  aria-label="Decrease quantity"
                                >
                                  <Icon name="minus" size="sm" />
                                </button>
                                <span className="w-10 text-center font-medium">{item.quantity}</span>
                                <button
                                  onClick={() => updateQuantity(item.id, item.quantity + 1)}
                            className="w-8 h-8 rounded-lg border flex items-center justify-center hover:bg-muted transition-colors"
                            aria-label="Increase quantity"
                          >
                            <Icon name="plus" size="sm" />
                          </button>
                        </div>

                        <div className="text-right">
                          <p className="font-semibold text-primary">
                            {formatPrice(
                              (item.selectedVariation.price ?? item.product.salePrice ?? item.product.price) *
                                item.quantity,
                            )}
                          </p>
                          {item.quantity > 1 && (
                            <p className="text-xs text-muted-foreground">
                              {formatPrice(
                                item.selectedVariation.price ?? item.product.salePrice ?? item.product.price,
                              )}{" "}
                              each
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

            {/* Order Summary */}
            <div className="lg:col-span-1">
              <div className="bg-card border rounded-2xl p-6 sticky top-24">
                <h2 className="text-xl font-semibold mb-4">Order Summary</h2>

                <div className="space-y-3 mb-6">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Subtotal ({selectedCartItems.length} items)</span>
                    <span>{formatPrice(selectedSubtotal)}</span>
                  </div>
                  <div className="flex justify-between">
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
                  <div className="border-t pt-3 flex justify-between font-semibold text-lg">
                    <span>Total</span>
                    <span className="text-primary">{formatPrice(selectedTotal)}</span>
                  </div>
                </div>

                {totalShipping > 0 && selectedSubtotal < FREE_SHIPPING_THRESHOLD && selectedCartItems.length > 0 && (
                  <div className="bg-primary/10 text-primary text-sm p-3 rounded-lg mb-4">
                    <Icon name="truck-loading" className="inline mr-2" />
                    Add {formatPrice(FREE_SHIPPING_THRESHOLD - selectedSubtotal)} more for free shipping!
                  </div>
                )}

                <div className="mb-4">
                  <ShippingEstimator className="w-full" />
                </div>

                <Button
                  className="w-full"
                  size="lg"
                  onClick={handleCheckout}
                  disabled={selectedItems.length === 0}
                >
                  Proceed to Checkout
                  <Icon name="arrow-right" className="ml-2" />
                </Button>

                <Link
                  href="/search"
                  className="flex items-center justify-center gap-2 text-sm text-muted-foreground hover:text-foreground mt-4"
                >
                  <Icon name="arrow-left" />
                  Continue Shopping
                </Link>
              </div>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}
