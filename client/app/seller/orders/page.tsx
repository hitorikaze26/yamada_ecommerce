"use client"
import { useEffect, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { useRouter } from "next/navigation"
import { sellerApi, resolveImageUrl } from "@/lib/api"
import { formatPrice } from "@/lib/format"
import { SellerOrderExpandedDetails } from "@/components/seller/seller-order-expanded-details"

const tabs = ["all", "pending", "processing", "shipped", "delivered", "cancelled"]

type SellerOrderItem = {
  product: {
    name: string
    images: string[]
    price: number
    salePrice?: number
  }
  quantity: number
  variation: {
    color?: string
    size?: string
  }
}

type SellerOrder = {
  id: string
  backendId: number
  date: string
  status: string
  customer: {
    name: string
    email: string
    address: string
    notes?: string | null
  }
  items: SellerOrderItem[]
  total: number
  paymentMethod: string
  riderDelivery?: {
    id: number
    status: string
    fee: number
    distanceKm?: number | null
    hasProofPhoto?: boolean
    proofPhotoUrl?: string | null
    proofNote?: string | null
    rider?: {
      id: number
      name: string
      email: string
      contactNumber?: string
      vehicleType?: string | null
      licenseNumber?: string | null
    } | null
  } | null
}

const statusColors: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  processing: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  shipped: "bg-sky-100 text-sky-700 dark:bg-sky-900/30 dark:text-sky-300",
  out_for_delivery: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
  delivered: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  completed: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  cancelled: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
}

const sellerOrderMatchesTab = (orderStatus: string, tab: string): boolean => {
  const s = orderStatus.toLowerCase()
  if (tab === "all") return true
  if (tab === "delivered") return s === "delivered" || s === "completed"
  if (tab === "shipped") return s === "shipped" || s === "out_for_delivery"
  return s === tab
}

const statusDisplayLabel = (status: string): string => {
  const key = status.toLowerCase()
  if (key === "shipped") {
    return "Ready for pickup"
  }
  if (key === "out_for_delivery") {
    return "Out for delivery"
  }
  if (key === "completed") {
    return "Completed"
  }
  return key.charAt(0).toUpperCase() + key.slice(1)
}

