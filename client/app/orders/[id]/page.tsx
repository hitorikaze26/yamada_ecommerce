"use client"
import React, { Suspense, useEffect, useState } from "react"
import Link from "next/link"
import Image from "next/image"
import { useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"
import { useRouter } from "next/navigation"
import { ordersApi, resolveImageUrl } from "@/lib/api"
import { resolveStoreIdFromOrder } from "@/lib/buyer/order-chat"
import { canMessageSellerForBuyerOrder } from "@/lib/chat/navigation"
import { useChatOpen } from "@/hooks/use-chat-open"
import Swal from "sweetalert2"
import "sweetalert2/dist/sweetalert2.min.css"
import { OrderReviewSection } from "@/components/order/order-review-section"
import { StoreNameLink } from "@/components/store/store-name-link"
import type { ReviewableItem, ProductReviewPayload } from "@/lib/review-types"
import { ReportLinkButton } from "@/components/report/report-link-button"
import {
  ORDER_TRACKING_STEPS,
  canBuyerConfirmReceipt,
  formatOrderStatusLabel,
  getEffectiveOrderStatus,
  getOrderTimelineIndex,
  isOrderDelivered,
  orderStatusBadgeClass,
  normalizeOrderStatus,
  riderHasProofOfDelivery,
  shouldPollOrderStatus,
} from "@/lib/buyer/order-status"
import { formatPrice } from "@/lib/format"

interface OrderItemDetail {
  id: number
  productId: number
  quantity: number
  unitPrice: number
  sellerId?: number | null
  sellerName?: string | null
  variation: {
    color?: string
    size?: string
  } | null
  product?: {
    id: number
    name: string
    price: number
    imageUrl?: string | null
  } | null
}

interface RiderInfoDetail {
  id?: number
  name?: string | null
  email?: string | null
  contactNumber?: string | null
  vehicleType?: string | null
  licenseNumber?: string | null
}

interface RiderDeliveryDetail {
  id?: number
  status: string
  rider?: RiderInfoDetail | null
  hasProofPhoto?: boolean
  proofPhotoUrl?: string | null
  proofNote?: string | null
}

interface OrderDetail {
  id: number
  status: string
  createdAt: string | null
  updatedAt: string | null
  subtotal: number
  shipping: number
  total: number
  paymentMethod: string | null
  shippingAddress: string | null
  storeId?: number | null
  storeName?: string | null
  items: OrderItemDetail[]
  riderDelivery?: RiderDeliveryDetail | null
}

function formatRiderStatus(status: string): string {
  switch (status.toLowerCase()) {
    case "pending":
      return "Pending pickup"
    case "pickup":
      return "Picked up"
    case "transit":
      return "In transit"
    case "delivered":
      return "Delivered"
    case "cancelled":
      return "Cancelled"
    default:
      return status.replace(/_/g, " ")
  }
}

function riderStatusBadgeClass(status: string): string {
  switch (status.toLowerCase()) {
    case "delivered":
      return "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
    case "transit":
      return "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400"
    case "pickup":
      return "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400"
    case "cancelled":
      return "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
    default:
      return "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
  }
}

function OrderContent({ orderId }: { orderId: string }) {
  const router = useRouter()
  const { isBusy, openBuyerOrder } = useChatOpen()
  const searchParams = useSearchParams()
  const isSuccess = searchParams.get("success") === "true"
  const openReview = searchParams.get("review") === "1"

  const [order, setOrder] = useState<OrderDetail | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [reviewableItems, setReviewableItems] = useState<ReviewableItem[]>([])
  const [submittedReviewItemIds, setSubmittedReviewItemIds] = useState<Set<number>>(new Set())
  const [deliveryPillOptions, setDeliveryPillOptions] = useState<string[]>([])
  const [orderDetailImageErrors, setOrderDetailImageErrors] = useState<Record<string, boolean>>({})

  const loadOrder = React.useCallback(async (opts?: { silent?: boolean }) => {
      if (!opts?.silent) {
        setIsLoading(true)
        setError(null)
      }
      try {
        const res = await ordersApi.getById(String(orderId))
        const raw = (res.data as any)?.order as any

        if (!raw) {
          setOrder(null)
          setError("Order not found")
          return
        }

        const items: OrderItemDetail[] = Array.isArray(raw.items)
          ? raw.items.map((it: any) => {
              let variation: { color?: string; size?: string } | null = null

              if (it?.variation) {
                if (typeof it.variation === "object") {
                  variation = {
                    color: it.variation.color,
                    size: it.variation.size,
                  }
                } else if (typeof it.variation === "string") {
                  // Try JSON first (double quotes)
                  try {
                    const parsed = JSON.parse(it.variation)
                    variation = {
                      color: parsed?.color,
                      size: parsed?.size,
                    }
                  } catch {
                    // Fallback: Parse Python dict string (single quotes)
                    try {
                      // Replace single quotes with double quotes for JSON parsing
                      // Handle cases like "{'color': 'Red', 'size': 'M'}"
                      const jsonLike = it.variation
                        .replace(/'/g, '"')
                        .replace(/"\s*:\s*"([^"]*)"\s*,?\s*"\s*:\s*"([^"]*)"/g, '"$1": "$2"')
                      const parsed = JSON.parse(jsonLike)
                      variation = {
                        color: parsed?.color,
                        size: parsed?.size,
                      }
                    } catch {
                      // Last resort: manual extraction with regex
                      const colorMatch = it.variation.match(/['"]color['"]\s*:\s*['"]([^'"]+)/)
                      const sizeMatch = it.variation.match(/['"]size['"]\s*:\s*['"]([^'"]+)/)
                      if (colorMatch || sizeMatch) {
                        variation = {
                          color: colorMatch?.[1] || undefined,
                          size: sizeMatch?.[1] || undefined,
                        }
                      }
                    }
                  }
                }
              }

              return {
                id: Number(it.id ?? 0),
                productId: Number(it.productId ?? 0),
                quantity: Number(it.quantity ?? 0),
                unitPrice: Number(it.unitPrice ?? 0),
                sellerId: it.sellerId != null ? Number(it.sellerId) : null,
                sellerName: it.sellerName != null ? String(it.sellerName) : null,
                variation,
                product: it.product
                  ? {
                      id: Number(it.product.id ?? 0),
                      name: String(it.product.name ?? ""),
                      price: Number(it.product.price ?? 0),
                      imageUrl:
                        resolveImageUrl(it.product.imageUrl ?? it.product.image_url) ?? null,
                    }
                  : null,
              }
            })
          : []

        const subtotal = Number(raw.subtotal ?? raw.total_amount ?? 0)
        const shipping = Number(raw.shipping ?? raw.shippingFee ?? 0)
        const total = Number(raw.total ?? raw.grandTotal ?? (subtotal + shipping))

        const rawStore = raw.store as { id?: number; name?: string } | null | undefined

        const mapped: OrderDetail = {
          id: Number(raw.id ?? orderId),
          status: String(raw.status ?? ""),
          createdAt: raw.createdAt ?? null,
          updatedAt: raw.updatedAt ?? null,
          subtotal,
          shipping,
          total,
          paymentMethod: raw.paymentMethod ?? null,
          shippingAddress: raw.shippingAddress ?? null,
          storeId: rawStore?.id != null ? Number(rawStore.id) : null,
          storeName: rawStore?.name != null ? String(rawStore.name) : null,
          items,
          riderDelivery: (() => {
            const rd = raw.riderDelivery ?? raw.rider_delivery
            if (!rd) return null
            const riderRaw = rd.rider
            const rider = riderRaw
              ? {
                  id: riderRaw.id != null ? Number(riderRaw.id) : undefined,
                  name: riderRaw.name ?? null,
                  email: riderRaw.email ?? null,
                  contactNumber: riderRaw.contactNumber ?? riderRaw.contact_number ?? null,
                  vehicleType: riderRaw.vehicleType ?? riderRaw.vehicle_type ?? null,
                  licenseNumber: riderRaw.licenseNumber ?? riderRaw.license_number ?? null,
                }
              : null
            const proofPath = rd.proofPhotoUrl ?? rd.proof_photo_url ?? null
            const hasProofPhoto = Boolean(rd.hasProofPhoto ?? rd.has_proof_photo) || Boolean(proofPath)
            return {
              id: rd.id != null ? Number(rd.id) : undefined,
              status: String(rd.status ?? ""),
              rider,
              hasProofPhoto,
              proofPhotoUrl: resolveImageUrl(proofPath) ?? null,
              proofNote: rd.proofNote ?? rd.proof_note ?? null,
            }
          })(),
        }

        setOrder(mapped)
      } catch (err: any) {
        console.error("Failed to load order", err)
        if (err.response?.status === 404) {
          setError("Order not found. It may have been deleted or you don't have permission to view it.")
        } else if (err.response?.status === 401) {
          setError("Please log in to view this order.")
        } else {
          setError(err.response?.data?.msg || "Failed to load order details.")
        }
      } finally {
        if (!opts?.silent) setIsLoading(false)
      }
  }, [orderId])

  useEffect(() => {
    void loadOrder()
  }, [loadOrder])

  useEffect(() => {
    if (
      !order ||
      !shouldPollOrderStatus(
        order.status,
        order.riderDelivery?.status,
        order.riderDelivery?.proofPhotoUrl,
      )
    )
      return
    const interval = setInterval(() => {
      void loadOrder({ silent: true })
    }, 30_000)
    return () => clearInterval(interval)
  }, [order?.status, order?.riderDelivery?.status, loadOrder])

  useEffect(() => {
    if (!order || String(order.status).toLowerCase() !== "completed") {
      setReviewableItems([])
      setSubmittedReviewItemIds(new Set())
      return
    }
    const loadReviews = async () => {
      try {
        const res = await ordersApi.getOrderReviews(Number(order.id))
        const data = res.data as {
          reviews?: { orderItemId?: number }[]
          reviewableItems?: ReviewableItem[]
          deliveryPillOptions?: string[]
        }
        const submitted = new Set(
          (data.reviews ?? [])
            .map((r) => r.orderItemId)
            .filter((id): id is number => id != null),
        )
        setSubmittedReviewItemIds(submitted)
        setReviewableItems(data.reviewableItems ?? [])
        setDeliveryPillOptions(data.deliveryPillOptions ?? [])
      } catch {
        setReviewableItems([])
      }
    }
    void loadReviews()
  }, [order?.id, order?.status])

  const effectiveStatus = order
    ? getEffectiveOrderStatus(
        order.status,
        order.riderDelivery?.status,
        order.riderDelivery?.proofPhotoUrl,
        order.riderDelivery?.hasProofPhoto,
      )
    : ""
  const showConfirmReceived = order
    ? canBuyerConfirmReceipt(
        order.status,
        order.riderDelivery?.status,
        order.riderDelivery?.proofPhotoUrl,
        order.riderDelivery?.hasProofPhoto,
      )
    : false
  const showProofInRiderCard =
    order &&
    (riderHasProofOfDelivery(order.riderDelivery) ||
      normalizeOrderStatus(order.riderDelivery?.status ?? "") === "delivered")
  const currentStatusIndex = order ? getOrderTimelineIndex(effectiveStatus) : -1
  const displayStatus = order ? formatOrderStatusLabel(effectiveStatus) : "Unknown"
  const normalizedOrderStatus = effectiveStatus
  const showDeliverySection =
    order &&
    (order.riderDelivery?.rider ||
      riderHasProofOfDelivery(order.riderDelivery) ||
      normalizedOrderStatus === "out_for_delivery" ||
      normalizedOrderStatus === "shipped" ||
      normalizedOrderStatus === "delivered" ||
      normalizedOrderStatus === "completed")

  const getShippingAddressParts = (
    raw: string | null,
  ): { label: string; value: string }[] => {
    if (!raw) return []

    // If backend sends JSON string (e.g. checkout payload), try to parse it
    try {
      const parsed = typeof raw === "string" ? JSON.parse(raw) : raw

      if (parsed && typeof parsed === "object") {
        const {
          streetAddress,
          barangayName,
          municipalityName,
          provinceName,
          regionName,
          postalCode,
        } = parsed as any

        const parts: { label: string; value: string }[] = []

        const street = [streetAddress].filter(Boolean).join(", ")
        if (street) parts.push({ label: "Street", value: street })

        const city = [barangayName, municipalityName].filter(Boolean).join(", ")
        if (city) parts.push({ label: "City", value: city })

        const region = [provinceName, regionName].filter(Boolean).join(", ")
        if (region) parts.push({ label: "Region", value: region })

        if (postalCode) parts.push({ label: "Postal Code", value: String(postalCode) })

        return parts
      }
    } catch {
      // fall through to string parsing fallback below
    }

    // Fallback: raw is likely a Python-style dict string. Extract only readable fields.
    const source = String(raw)
    const cleaned = source.replace(/[{}']/g, "")
    const segments = cleaned.split(",").map((s) => s.trim())

    const extract = (key: string): string | undefined => {
      const seg = segments.find((s) => s.toLowerCase().startsWith(`${key.toLowerCase()}:`))
      if (!seg) return undefined
      return seg.split(":").slice(1).join(":").trim()
    }

    const streetAddress = extract("streetAddress")
    const barangayName = extract("barangayName")
    const municipalityName = extract("municipalityName")
    const provinceName = extract("provinceName")
    const regionName = extract("regionName")
    const postalCode = extract("postalCode")

    const parts: { label: string; value: string }[] = []

    if (streetAddress) {
      parts.push({ label: "Street", value: streetAddress })
    }

    const city = [barangayName, municipalityName].filter(Boolean).join(", ")
    if (city) {
      parts.push({ label: "City", value: city })
    }

    const region = [provinceName, regionName].filter(Boolean).join(", ")
    if (region) {
      parts.push({ label: "Region", value: region })
    }

    if (postalCode) {
      parts.push({ label: "Postal Code", value: postalCode })
    }

    if (parts.length > 0) {
      return parts
    }

    // Last resort: show cleaned-up raw string in a single line
    return [
      {
        label: "Address",
        value: cleaned,
      },
    ]
  }

  const handleSubmitReview = async (payload: ProductReviewPayload) => {
    if (!order) return
    await ordersApi.addReview(Number(order.id), payload)
    setSubmittedReviewItemIds((prev) => new Set([...prev, payload.orderItemId]))
    setReviewableItems((prev) => prev.filter((i) => i.orderItemId !== payload.orderItemId))
  }

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-8">
          {isLoading && (
            <div className="bg-card border rounded-2xl p-4 mb-6">Loading order...</div>
          )}

          {!isLoading && error && (
            <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 mb-6 text-sm">
              {error}
            </div>
          )}

          {!isLoading && !order && !error && (
            <div className="bg-card border rounded-2xl p-8 mb-6 text-center text-sm text-muted-foreground">
              Order not found.
            </div>
          )}

          {!isLoading && order && (
            <div>
              {isSuccess && (
                <motion.div
                  initial={{ opacity: 0, y: -20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-2xl p-6 mb-8 text-center"
                >
                  <div className="w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center mx-auto mb-4">
                    <Icon name="check" size="xl" className="text-green-600 dark:text-green-400" />
                  </div>
                  <h2 className="text-2xl font-bold text-green-800 dark:text-green-200 mb-2">Order Placed Successfully!</h2>
                  <p className="text-green-700 dark:text-green-300">
                    Thank you for your order. You will receive an email confirmation shortly.
                  </p>
                </motion.div>
              )}

              <div className="grid lg:grid-cols-3 gap-8">
                <div className="lg:col-span-2 space-y-6">
                  <div className="bg-card border rounded-2xl p-6">
                    <div className="flex flex-wrap items-center justify-between gap-4 mb-6">
                      <div>
                        <p className="text-sm text-muted-foreground">Order ID</p>
                        <div className="flex items-center gap-3">
                          <h1 className="text-2xl font-bold">{order.id}</h1>
                          <span
                            className={`px-2.5 py-1 rounded-full text-xs font-semibold ${orderStatusBadgeClass(effectiveStatus)}`}
                          >
                            {displayStatus}
                          </span>
                        </div>
                        {order.storeName && (
                          <p className="text-sm text-primary font-medium mt-2 flex items-center gap-1.5">
                            <Icon name="store" className="w-4 h-4 shrink-0" />
                            <StoreNameLink
                              storeId={order.storeId}
                              storeName={order.storeName}
                              className="text-sm font-medium"
                            />
                          </p>
                        )}
                      </div>
                      <div className="text-right">
                        <p className="text-sm text-muted-foreground">Placed on</p>
                        <p className="font-medium">
                          {order.createdAt
                            ? new Date(order.createdAt).toLocaleDateString("en-PH", {
                                year: "numeric",
                                month: "long",
                                day: "numeric",
                              })
                            : "-"}
                        </p>
                      </div>
                    </div>

                    {normalizedOrderStatus === "cancelled" || normalizedOrderStatus === "canceled" ? (
                      <p className="text-sm text-muted-foreground">This order was cancelled.</p>
                    ) : normalizedOrderStatus === "pending" ? (
                      <p className="text-sm text-muted-foreground">
                        Tracking updates after your order is confirmed for processing.
                      </p>
                    ) : currentStatusIndex >= 0 ? (
                      <div className="flex items-center justify-between gap-1">
                        {ORDER_TRACKING_STEPS.map((status, index) => (
                          <div key={status.key} className="flex-1 flex items-center min-w-0">
                            <div className="flex flex-col items-center min-w-0">
                              <div
                                className={`w-9 h-9 sm:w-10 sm:h-10 rounded-full flex items-center justify-center shrink-0 ${
                                  index <= currentStatusIndex
                                    ? "bg-primary text-primary-foreground"
                                    : "bg-muted text-muted-foreground"
                                }`}
                              >
                                <Icon name={status.icon} />
                              </div>
                              <span
                                className={`text-[10px] sm:text-xs mt-2 text-center leading-tight px-0.5 ${
                                  index <= currentStatusIndex
                                    ? "text-primary font-medium"
                                    : "text-muted-foreground"
                                }`}
                              >
                                {status.label}
                              </span>
                            </div>
                            {index < ORDER_TRACKING_STEPS.length - 1 && (
                              <div
                                className={`flex-1 h-1 mx-1 sm:mx-2 rounded min-w-[8px] ${
                                  index < currentStatusIndex ? "bg-primary" : "bg-muted"
                                }`}
                              />
                            )}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-sm text-muted-foreground">Status: {displayStatus}</p>
                    )}
                    {normalizedOrderStatus === "out_for_delivery" && (
                      <p className="mt-4 text-sm text-purple-700 dark:text-purple-300 bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-xl px-4 py-3 flex items-start gap-2">
                        <Icon name="motorcycle" className="shrink-0 mt-0.5" />
                        <span>
                          Your order is on the way. A rider may contact you before delivery. This page
                          refreshes automatically for status updates.
                        </span>
                      </p>
                    )}
                    {showConfirmReceived && (
                      <div className="mt-6 rounded-2xl border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 p-5">
                        <p className="text-sm text-green-800 dark:text-green-200">
                          Your package has been delivered. Please confirm when you have received all
                          items in good condition. After confirming, you can leave a review below.
                        </p>
                        <button
                          type="button"
                          className="mt-4 w-full sm:w-auto px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-xl font-semibold flex items-center justify-center gap-2"
                          onClick={async () => {
                            const r = await Swal.fire({
                              title: "Confirm Received?",
                              text: "Have you received all items in good condition?",
                              icon: "question",
                              showCancelButton: true,
                              confirmButtonText: "Yes, I received it",
                              confirmButtonColor: "#16a34a",
                            })
                            if (!r.isConfirmed) return
                            try {
                              await ordersApi.confirmReceived(String(order.id))
                              await Swal.fire({
                                icon: "success",
                                title: "Order received!",
                                text: "Thank you — you can share your feedback below.",
                                timer: 1600,
                                showConfirmButton: false,
                              })
                              router.replace(`/orders/${order.id}?review=1`)
                            } catch (e: unknown) {
                              const msg =
                                (e as { response?: { data?: { msg?: string } } })?.response?.data
                                  ?.msg ?? "Could not confirm receipt"
                              await Swal.fire({ icon: "error", title: msg })
                            }
                          }}
                        >
                          <Icon name="check-circle" />
                          Confirm Received
                        </button>
                      </div>
                    )}
                  </div>

                  <div className="bg-card border rounded-2xl p-6">
                    <h2 className="text-xl font-semibold mb-4">Order Items</h2>
                    <div className="space-y-4">
                      {order.items.map((item, index) => {
                        const img = resolveImageUrl(item.product?.imageUrl) || "/placeholder.svg"
                        const storeId = item.sellerId ?? order.storeId
                        const storeName = item.sellerName ?? order.storeName
                        return (
                          <div key={item.id ?? index} className="flex gap-4 items-center">
                            <div className="relative w-16 h-16 sm:w-24 sm:h-24 rounded-xl overflow-hidden bg-muted flex-shrink-0">
                              {orderDetailImageErrors[`${item.id}-${index}`] ? (
                                <div className="w-full h-full flex items-center justify-center bg-muted">
                                  <Icon name="image" className="text-muted-foreground/50" />
                                </div>
                              ) : (
                                <Image
                                  src={img}
                                  alt={item.product?.name ?? ""}
                                  fill
                                  className="object-cover"
                                  onError={() => setOrderDetailImageErrors((prev) => ({ ...prev, [`${item.id}-${index}`]: true }))}
                                />
                              )}
                            </div>
                          <div className="flex-1 min-w-0">
                            {item.product && (
                              <Link
                                href={`/product/${item.product.id}`}
                                className="font-medium hover:text-primary transition-colors line-clamp-2"
                              >
                                {item.product.name}
                              </Link>
                            )}
                            {storeName && (
                              <p className="text-xs text-primary font-medium flex items-center gap-1 mt-0.5">
                                <Icon name="store" className="w-3 h-3 shrink-0" />
                                <StoreNameLink
                                  storeId={storeId}
                                  storeName={storeName}
                                  className="text-xs font-medium"
                                />
                              </p>
                            )}
                            {item.variation && (
                              <p className="text-sm text-muted-foreground">
                                {item.variation.color} / {item.variation.size}
                              </p>
                            )}
                            <p className="text-sm text-muted-foreground">Qty: {item.quantity}</p>
                          </div>
                            <div className="text-right">
                              <p className="font-semibold">
                                {formatPrice((item.product?.price || 0) * item.quantity)}
                              </p>
                            </div>
                          </div>
                        )
                      })}
                    </div>

                    {String(order.status).toLowerCase() === "completed" &&
                      (reviewableItems.length > 0 || submittedReviewItemIds.size > 0) && (
                      <OrderReviewSection
                        orderId={Number(order.id)}
                        reviewableItems={reviewableItems}
                        submittedReviewItemIds={submittedReviewItemIds}
                        deliveryPillOptions={deliveryPillOptions}
                        onSubmit={handleSubmitReview}
                        highlight={openReview}
                      />
                    )}
                  </div>
                </div>

                <div className="space-y-6">
                  <div className="bg-card border rounded-2xl p-6">
                    <h2 className="text-xl font-semibold mb-4">Order Summary</h2>
                    <div className="space-y-3 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Subtotal</span>
                        <span>{formatPrice(order.subtotal)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Shipping</span>
                        <span className={order.shipping === 0 ? "text-green-600" : ""}>
                          {order.shipping === 0 ? "Free" : formatPrice(order.shipping)}
                        </span>
                      </div>
                      <div className="border-t pt-3 flex justify-between font-semibold text-lg">
                        <span>Total</span>
                        <span className="text-primary">{formatPrice(order.total)}</span>
                      </div>
                    </div>
                  </div>

                  <div className="bg-card border rounded-2xl p-6">
                    <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                      <Icon name="marker" className="text-primary" />
                      Shipping Address
                    </h2>
                    <div className="text-muted-foreground text-sm space-y-1">
                      {getShippingAddressParts(order.shippingAddress).map((part) => (
                        <p key={part.label} className="flex gap-1">
                          <span className="font-medium min-w-[90px]">{part.label}:</span>
                          <span className="flex-1">{part.value}</span>
                        </p>
                      ))}
                    </div>
                  </div>
                  {showDeliverySection && (
                    <div className="bg-card border rounded-2xl p-6">
                      <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                        <Icon name="truck-loading" className="text-primary" />
                        Delivery rider
                      </h2>
                      <div className="rounded-xl border bg-muted/20 overflow-hidden">
                        {!order.riderDelivery?.rider &&
                          (normalizedOrderStatus === "out_for_delivery" ||
                            normalizedOrderStatus === "shipped") && (
                          <div className="p-4 text-sm text-muted-foreground border-b">
                            {normalizedOrderStatus === "out_for_delivery"
                              ? "Your package is out for delivery. Rider details will appear here when assigned."
                              : "Preparing for delivery. Rider details will appear once assigned."}
                          </div>
                        )}
                        {order.riderDelivery?.rider && (
                          <div className="p-4 flex items-center gap-4 border-b">
                            <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                              <Icon name="user" className="text-primary" />
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="font-semibold text-sm truncate">
                                {order.riderDelivery.rider.name ||
                                  order.riderDelivery.rider.email ||
                                  "Assigned rider"}
                              </p>
                              {order.riderDelivery.rider.email && (
                                <p className="text-xs text-muted-foreground truncate">
                                  {order.riderDelivery.rider.email}
                                </p>
                              )}
                            </div>
                            {order.riderDelivery?.status && (
                              <span
                                className={`px-2.5 py-1 rounded-full text-xs font-medium capitalize shrink-0 ${riderStatusBadgeClass(order.riderDelivery.status)}`}
                              >
                                {formatRiderStatus(order.riderDelivery.status)}
                              </span>
                            )}
                          </div>
                        )}
                        {order.riderDelivery?.rider &&
                          (order.riderDelivery.rider.contactNumber ||
                            order.riderDelivery.rider.vehicleType ||
                            order.riderDelivery.rider.licenseNumber) && (
                          <div className="px-4 py-3 grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3 text-sm border-b">
                            {order.riderDelivery.rider.contactNumber && (
                              <div>
                                <p className="text-xs text-muted-foreground">Contact</p>
                                <p className="font-medium">{order.riderDelivery.rider.contactNumber}</p>
                              </div>
                            )}
                            {order.riderDelivery.rider.vehicleType && (
                              <div>
                                <p className="text-xs text-muted-foreground">Vehicle</p>
                                <p className="font-medium capitalize">
                                  {order.riderDelivery.rider.vehicleType}
                                </p>
                              </div>
                            )}
                            {order.riderDelivery.rider.licenseNumber && (
                              <div>
                                <p className="text-xs text-muted-foreground">License</p>
                                <p className="font-medium">{order.riderDelivery.rider.licenseNumber}</p>
                              </div>
                            )}
                          </div>
                        )}
                        {showProofInRiderCard && (
                          <div className="px-4 py-4 space-y-3 border-b">
                            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide flex items-center gap-2">
                              <Icon name="camera" className="text-primary" size="sm" />
                              Proof of delivery
                            </p>
                            {order.riderDelivery?.proofPhotoUrl ? (
                              <a
                                href={order.riderDelivery.proofPhotoUrl}
                                target="_blank"
                                rel="noreferrer"
                                className="block group max-w-sm"
                              >
                                <div className="relative rounded-xl overflow-hidden border bg-background">
                                  <img
                                    src={order.riderDelivery.proofPhotoUrl}
                                    alt="Proof of delivery"
                                    className="w-full h-44 object-cover group-hover:opacity-90 transition-opacity"
                                  />
                                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-black/20">
                                    <span className="text-white text-xs font-medium bg-black/50 px-2 py-1 rounded-full">
                                      View full photo
                                    </span>
                                  </div>
                                </div>
                              </a>
                            ) : (
                              <p className="text-sm text-muted-foreground">
                                Rider marked this delivery complete. Photo may still be processing.
                              </p>
                            )}
                            {order.riderDelivery?.proofNote && (
                              <p className="text-sm text-muted-foreground break-words">
                                <span className="font-medium text-foreground">Rider note: </span>
                                {order.riderDelivery.proofNote}
                              </p>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                  <div className="bg-card border rounded-2xl p-6">
                    <h2 className="text-xl font-semibold mb-4">Payment Method</h2>
                    <div className="flex items-center gap-2 text-sm">
                      <Icon name="money-bill-wave" className="text-green-600" />
                      <span>{order.paymentMethod ?? ""}</span>
                    </div>
                  </div>
                </div>
              </div>

              {order && (
                <div className="mt-6 flex flex-wrap gap-2">
                  {["pending", "processing"].includes(String(order.status).toLowerCase()) && (
                    <button
                      type="button"
                      className="px-4 py-2 border border-destructive/50 text-destructive rounded-xl text-sm font-medium hover:bg-destructive/10"
                      onClick={async () => {
                        const r = await Swal.fire({
                          title: "Cancel order?",
                          showCancelButton: true,
                          confirmButtonColor: "#dc2626",
                          confirmButtonText: "Cancel order",
                        })
                        if (!r.isConfirmed) return
                        try {
                          await ordersApi.cancel(String(order.id))
                          setOrder({ ...order, status: "cancelled" })
                          await Swal.fire({ icon: "success", title: "Order cancelled", timer: 1500, showConfirmButton: false })
                        } catch (e: any) {
                          await Swal.fire({ icon: "error", title: e?.response?.data?.msg ?? "Could not cancel" })
                        }
                      }}
                    >
                      Cancel order
                    </button>
                  )}
                  {canMessageSellerForBuyerOrder({
                    status: order.status,
                    store: order.storeId != null ? { id: order.storeId } : undefined,
                    items: order.items.map((it) => ({
                      sellerId: it.sellerId != null ? String(it.sellerId) : undefined,
                    })),
                  }) && (
                    <button
                      type="button"
                      disabled={isBusy(`buyer-order-detail-${order.id}`)}
                      className="px-4 py-2 border rounded-xl text-sm font-medium hover:bg-muted disabled:opacity-60 disabled:pointer-events-none inline-flex items-center gap-2"
                      onClick={async () => {
                        const storeId =
                          order.storeId ??
                          resolveStoreIdFromOrder({
                            items: order.items.map((it) => ({
                              sellerId: it.sellerId != null ? String(it.sellerId) : undefined,
                            })),
                          })
                        if (!storeId) {
                          await Swal.fire({ icon: "info", title: "Store not available for chat." })
                          return
                        }
                        const first = order.items[0]
                        await openBuyerOrder(`buyer-order-detail-${order.id}`, {
                          orderId: Number(order.id),
                          storeId,
                          productName: first?.product?.name ?? `Order #${order.id}`,
                          productImageUrl: first?.product?.imageUrl,
                          status: order.status,
                          totalAmount: order.total,
                          displayId: String(order.id),
                        })
                      }}
                    >
                      {isBusy(`buyer-order-detail-${order.id}`) ? (
                        <>
                          <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
                          Opening chat…
                        </>
                      ) : (
                        "Message seller"
                      )}
                    </button>
                  )}
                  {order.storeId != null && (
                    <ReportLinkButton
                      reporterRole="buyer"
                      params={{
                        targetRole: "seller",
                        storeId: order.storeId,
                        orderId: order.id,
                        label: order.storeName ?? undefined,
                      }}
                    >
                      Report store
                    </ReportLinkButton>
                  )}
                  {order.riderDelivery?.rider?.id != null && (
                    <ReportLinkButton
                      reporterRole="buyer"
                      params={{
                        targetRole: "rider",
                        targetUserId: order.riderDelivery.rider.id,
                        orderId: order.id,
                        label: order.riderDelivery.rider.name ?? undefined,
                      }}
                    >
                      Report rider
                    </ReportLinkButton>
                  )}
                  <Link href="/buyer/help" className="px-4 py-2 border rounded-xl text-sm font-medium hover:bg-muted inline-flex items-center">
                    Help
                  </Link>
                </div>
              )}

              <Link
                href="/buyer/orders"
                className="mt-4 flex items-center justify-center gap-2 w-full py-3 px-4 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
              >
                <Icon name="list" />
                View All Orders
              </Link>
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  )
}

export default function OrderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = React.use(params)
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading order…</div>}>
      <OrderContent orderId={String(id)} />
    </Suspense>
  )
}
