"use client"
import { Suspense, useCallback, useEffect, useState } from "react"
import Link from "next/link"
import Image from "next/image"
import { useRouter, useSearchParams } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { ordersApi, resolveImageUrl } from "@/lib/api"
import type { Order } from "@/lib/types"
import { useAuth } from "@/context/auth-context"
import Swal from "sweetalert2"
import "sweetalert2/dist/sweetalert2.min.css"
import {
  BUYER_ORDER_FILTERS,
  filterOrdersByBuyerFilter,
  normalizeBuyerOrderFilter,
  type BuyerOrderFilterKey,
} from "@/lib/buyer/order-filters"
import { BuyerVerificationBanner } from "@/components/buyer/buyer-verification-banner"
import { resolveStoreIdFromOrder } from "@/lib/buyer/order-chat"
import { canMessageSellerForBuyerOrder } from "@/lib/chat/navigation"
import { useChatOpen } from "@/hooks/use-chat-open"
import { StoreNameLink } from "@/components/store/store-name-link"
import { ReportLinkButton } from "@/components/report/report-link-button"
import {
  canBuyerConfirmReceipt,
  formatOrderStatusLabel,
  getEffectiveOrderStatus,
  isOrderDelivered,
  orderStatusBadgeClass,
  shouldPollOrderStatus,
} from "@/lib/buyer/order-status"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"

type OrderWithRider = Order & {
  riderDelivery?: { status?: string; proofPhotoUrl?: string | null; rider?: { id?: number; name?: string } }
  store?: { id: number; name: string }
}