const getShippingFullName = (raw: string | null | undefined): string | null => {
  if (!raw) return null

  try {
    const parsed = JSON.parse(raw)
    if (parsed && typeof parsed === "object") {
      const obj = parsed as any
      return (
        obj.fullName ||
        obj.name ||
        [obj.firstName, obj.lastName].filter(Boolean).join(" ") ||
        obj.recipientName ||
        null
      )
    }
  } catch {
  }

  const source = String(raw)
  const cleaned = source.replace(/[{}']/g, "")
  const segments = cleaned.split(",").map((s) => s.trim())

  const extract = (key: string): string | null => {
    const seg = segments.find((s) => s.toLowerCase().startsWith(`${key.toLowerCase()}:`))
    if (!seg) return null
    const value = seg.split(":").slice(1).join(":").trim()
    return value || null
  }

  return (
    extract("fullName") ||
    extract("name") ||
    [extract("firstName"), extract("lastName")].filter(Boolean).join(" ") ||
    extract("recipientName") ||
    null
  )
}

export default function SellerOrdersPage() {
  const router = useRouter()
  const [activeTab, setActiveTab] = useState("all")
  const [orders, setOrders] = useState<SellerOrder[]>([])
  const [expandedOrderId, setExpandedOrderId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [statusError, setStatusError] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const [successVariant, setSuccessVariant] = useState<"success" | "warning">("success")

  useEffect(() => {
    const loadOrders = async () => {
      try {
        setIsLoading(true)
        setError(null)
        let sellerId = typeof window !== "undefined" ? localStorage.getItem("yamada-seller-id") : null

        if (!sellerId) {
          const profileRes = await sellerApi.getProfile()
          const sellerProfile = (profileRes.data as any)?.seller_profile

          if (sellerProfile?.id) {
            sellerId = String(sellerProfile.id)
            if (typeof window !== "undefined") {
              localStorage.setItem("yamada-seller-id", sellerId)
            }
          } else {
            setError("Seller ID not found. Please re-login as seller.")
            setIsLoading(false)
            return
          }
        }

        const res = await sellerApi.getOrders()
        const apiOrders = (res.data as any)?.orders || []

        const mapped: SellerOrder[] = apiOrders.map((o: any) => {
          const rawItems = Array.isArray(o.items) ? o.items : []

          const items: SellerOrderItem[] = rawItems.map((item: any) => {
            let variation: { color?: string; size?: string } = {}
            try {
              if (item.variation) {
                const parsed = JSON.parse(item.variation)
                if (parsed && typeof parsed === "object") {
                  variation = {
                    color: (parsed as any).color,
                    size: (parsed as any).size,
                  }
                }
              }
            } catch {
              variation = {}
            }

            const product = item.product || {}

            return {
              product: {
                name: product.name || "Unknown product",
                images: product.imageUrl ? [product.imageUrl] : [],
                price: Number(product.price ?? item.unitPrice ?? 0),
                salePrice: undefined,
              },
              quantity: Number(item.quantity ?? 1),
              variation,
            }
          })

          const rawStatus = (o.status || "PENDING") as string
          const normalizedStatus = rawStatus.toLowerCase()

          const buyer = o.buyer || {}
          const shippingFullName = getShippingFullName(o.shippingAddress)

          const primaryBuyerName =
            buyer.fullName ||
            buyer.full_name ||
            buyer.name ||
            [buyer.firstName, buyer.lastName].filter(Boolean).join(" ") ||
            [buyer.first_name, buyer.last_name].filter(Boolean).join(" ") ||
            buyer.username ||
            null

          const buyerName = shippingFullName || primaryBuyerName || "Customer"

          const buyerEmail = buyer.email || buyer.contactEmail || ""

          return {
            id: `ORD-${String(o.id).padStart(6, "0")}`,
            backendId: Number(o.id),
            date: o.createdAt || new Date().toISOString(),
            status: normalizedStatus,
            buyerId: buyer.id != null ? Number(buyer.id) : null,
            customer: {
              name: buyerName,
              email: buyerEmail,
              address: o.shippingAddress || "",
              notes: o.notes || o.orderNotes || null,
            },
            items,
            total: Number(o.total ?? o.total_amount ?? 0),
            paymentMethod: o.paymentMethod || "",
            riderDelivery: o.riderDelivery
              ? {
                  id: Number(o.riderDelivery.id),
                  status: (o.riderDelivery.status || "pending").toLowerCase(),
                  fee: Number(o.riderDelivery.fee ?? 0),
                  distanceKm: o.riderDelivery.distanceKm ?? null,
                  hasProofPhoto: Boolean(o.riderDelivery.hasProofPhoto) || Boolean(o.riderDelivery.proofPhotoUrl),
                  proofPhotoUrl: resolveImageUrl(o.riderDelivery.proofPhotoUrl) ?? null,
                  proofNote: o.riderDelivery.proofNote ?? null,
                  rider: o.riderDelivery.rider
                    ? {
                        id: Number(o.riderDelivery.rider.id),
                        name: o.riderDelivery.rider.name || o.riderDelivery.rider.email || "Rider",
                        email: o.riderDelivery.rider.email || "",
                        contactNumber: o.riderDelivery.rider.contactNumber || "",
                        vehicleType: o.riderDelivery.rider.vehicleType ?? null,
                        licenseNumber: o.riderDelivery.rider.licenseNumber ?? null,
                      }
                    : null,
                }
              : null,
          }
        })

        setOrders(mapped)
      } catch (err) {
        console.error("Failed to load orders", err)
        setError("Failed to load orders. Please try again later.")
      } finally {
        setIsLoading(false)
      }
    }

    void loadOrders()
  }, [])

  useEffect(() => {
    if (!successMessage) return

    const timer = setTimeout(() => {
      setSuccessMessage(null)
    }, 3500)

    return () => clearTimeout(timer)
  }, [successMessage])

  const filteredOrders = orders.filter((o) => sellerOrderMatchesTab(o.status, activeTab))

  const updateOrderStatus = async (orderId: string, newStatus: string) => {
    const target = orders.find((o) => o.id === orderId)
    if (!target) return

    const previousStatus = target.status

    // Optimistic UI update
    setOrders(orders.map((o) => (o.id === orderId ? { ...o, status: newStatus } : o)))

    try {
      await sellerApi.updateOrderStatus(target.backendId, newStatus)
    } catch (err) {
      console.error("Failed to update order status", err)
      setStatusError("Failed to update order status. Please try again.")
      // Revert on error
      setOrders(orders.map((o) => (o.id === orderId ? { ...o, status: previousStatus } : o)))
    }
  }

  return (
    <div className="space-y-6 relative">
      {successMessage && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          className={`fixed top-4 right-4 z-40 max-w-sm rounded-2xl border backdrop-blur-xl shadow-lg px-4 py-3 text-sm flex items-start gap-3
            ${successVariant === "success" ? "bg-emerald-50/60 dark:bg-emerald-900/20 border-emerald-300/70" : "bg-amber-50/60 dark:bg-amber-900/20 border-amber-300/70"}
          `}
        >
          <div
            className={`mt-0.5 rounded-full p-1.5 text-white
              ${successVariant === "success" ? "bg-emerald-500/90" : "bg-amber-500/90"}
            `}
          >
            <Icon name={successVariant === "success" ? "check" : "exclamation"} className="w-4 h-4" />
          </div>
          <div className="flex-1">
            <p className="font-medium text-foreground">
              {successVariant === "success" ? "Action completed" : "Action applied"}
            </p>
            <p className="text-xs text-muted-foreground">{successMessage}</p>
          </div>
          <button
            type="button"
            className="text-xs text-muted-foreground hover:text-foreground"
            onClick={() => setSuccessMessage(null)}
          >
            Dismiss
          </button>
        </motion.div>
      )}
      <div>
        <h1 className="text-3xl font-bold mb-2">Orders</h1>
        <p className="text-muted-foreground">Tap an order to view details and take action.</p>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4 text-sm text-muted-foreground">Loading orders...</div>
      )}

      {!isLoading && error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-2xl p-4 text-sm">{error}</div>
      )}

      {!isLoading && statusError && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-2xl p-4 text-sm flex items-center justify-between">
          <span>{statusError}</span>
          <button
            type="button"
            className="text-xs underline"
            onClick={() => setStatusError(null)}
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        {tabs.slice(1).map((tab) => {
          const count = orders.filter((o) => sellerOrderMatchesTab(o.status, tab)).length
          return (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`p-4 rounded-xl border text-left transition-colors ${
                activeTab === tab ? "border-primary bg-primary/5" : "hover:border-muted-foreground/30"
              }`}
            >
              <p className="text-2xl font-bold">{count}</p>
              <p className="text-sm text-muted-foreground">{statusDisplayLabel(tab)}</p>
            </button>
          )
        })}
      </div>

      {/* Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {tabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors ${
              activeTab === tab ? "bg-primary text-primary-foreground" : "bg-muted hover:bg-muted/80"
            }`}
          >
            {statusDisplayLabel(tab)}
          </button>
        ))}
      </div>

      {/* Orders List */}
      <div className="space-y-2">
        <AnimatePresence mode="wait">
          {filteredOrders.length === 0 ? (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="bg-card border rounded-2xl p-12 text-center"
            >
              <Icon name="inbox" size="xl" className="mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No {activeTab} orders</h3>
              <p className="text-muted-foreground">Orders with this status will appear here.</p>
            </motion.div>
          ) : (
            filteredOrders.map((order) => {
              const isExpanded = expandedOrderId === order.id
              const primaryProduct =
                order.items.length > 0 ? order.items[0].product.name : "Unknown product"

              return (
                <motion.div
                  key={order.id}
                  layout
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className={`bg-card border rounded-xl overflow-hidden transition-colors ${
                    isExpanded ? "border-primary/40 shadow-sm" : "hover:border-muted-foreground/30"
                  }`}
                >
                  <button
                    type="button"
                    className="w-full p-4 flex flex-wrap items-center gap-3 text-left hover:bg-muted/30 transition-colors"
                    onClick={() => setExpandedOrderId(isExpanded ? null : order.id)}
                    aria-expanded={isExpanded}
                  >
                    <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                      <Icon name="shopping-bag" className="text-primary" size="sm" />
                    </div>

                    <div className="flex-1 min-w-0">
                      <p className="font-semibold text-sm line-clamp-1">
                        {primaryProduct}
                        {order.items.length > 1 && (
                          <span className="text-muted-foreground font-normal">
                            {" "}
                            +{order.items.length - 1} more
                          </span>
                        )}
                      </p>
                      <p className="text-xs text-muted-foreground truncate">
                        {order.id} · {order.customer.name}
                      </p>
                    </div>

                    <div className="text-right shrink-0">
                      <p className="font-bold">{formatPrice(order.total)}</p>
                      <p className="text-xs text-muted-foreground">
                        {new Date(order.date).toLocaleDateString("en-PH", {
                          month: "short",
                          day: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </p>
                    </div>

                    <span
                      className={`inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium shrink-0 ${statusColors[order.status]}`}
                    >
                      {statusDisplayLabel(order.status)}
                    </span>

                    <Icon
                      name={isExpanded ? "chevron-up" : "chevron-down"}
                      className="text-muted-foreground shrink-0"
                      size="sm"
                    />
                  </button>

                  <AnimatePresence>
                    {isExpanded && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: "auto", opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                      >
                        <SellerOrderExpandedDetails
                          order={order}
                          formatPrice={formatPrice}
                          onUpdateStatus={async (orderId, newStatus) => {
                            await updateOrderStatus(orderId, newStatus)
                            setOrders((prev) =>
                              prev.map((o) => (o.id === orderId ? { ...o, status: newStatus } : o)),
                            )
                            setSuccessVariant(newStatus === "cancelled" ? "warning" : "success")
                            setSuccessMessage(
                              newStatus === "cancelled"
                                ? "Order cancelled successfully."
                                : newStatus === "processing"
                                  ? "Order accepted successfully."
                                  : newStatus === "shipped"
                                    ? "Order marked as ready for pickup."
                                    : "Order status updated successfully.",
                            )
                          }}
                        />
                      </motion.div>
                    )}
                  </AnimatePresence>
                </motion.div>
              )
            })
          )}
        </AnimatePresence>
      </div>
    </div>
  )
}
