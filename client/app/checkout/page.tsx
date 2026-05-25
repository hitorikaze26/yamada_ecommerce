"use client"

import type React from "react"

import { useEffect, useRef, useState, Suspense } from "react"
import Image from "next/image"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { AddressSelector } from "@/components/form/address-selector"
import { GlassAlert } from "@/components/ui/glass-alert"
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { useCart } from "@/context/cart-context"
import { StoreNameLink } from "@/components/store/store-name-link"
import {
  buyNowPayloadToCartItem,
  clearBuyNowCheckout,
  getBuyNowCheckout,
} from "@/lib/buy-now"
import { useAuth } from "@/context/auth-context"
import { buyerApi, ordersApi, type AddressData } from "@/lib/api"
import { formatShippingDisplay } from "@/lib/shipping"
import { formatPrice } from "@/lib/format"
import { toast } from "sonner"
import {
  BuyerVerificationBanner,
  BUYER_VERIFICATION_MESSAGE,
} from "@/components/buyer/buyer-verification-banner"
import { SellerShoppingBanner } from "@/components/seller/seller-shopping-banner"

const paymentMethods = [
  {
    id: "cod",
    name: "Cash on Delivery",
    icon: "money-bill-wave",
    description: "Pay when you receive",
  },
]

function CheckoutContent() {
  const router = useRouter()
  const {
    cart,
    clearCart,
    removeItemsByIds,
    shippingBySeller,
    shippingCalculation,
    isCalculatingShipping,
    calculateShippingForItems,
    calculateShippingForCheckoutItems,
  } = useCart()
  const { isAuthenticated, user, getRole, isVerified, refreshBuyerProfile } = useAuth()
  const searchParams = useSearchParams()

  const isBuyNow = searchParams.get("buyNow") === "1"
  const buyNowPayload = isBuyNow ? getBuyNowCheckout() : null

  const [existingAddress, setExistingAddress] = useState<AddressData | null>(null)
  const [isExistingAddressLoading, setIsExistingAddressLoading] = useState(true)
  const [addressMode, setAddressMode] = useState<"existing" | "new">("existing")
  const [isAddressModalOpen, setIsAddressModalOpen] = useState(false)
  const [tempNewAddress, setTempNewAddress] = useState<AddressData | null>(null)

  const itemsParam = searchParams.get("items")
  const selectedIds = itemsParam ? itemsParam.split(",").filter(Boolean) : null

  const itemsForCheckout = (() => {
    if (buyNowPayload) {
      return [buyNowPayloadToCartItem(buyNowPayload)]
    }
    if (selectedIds && selectedIds.length > 0) {
      return cart.items.filter((item) => selectedIds.includes(item.id))
    }
    return cart.items
  })()

  const subtotalForCheckout = itemsForCheckout.reduce((sum, item) => {
    const price = item.selectedVariation.price ?? item.product.salePrice ?? item.product.price
    return sum + price * item.quantity
  }, 0)

  const [shippingAddress, setShippingAddress] = useState<AddressData | null>(null)
  const [paymentMethod, setPaymentMethod] = useState("cod")
  const [contactNumber, setContactNumber] = useState(user?.contactNumber || "")
  const [notes, setNotes] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const placingRef = useRef(false)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  // Sync contact number from auth user when it becomes available (e.g. after localStorage hydration)
  useEffect(() => {
    if (user?.contactNumber && !contactNumber) {
      setContactNumber(user.contactNumber)
    }
  }, [user?.contactNumber])


  // Group items by seller for display
  const itemsBySeller = itemsForCheckout.reduce((acc, item) => {
    const sellerId = item.product.sellerId || 'unknown'
    const sellerName = item.product.sellerName || 'Unknown Seller'
    if (!acc[sellerId]) {
      acc[sellerId] = { sellerId, sellerName, items: [] }
    }
    acc[sellerId].items.push(item)
    return acc
  }, {} as Record<string, { sellerId: string; sellerName: string; items: typeof itemsForCheckout }>)

  // Calculate shipping using context when address changes
  const handleAddressChange = async (address: AddressData) => {
    setShippingAddress(address)
    if (itemsForCheckout.length > 0) {
      if (buyNowPayload) {
        await calculateShippingForCheckoutItems(itemsForCheckout)
      } else {
        const itemIds = itemsForCheckout.map((item) => item.id)
        await calculateShippingForItems(itemIds)
      }
    }
  }

  // Load existing buyer address and contact from profile
  useEffect(() => {
    const loadProfile = async () => {
      try {
        const res = await buyerApi.getProfile()
        const data: any = res.data

        // API returns { profile: { contactNumber, address: {...} } }
        const profile = data?.profile ?? data?.buyer ?? data?.user ?? data

        // Extract address — the buyer profile endpoint returns it under profile.address
        const addr: any = profile?.address ?? profile?.shippingAddress ?? null

        if (addr && typeof addr === 'object' && addr.regionCode) {
          setExistingAddress(addr as AddressData)
          setShippingAddress(addr as AddressData)
          setAddressMode("existing")
          // Trigger shipping calculation with the loaded address
          handleAddressChange(addr as AddressData)
        } else {
          setAddressMode("new")
        }

        // Always prefer the profile contact number (overrides the auth-context placeholder)
        const profileContact =
          profile?.contactNumber ||
          profile?.contact_number ||
          profile?.phoneNumber ||
          profile?.phone
        if (profileContact) {
          setContactNumber(profileContact)
        }
      } catch (error: any) {
        console.error("[checkout] Failed to load buyer profile:", error?.response?.status, error?.message)
        setAddressMode("new")
      } finally {
        setIsExistingAddressLoading(false)
      }
    }

    loadProfile()
  }, [])

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!shippingAddress) {
      showAlert("Please select a shipping address.", "error")
      return
    }

    if (!contactNumber) {
      showAlert("Please enter a contact number.", "error")
      return
    }

    if (!isAuthenticated) {
      router.push("/auth/login?redirect=/checkout")
      return
    }

    if (getRole() === "buyer") {
      await refreshBuyerProfile()
    }
    if (getRole() === "buyer" && !isVerified()) {
      showAlert(BUYER_VERIFICATION_MESSAGE, "warning")
      return
    }

    if (placingRef.current) return
    placingRef.current = true
    setIsLoading(true)

    const checkoutIdempotencyKey =
      typeof crypto !== "undefined" && crypto.randomUUID
        ? crypto.randomUUID()
        : `checkout-${Date.now()}`

    const itemsBySeller = itemsForCheckout.reduce(
      (acc, item) => {
        const sellerId = item.product.sellerId || "unknown"
        if (!acc[sellerId]) acc[sellerId] = []
        acc[sellerId].push(item)
        return acc
      },
      {} as Record<string, typeof itemsForCheckout>,
    )

    const placedOrderIds: string[] = []
    const succeededItemIds: string[] = []
    const failedStoreNames: string[] = []

    try {
      for (const [sellerId, sellerItems] of Object.entries(itemsBySeller)) {
        const shippingFee = shippingBySeller[sellerId]?.fee ?? 0
        const payload = {
          shippingAddress,
          paymentMethod,
          shippingFee,
          idempotencyKey: `${checkoutIdempotencyKey}-${sellerId}`,
          items: sellerItems.map((item) => ({
            productId: String(item.product.id),
            quantity: item.quantity,
            variant: {
              size: item.selectedVariation.size,
              color: item.selectedVariation.color,
              sku: item.selectedVariation.sku,
            },
          })),
        }

        try {
          const res = await ordersApi.create(payload)
          const order = (res.data as any)?.order
          if (order?.id != null) {
            placedOrderIds.push(String(order.id))
          }
          succeededItemIds.push(...sellerItems.map((i) => i.id))
        } catch (err: any) {
          const storeName = sellerItems[0]?.product?.sellerName || "Store"
          failedStoreNames.push(storeName)
          console.error(`Checkout failed for ${storeName}:`, err)
        }
      }

      if (placedOrderIds.length === 0) {
        const detail =
          failedStoreNames.length > 0
            ? `Could not place orders for: ${failedStoreNames.join(", ")}`
            : "No orders were placed."
        showAlert(detail, "error")
        return
      }

      if (buyNowPayload) {
        clearBuyNowCheckout()
      } else if (succeededItemIds.length > 0) {
        removeItemsByIds(succeededItemIds)
      }

      let message = `Order${placedOrderIds.length > 1 ? "s" : ""} placed. Track them under My Orders — you'll get in-app updates.`
      if (failedStoreNames.length > 0) {
        message += ` Some stores failed (${failedStoreNames.join(", ")}); those items remain in your cart.`
      }
      showAlert(message, "success")
      router.push("/buyer/orders?placed=1")
    } catch (error: any) {
      const msg =
        error?.response?.data?.msg ??
        error?.response?.data?.message ??
        "Failed to place order. Please try again later."
      showAlert(String(msg), "error")
    } finally {
      placingRef.current = false
      setIsLoading(false)
    }
  }

  if (isBuyNow && !buyNowPayload) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center px-4">
            <h1 className="text-2xl font-bold mb-2">Buy Now session expired</h1>
            <p className="text-muted-foreground mb-6">Please select the product again.</p>
            <Button asChild size="lg">
              <Link href="/search">Continue Shopping</Link>
            </Button>
          </div>
        </main>
        <Footer />
      </div>
    )
  }

  if (itemsForCheckout.length === 0) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center px-4">
            <div className="w-32 h-32 rounded-full bg-muted flex items-center justify-center mx-auto mb-6">
              <Icon name="shopping-cart" size="xl" className="text-muted-foreground text-4xl" />
            </div>
            <h1 className="text-3xl font-bold mb-2">Your cart is empty</h1>
            <p className="text-muted-foreground mb-6">Add some items to checkout</p>
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
      <GlassAlert
        open={alertOpen && !!alertMessage}
        title={
          alertVariant === "success"
            ? "Success"
            : alertVariant === "error"
              ? "Error"
              : alertVariant === "warning"
                ? "Warning"
                : "Notice"
        }
        description={alertMessage ?? undefined}
        variant={alertVariant}
        onClose={() => setAlertOpen(false)}
      />
      <Navbar />

      <main className="flex-1 bg-muted/30">
        <div className="container mx-auto px-4 py-8">
          <h1 className="text-3xl font-bold mb-4">Checkout</h1>

          {user?.role === "seller" && (
            <div className="mb-4">
              <SellerShoppingBanner />
            </div>
          )}

          {isAuthenticated && getRole() === "buyer" && !isVerified() && (
            <div className="mb-6">
              <BuyerVerificationBanner />
            </div>
          )}

          {Object.keys(itemsBySeller).length > 1 && (
            <div className="mb-6 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-2xl p-4 text-sm flex items-start gap-2">
              <Icon name="info-circle" className="mt-0.5 text-blue-600 dark:text-blue-400 flex-shrink-0" />
              <p>
                You&apos;ll place <strong>{Object.keys(itemsBySeller).length} separate orders</strong> (one per
                store). Each store is checked out individually.
              </p>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="grid lg:grid-cols-3 gap-8">
              {/* Checkout Form */}
              <div className="lg:col-span-2 space-y-6">
                {/* Shipping Address */}
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="bg-card border rounded-2xl p-6"
                >
                  <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                    <Icon name="marker" className="text-primary" />
                    Shipping Address
                  </h2>
                  {isExistingAddressLoading ? (
                    <p className="text-sm text-muted-foreground">Loading your address...</p>
                  ) : (
                    <div className="space-y-4">
                      <RadioGroup
                        value={addressMode}
                        onValueChange={(value) => setAddressMode(value as "existing" | "new")}
                        className="flex flex-col gap-2 sm:flex-row sm:gap-4"
                      >
                        <label className="flex items-center gap-2 cursor-pointer">
                          <RadioGroupItem value="existing" id="address-existing" />
                          <span className="text-sm">Use existing address</span>
                        </label>
                        <label className="flex items-center gap-2 cursor-pointer">
                          <RadioGroupItem value="new" id="address-new" />
                          <span className="text-sm">Use another address</span>
                        </label>
                      </RadioGroup>

                      {addressMode === "existing" && existingAddress && (
                        <div className="p-4 rounded-xl border bg-muted/40 text-sm">
                          <p className="font-medium mb-1">Saved address</p>
                          <p className="text-muted-foreground">
                            {[ 
                              existingAddress.streetAddress,
                              existingAddress.barangayName,
                              existingAddress.municipalityName,
                              existingAddress.provinceName,
                              existingAddress.regionName,
                            ]
                              .filter(Boolean)
                              .join(", ")}
                            {existingAddress.postalCode && ` ${existingAddress.postalCode}`}
                          </p>
                        </div>
                      )}

                      {addressMode === "existing" && !existingAddress && (
                        <p className="text-sm text-muted-foreground">
                          No saved address found. Please add a new address.
                        </p>
                      )}

                      {addressMode === "new" && (
                        <div className="space-y-3">
                          <Button variant="outline" type="button" onClick={() => setIsAddressModalOpen(true)}>
                            Add another address
                          </Button>

                          {shippingAddress && (
                            <div className="p-3 bg-muted rounded-lg text-sm">
                              <div className="flex items-start gap-2">
                                <Icon name="marker" className="text-primary mt-0.5" />
                                <div>
                                  <p className="font-medium">Selected address</p>
                                  <p className="text-muted-foreground">
                                    {[ 
                                      shippingAddress.streetAddress,
                                      shippingAddress.barangayName,
                                      shippingAddress.municipalityName,
                                      shippingAddress.provinceName,
                                      shippingAddress.regionName,
                                    ]
                                      .filter(Boolean)
                                      .join(", ")}
                                    {shippingAddress.postalCode && ` ${shippingAddress.postalCode}`}
                                  </p>
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  )}
                </motion.div>

                {/* Contact Information */}
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 }}
                  className="bg-card border rounded-2xl p-6"
                >
                  <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                    <Icon name="phone-call" className="text-primary" />
                    Contact Information
                  </h2>
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <Label htmlFor="contact">Contact Number</Label>
                      <Input
                        id="contact"
                        type="tel"
                        placeholder="+63 912 345 6789"
                        value={contactNumber}
                        onChange={(e) => setContactNumber(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="notes">Order Notes (Optional)</Label>
                      <Input
                        id="notes"
                        placeholder="Any special instructions for delivery..."
                        value={notes}
                        onChange={(e) => setNotes(e.target.value)}
                      />
                    </div>
                  </div>
                </motion.div>

                {/* Payment Method */}
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.2 }}
                  className="bg-card border rounded-2xl p-6"
                >
                  <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                    <Icon name="credit-card" className="text-primary" />
                    Payment Method
                  </h2>
                  <RadioGroup value={paymentMethod} onValueChange={setPaymentMethod} className="space-y-3">
                    {paymentMethods.map((method) => (
                      <label
                        key={method.id}
                        htmlFor={method.id}
                        className={`flex items-center gap-4 p-4 rounded-xl border-2 cursor-pointer transition-all ${
                          paymentMethod === method.id
                            ? "border-primary bg-primary/5"
                            : "border-transparent bg-muted/50 hover:border-primary/30"
                        }`}
                      >
                        <RadioGroupItem value={method.id} id={method.id} />
                        <div className="w-10 h-10 rounded-lg bg-background flex items-center justify-center">
                          <Icon name={method.icon} className="text-primary" />
                        </div>
                        <div className="flex-1">
                          <p className="font-medium">{method.name}</p>
                          <p className="text-sm text-muted-foreground">{method.description}</p>
                        </div>
                      </label>
                    ))}
                  </RadioGroup>
                </motion.div>
              </div>

              {/* Order Summary */}
              <div className="lg:col-span-1">
                <motion.div
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.3 }}
                  className="bg-card border rounded-2xl p-6 sticky top-24"
                >
                  <h2 className="text-xl font-semibold mb-4">Order Summary</h2>

                  {/* Items grouped by seller */}
                  <div className="space-y-4 mb-6 max-h-64 overflow-y-auto">
                    {Object.values(itemsBySeller).map((sellerGroup) => (
                      <div key={sellerGroup.sellerId} className="border rounded-lg overflow-hidden">
                        {/* Shop Name Header */}
                        <div className="bg-primary px-3 py-2 flex items-center gap-2 text-primary-foreground">
                          <Icon name="store" className="w-4 h-4 shrink-0" />
                          <StoreNameLink
                            storeId={sellerGroup.sellerId}
                            storeName={sellerGroup.sellerName}
                            onPrimary
                            className="font-medium text-sm min-w-0"
                          />
                          {shippingBySeller[sellerGroup.sellerId] && (
                            <span className="ml-auto text-xs text-primary-foreground/80">
                              {formatShippingDisplay(shippingBySeller[sellerGroup.sellerId])}
                            </span>
                          )}
                        </div>
                        {/* Items from this seller */}
                        <div className="divide-y">
                          {sellerGroup.items.map((item) => (
                            <div key={item.id} className="flex gap-3 p-3">
                              <div className="relative w-16 h-16 rounded-lg overflow-hidden bg-muted flex-shrink-0">
                                <Image
                                  src={item.product?.images?.[0] || item.product?.imageUrl || "/placeholder.svg"}
                                  alt={item.product?.name || "Product"}
                                  fill
                                  className="object-cover"
                                />
                                <span className="absolute -top-1 -right-1 w-5 h-5 bg-primary text-primary-foreground text-xs rounded-full flex items-center justify-center">
                                  {item.quantity}
                                </span>
                              </div>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-medium truncate">{item.product.name}</p>
                                <p className="text-xs text-muted-foreground">
                                  {item.selectedVariation.size} / {item.selectedVariation.color}
                                </p>
                                <p className="text-sm font-medium text-primary">
                                  {formatPrice(
                                    (item.selectedVariation.price ?? item.product.salePrice ?? item.product.price) *
                                      item.quantity,
                                  )}
                                </p>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="border-t pt-4 space-y-3">
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Subtotal</span>
                      <span>{formatPrice(subtotalForCheckout)}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Shipping</span>
                      <span className={shippingCalculation?.isFree ? "text-green-600" : ""}>
                        {isCalculatingShipping ? (
                          <span className="flex items-center gap-2">
                            <Icon name="arrow-path" className="animate-spin" size="sm" />
                            Calculating...
                          </span>
                        ) : shippingCalculation ? (
                          formatShippingDisplay(shippingCalculation)
                        ) : (
                          "TBD"
                        )}
                      </span>
                    </div>
                    {shippingCalculation?.isEstimated && (
                      <p className="text-xs text-muted-foreground">
                        {shippingCalculation.note}
                      </p>
                    )}
                    <div className="border-t pt-3 flex justify-between font-semibold text-lg">
                      <span>Total</span>
                      <span className="text-primary">
                        {formatPrice(subtotalForCheckout + (shippingCalculation?.fee ?? 0))}
                      </span>
                    </div>
                  </div>

                  <Button type="submit" className="w-full mt-6" size="lg" disabled={isLoading}>
                    {isLoading ? (
                      <>
                        <Icon name="spinner" className="mr-2 animate-spin" />
                        Processing...
                      </>
                    ) : (
                      <>
                        Place Order
                        <Icon name="arrow-right" className="ml-2" />
                      </>
                    )}
                  </Button>

                  <p className="text-xs text-muted-foreground text-center mt-4">
                    By placing this order, you agree to our{" "}
                    <Link href="/terms" className="text-primary hover:underline">
                      Terms of Service
                    </Link>
                  </p>
                </motion.div>
              </div>
            </div>
          </form>
        </div>
      </main>

      <Footer />

      <Dialog open={isAddressModalOpen} onOpenChange={setIsAddressModalOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Add another address</DialogTitle>
          </DialogHeader>

          <div className="mt-2">
            <AddressSelector value={tempNewAddress} onChange={setTempNewAddress} />
          </div>

          <DialogFooter className="mt-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                setTempNewAddress(null)
                setIsAddressModalOpen(false)
              }}
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={() => {
                if (tempNewAddress) {
                  handleAddressChange(tempNewAddress)
                  setIsAddressModalOpen(false)
                }
              }}
              disabled={!tempNewAddress}
            >
              Use this address
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

export default function CheckoutPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen flex flex-col">
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
            <p>Loading checkout...</p>
          </div>
        </div>
      </div>
    }>
      <CheckoutContent />
    </Suspense>
  )
}