function BuyerOrdersContent() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const filterParam = normalizeBuyerOrderFilter(searchParams.get("filter"))
  const [activeTab, setActiveTab] = useState<BuyerOrderFilterKey>(filterParam)
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const { getRole, isVerified } = useAuth()
  const role = getRole()
  const buyerUnverified = role === "buyer" && !isVerified()

  useEffect(() => {
    setActiveTab(normalizeBuyerOrderFilter(searchParams.get("filter")))
  }, [searchParams])

  useEffect(() => {
    if (searchParams.get("placed") === "1") {
      void Swal.fire({
        title: "Order placed",
        text: "Track your orders here. You'll get in-app updates.",
        icon: "success",
        timer: 2800,
        showConfirmButton: false,
      })
      router.replace("/buyer/orders")
    }
  }, [searchParams, router])

  const fetchOrders = useCallback(async (opts?: { silent?: boolean }) => {
    if (!opts?.silent) {
      setIsLoading(true)
      setError(null)
    }
    try {
      const res = await ordersApi.getAll()
      const fetchedOrders = unwrapBuyerList<Order>(res.data, ["orders"])
      const sortedOrders = fetchedOrders.sort((a, b) => {
        const dateA = new Date(a.createdAt || 0).getTime()
        const dateB = new Date(b.createdAt || 0).getTime()
        return dateB - dateA
      })
      setOrders(sortedOrders)
    } catch (err) {
      const anyErr = err as any
      const status = anyErr?.response?.status
      if (status === 404) {
        console.warn("Orders endpoint returned 404; treating as no orders")
        setOrders([])
        setError(null)
      } else if (!opts?.silent) {
        console.error("Failed to load orders", err)
        setError(getBuyerFetchError(err, "Failed to load orders. Please try again."))
      }
    } finally {
      if (!opts?.silent) setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchOrders()
  }, [fetchOrders])

  useEffect(() => {
    const onFocus = () => {
      void fetchOrders({ silent: true })
    }
    window.addEventListener("focus", onFocus)
    return () => window.removeEventListener("focus", onFocus)
  }, [fetchOrders])

  useEffect(() => {
    const needsPoll = orders.some((o) => {
      const rd = (o as OrderWithRider).riderDelivery
      return shouldPollOrderStatus(o.status, rd?.status, rd?.proofPhotoUrl)
    })
    if (!needsPoll) return
    const interval = setInterval(() => {
      void fetchOrders({ silent: true })
    }, 30_000)
    return () => clearInterval(interval)
  }, [orders, fetchOrders])

  const filteredOrders = filterOrdersByBuyerFilter(orders, activeTab)

  const setFilter = (key: BuyerOrderFilterKey) => {
    setActiveTab(key)
    const q = key === "all" ? "" : `?filter=${key}`
    router.replace(`/buyer/orders${q}`)
  }

  const orderRider = (order: Order) => (order as OrderWithRider).riderDelivery

  const statusLabel = (order: Order) => {
    const rd = orderRider(order)
    return formatOrderStatusLabel(
      getEffectiveOrderStatus(order.status, rd?.status, rd?.proofPhotoUrl),
    )
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  // Helper to parse variation from string (backend stores as JSON or Python dict)
  const parseVariation = (variation: any): { color?: string; size?: string } | null => {
    if (!variation) return null
    if (typeof variation === "object") {
      return { color: variation.color, size: variation.size }
    }
    if (typeof variation === "string") {
      // Try JSON first (double quotes)
      try {
        const parsed = JSON.parse(variation)
        return { color: parsed?.color, size: parsed?.size }
      } catch {
        // Fallback: Parse Python dict string (single quotes)
        try {
          const jsonLike = variation.replace(/'/g, '"')
          const parsed = JSON.parse(jsonLike)
          return { color: parsed?.color, size: parsed?.size }
        } catch {
          // Last resort: manual extraction with regex
          const colorMatch = variation.match(/['"]color['"]\s*:\s*['"]([^'"]+)/)
          const sizeMatch = variation.match(/['"]size['"]\s*:\s*['"]([^'"]+)/)
          if (colorMatch || sizeMatch) {
            return {
              color: colorMatch?.[1] || undefined,
              size: sizeMatch?.[1] || undefined,
            }
          }
        }
      }
    }
    return null
  }

  const handleConfirmReceived = async (orderId: string) => {
    try {
      const result = await Swal.fire({
        title: "Confirm Received?",
        text: "Are you sure you have received this order?",
        icon: "question",
        showCancelButton: true,
        confirmButtonText: "Yes, I received it",
        cancelButtonText: "Cancel",
        confirmButtonColor: "#22c55e",
      })

      if (!result.isConfirmed) return

      const res = await ordersApi.confirmReceived(orderId)
      const updated = (res.data as any)?.order

      if (updated && updated.id != null && updated.status) {
        const normalizedStatus = String(updated.status).toLowerCase()
        setOrders((prev) =>
          prev.map((o) => (String(o.id) === String(updated.id) ? { ...o, status: normalizedStatus as any } : o)),
        )
        await Swal.fire({
          title: "Order received!",
          text: "Taking you to rate your order…",
          icon: "success",
          timer: 1400,
          showConfirmButton: false,
        })
        window.location.href = `/orders/${updated.id}?review=1`
      }
    } catch (err: any) {
      console.error("Failed to confirm order receipt", err)
      const errorMessage = err?.response?.data?.message || err?.message || "Failed to confirm receipt. Please try again."
      await Swal.fire({
        title: "Error",
        text: errorMessage,
        icon: "error",
      })
    }
  }

  const handleRequestRefund = async (orderId: string) => {
    const { value: reason, isConfirmed } = await Swal.fire({
      title: "Request refund",
      input: "textarea",
      inputPlaceholder: "Reason (optional)",
      showCancelButton: true,
      confirmButtonText: "Submit",
    })
    if (!isConfirmed) return
    try {
      await ordersApi.requestRefund(orderId, reason ?? "")
      await Swal.fire({
        title: "Refund requested",
        text: "View status under Refunds in your account menu.",
        icon: "success",
        timer: 2000,
        showConfirmButton: false,
      })
    } catch (err) {
      console.error("Failed to request refund", err)
      await Swal.fire({ title: "Error", text: "Could not submit refund request.", icon: "error" })
    }
  }

  const handleCancelOrder = async (orderId: string) => {
    const result = await Swal.fire({
      title: "Cancel order?",
      text: "This cannot be undone.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#dc2626",
      confirmButtonText: "Cancel order",
    })
    if (!result.isConfirmed) return
    try {
      await ordersApi.cancel(orderId)
      setOrders((prev) =>
        prev.map((o) => (String(o.id) === String(orderId) ? { ...o, status: "cancelled" as const } : o)),
      )
      await Swal.fire({ title: "Order cancelled", icon: "success", timer: 1500, showConfirmButton: false })
    } catch (err: any) {
      await Swal.fire({
        title: "Error",
        text: err?.response?.data?.msg ?? "Could not cancel order.",
        icon: "error",
      })
    }
  }

  const { isBusy, openBuyerOrder } = useChatOpen()

  const handleMessageSeller = async (order: OrderWithRider) => {
    const orderId = parseInt(String(order.id), 10)
    const storeId = resolveStoreIdFromOrder(order)
    if (!storeId) {
      await Swal.fire({
        title: "Chat unavailable",
        text: "Store not available for this order.",
        icon: "info",
      })
      return
    }
    const first = order.items[0]
    const busyKey = `buyer-order-${order.id}`
    await openBuyerOrder(busyKey, {
      orderId,
      storeId,
      productName: first?.product?.name ?? order.orderNumber,
      productImageUrl: first?.product?.imageUrl ?? first?.product?.image_url,
      status: order.status,
      totalAmount: order.total,
      displayId: order.orderNumber,
    })
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-2">
        <div>
          <h1 className="text-3xl font-bold mb-2">My Orders</h1>
          <p className="text-muted-foreground">Track and manage your orders.</p>
        </div>
        <Link
          href="/buyer/refunds"
          className="inline-flex items-center gap-2 text-sm px-3 py-1.5 rounded-full border bg-background hover:bg-muted transition-colors"
        >
          <Icon name="receipt-alt" className="w-4 h-4" />
          <span>View refunds</span>
        </Link>
      </div>

      {buyerUnverified && <BuyerVerificationBanner />}

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading orders...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {BUYER_ORDER_FILTERS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setFilter(tab.key)}
            className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
              activeTab === tab.key ? "bg-primary text-primary-foreground" : "bg-muted hover:bg-muted/80"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Orders List */}
      {!isLoading && !error && (
      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          className="space-y-4"
        >
          {filteredOrders.length === 0 ? (
            <div className="bg-card border rounded-2xl p-12 text-center">
              <Icon name="shopping-bag" size="xl" className="mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No orders found</h3>
              <p className="text-muted-foreground mb-4">
                {buyerUnverified
                  ? "Your account is not yet verified. Please wait for admin approval before placing orders."
                  : `You don't have any orders in this filter yet.`}
              </p>
              <Link
                href="/search"
                className="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
              >
                Start Shopping
              </Link>
            </div>
          ) : (
            filteredOrders.map((order) => (
              <div key={order.id} className="bg-card border rounded-2xl overflow-hidden">
                <div className="p-4 border-b flex flex-wrap items-center justify-between gap-4 bg-muted/30">
                  <div className="flex items-center gap-4">
                    <span className="font-semibold">{order.orderNumber}</span>
                    <span
                      className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${
                        orderStatusBadgeClass(
                          getEffectiveOrderStatus(
                            order.status,
                            orderRider(order)?.status,
                            orderRider(order)?.proofPhotoUrl,
                          ),
                        )
                      }`}
                    >
                      {statusLabel(order)}
                    </span>
                  </div>
                  <span className="text-sm text-muted-foreground">
                    {new Date(order.createdAt).toLocaleDateString("en-PH", {
                      month: "long",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </span>
                </div>

                <div className="p-4 space-y-4">
                  {order.items.map((item, index) => {
                    const img = resolveImageUrl(item.product.imageUrl || item.product.image_url || item.product.images?.[0]) || "/placeholder.svg"
                    const variation = parseVariation(item.variation)
                    const orderStore = (order as OrderWithRider).store
                    const storeId =
                      item.sellerId ??
                      item.product?.sellerId ??
                      orderStore?.id ??
                      order.seller?.id
                    const storeName =
                      item.sellerName ||
                      item.product?.sellerName ||
                      orderStore?.name ||
                      order.seller?.shopName
                    return (
                      <div key={index} className="flex gap-4">
                        <div className="relative w-20 h-20 rounded-xl overflow-hidden bg-muted flex-shrink-0">
                          <Image
                            src={img}
                            alt={item.product.name}
                            fill
                            className="object-cover"
                          />
                        </div>
                      <div className="flex-1 min-w-0">
                        <Link
                          href={`/product/${item.product.slug}`}
                          className="font-medium hover:text-primary transition-colors line-clamp-1"
                        >
                          {item.product.name}
                        </Link>
                        {/* Shop Name */}
                        {storeName && (
                          <p className="text-xs text-primary font-medium flex items-center gap-1">
                            <Icon name="store" className="w-3 h-3 shrink-0" />
                            <StoreNameLink
                              storeId={storeId}
                              storeName={storeName}
                              className="text-xs font-medium"
                            />
                          </p>
                        )}
                        {variation && (variation.color || variation.size) && (
                          <p className="text-sm text-muted-foreground">
                            {variation.color && variation.size 
                              ? `${variation.color} / ${variation.size}`
                              : variation.color || variation.size}
                          </p>
                        )}
                        <p className="text-sm text-muted-foreground">Qty: {item.quantity}</p>
                      </div>
                        <div className="text-right">
                          <p className="font-semibold">
                            {formatPrice((item.product.salePrice || item.product.price) * item.quantity)}
                          </p>
                        </div>
                      </div>
                    )
                  })}
                </div>

                <div className="p-4 border-t flex flex-wrap items-center justify-between gap-4 bg-muted/30">
                  <div className="text-sm">
                    <div className="flex gap-4 text-muted-foreground">
                      <span>Subtotal: {formatPrice(order.subtotal || 0)}</span>
                      <span>Shipping: {order.shipping === 0 ? "Free" : formatPrice(order.shipping || 0)}</span>
                    </div>
                    <div className="mt-1">
                      <span className="text-muted-foreground">Total: </span>
                      <span className="font-bold text-lg text-primary">{formatPrice(order.total || 0)}</span>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {["pending", "processing"].includes(
                      getEffectiveOrderStatus(
                        order.status,
                        orderRider(order)?.status,
                        orderRider(order)?.proofPhotoUrl,
                      ),
                    ) && (
                      <button
                        type="button"
                        className="px-4 py-2 border border-destructive/40 text-destructive rounded-xl text-sm font-medium hover:bg-destructive/10"
                        onClick={() => void handleCancelOrder(order.id)}
                      >
                        Cancel
                      </button>
                    )}
                    {canMessageSellerForBuyerOrder(order as OrderWithRider) && (
                      <button
                        type="button"
                        disabled={isBusy(`buyer-order-${order.id}`)}
                        className="px-4 py-2 border rounded-xl text-sm font-medium hover:bg-muted transition-colors flex items-center gap-2 disabled:opacity-60 disabled:pointer-events-none"
                        onClick={() => void handleMessageSeller(order as OrderWithRider)}
                      >
                        {isBusy(`buyer-order-${order.id}`) ? (
                          <>
                            <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
                            Opening chat…
                          </>
                        ) : (
                          <>
                            <Icon name="comments" size="sm" />
                            Message seller
                          </>
                        )}
                      </button>
                    )}
                    {canBuyerConfirmReceipt(
                      order.status,
                      orderRider(order)?.status,
                      orderRider(order)?.proofPhotoUrl,
                    ) && (
                      <button
                        className="px-4 py-2 bg-green-600 text-white rounded-xl text-sm font-medium hover:bg-green-700 transition-colors flex items-center gap-2"
                        onClick={() => void handleConfirmReceived(order.id)}
                      >
                        <Icon name="check" size="sm" />
                        Confirm Received
                      </button>
                    )}
                    {isOrderDelivered(
                      order.status,
                      orderRider(order)?.status,
                      orderRider(order)?.proofPhotoUrl,
                    ) && (
                      <button
                        className="px-4 py-2 border rounded-xl text-sm font-medium hover:bg-muted transition-colors"
                        onClick={() => void handleRequestRefund(order.id)}
                      >
                        Request Refund
                      </button>
                    )}
                    {(() => {
                      const o = order as OrderWithRider
                      const storeId =
                        o.store?.id ??
                        o.items[0]?.sellerId ??
                        o.items[0]?.product?.sellerId
                      return storeId ? (
                        <ReportLinkButton
                          reporterRole="buyer"
                          params={{
                            targetRole: "seller",
                            storeId,
                            orderId: order.id,
                            label: o.store?.name ?? o.items[0]?.sellerName,
                          }}
                        >
                          Report store
                        </ReportLinkButton>
                      ) : null
                    })()}
                    {orderRider(order)?.rider?.id != null && (
                      <ReportLinkButton
                        reporterRole="buyer"
                        params={{
                          targetRole: "rider",
                          targetUserId: orderRider(order)!.rider!.id,
                          orderId: order.id,
                          label: orderRider(order)?.rider?.name ?? undefined,
                        }}
                      >
                        Report rider
                      </ReportLinkButton>
                    )}
                    <Link
                      href={`/orders/${order.id}`}
                      className="px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:bg-primary/90 transition-colors"
                    >
                      View Details
                    </Link>
                  </div>
                </div>
              </div>
            ))
          )}
        </motion.div>
      </AnimatePresence>
      )}
    </div>
  )
}

export default function BuyerOrdersPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center py-16 text-muted-foreground">Loading orders…</div>
      }
    >
      <BuyerOrdersContent />
    </Suspense>
  )
}
