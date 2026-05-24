"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { adminApi } from "@/lib/api"

const tabs = ["all", "pending", "processing", "shipped", "delivered", "cancelled"]

interface AdminOrderDto {
  id: number
  status: string
  total: number
  paymentMethod?: string | null
  createdAt: string | null
  buyer?: {
    id: number | null
    email: string | null
  }
}

interface AdminOrderItemDto {
  id: number
  productId: number
  quantity: number
  unitPrice: number
  variation?: string | null
  product?: {
    id: number
    name: string
    price: number
    imageUrl?: string | null
  } | null
}

interface AdminOrderDetailDto {
  id: number
  status: string
  total: number
  paymentMethod?: string | null
  shippingAddress?: string | null
  shippingAddressParts?: {
    streetAddress?: string | null
    barangayName?: string | null
    municipalityName?: string | null
    provinceName?: string | null
    regionName?: string | null
    postalCode?: string | null
  } | null
  createdAt: string | null
  updatedAt: string | null
  buyer?: {
    id: number | null
    email: string | null
  }
  store?: {
    id: number | null
    name?: string | null
    email?: string | null
  } | null
  riderDelivery?: {
    id: number
    status?: string | null
    rider?: {
      id?: number | null
      name?: string | null
      email?: string | null
    } | null
    proofPhotoUrl?: string | null
    proofNote?: string | null
  } | null
  items: AdminOrderItemDto[]
}

const statusColors: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  processing: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  shipped: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
  delivered: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  cancelled: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
}

const riderStatusColors: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  pickup: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  transit: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
  delivered: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  cancelled: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
}

export default function AdminOrdersPage() {
  const [activeTab, setActiveTab] = useState("all")
  const [orders, setOrders] = useState<AdminOrderDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedOrderId, setSelectedOrderId] = useState<number | null>(null)
  const [orderDetail, setOrderDetail] = useState<AdminOrderDetailDto | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState<string | null>(null)

  const handleOpenOrder = async (orderId: number) => {
    setSelectedOrderId(orderId)
    setOrderDetail(null)
    setDetailError(null)
    setDetailLoading(true)

    try {
      const res = await adminApi.getOrderById(orderId)
      const data: any = res.data
      const detail = (data?.order ?? data) as AdminOrderDetailDto
      setOrderDetail(detail)
    } catch (err: any) {
      console.error("Failed to load order detail", err)
      const status = err?.response?.status
      if (status === 404) {
        setDetailError("Order not found.")
      } else {
        setDetailError("Failed to load order details. Please try again.")
      }
    } finally {
      setDetailLoading(false)
    }
  }

  const handleCloseModal = () => {
    setSelectedOrderId(null)
    setOrderDetail(null)
    setDetailError(null)
  }

  useEffect(() => {
    const fetchOrders = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await adminApi.getOrders()
        setOrders((res.data.orders as AdminOrderDto[]) ?? [])
      } catch (err: unknown) {
        const status = (err as { response?: { status?: number } })?.response?.status
        if (status === 404) {
          setOrders([])
          setError(null)
        } else {
          console.error("Failed to load orders", err)
          const msg =
            (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
            "Failed to load orders. Please try again."
          setError(msg)
        }
      } finally {
        setIsLoading(false)
      }
    }

    void fetchOrders()
  }, [])

  const filteredOrders =
    activeTab === "all" ? orders : orders.filter((o) => o.status === activeTab)

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Orders</h1>
        <p className="text-muted-foreground">
          View and inspect orders. This currently shows orders for the authenticated account.
        </p>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading orders...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {/* Status filters */}
      <div className="bg-card border rounded-2xl p-4 flex flex-wrap gap-3 items-center justify-between">
        <div className="flex flex-wrap gap-2 overflow-x-auto">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-colors ${
                activeTab === tab ? "bg-primary text-primary-foreground" : "bg-muted hover:bg-muted/80"
              }`}
            >
              {tab}
            </button>
          ))}
        </div>
        <div className="text-sm text-muted-foreground">
          Total orders: <span className="font-semibold">{orders.length}</span>
        </div>
      </div>

      {/* Orders table */}
      {!isLoading && !error && (
        <div className="bg-card border rounded-2xl overflow-hidden">
          {filteredOrders.length === 0 ? (
            <div className="p-8 text-center">
              <Icon name="shopping-bag" size="xl" className="mx-auto text-muted-foreground mb-4" />
              <h2 className="text-lg font-semibold mb-1">No orders found</h2>
              <p className="text-sm text-muted-foreground">
                {activeTab === "all"
                  ? "There are no orders to display yet."
                  : `There are no ${activeTab} orders to display.`}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b bg-muted/30">
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Order ID</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Buyer</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Status</th>
                    <th className="text-left py-3 px-4 font-medium text-muted-foreground">Created</th>
                    <th className="text-right py-3 px-4 font-medium text-muted-foreground">Total</th>
                    <th className="text-right py-3 px-4 font-medium text-muted-foreground">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredOrders.map((order) => {
                    const buyerEmail = order.buyer?.email ?? "Unknown"
                    const buyerId = order.buyer?.id ?? null
                    const createdAtLabel = order.createdAt
                      ? new Date(order.createdAt).toLocaleDateString("en-PH", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })
                      : "-"

                    return (
                      <tr key={order.id} className="border-b last:border-0 hover:bg-muted/20">
                        <td className="py-3 px-4 font-medium">#{order.id}</td>
                        <td className="py-3 px-4">
                          <div className="flex flex-col">
                            <span className="font-medium text-xs break-all">{buyerEmail}</span>
                            <span className="text-[11px] text-muted-foreground">ID: {buyerId ?? "-"}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <span
                            className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${
                              statusColors[order.status] || "bg-muted text-muted-foreground"
                            }`}
                          >
                            {order.status}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-muted-foreground">{createdAtLabel}</td>
                        <td className="py-3 px-4 text-right font-semibold">{formatPrice(order.total)}</td>
                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-2">
                            <button
                              type="button"
                              onClick={() => void handleOpenOrder(order.id)}
                              className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-muted hover:bg-muted/80 transition-colors"
                            >
                              <Icon name="eye" size="sm" />
                              <span>View order</span>
                            </button>
                            {buyerId && (
                              <Link
                                href={`/admin/users?userId=${buyerId}`}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium border hover:bg-muted transition-colors"
                              >
                                <Icon name="user" size="sm" />
                                <span>Open buyer</span>
                              </Link>
                            )}
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* Order detail modal */}
      <AnimatePresence>
        {selectedOrderId !== null && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4"
            onClick={handleCloseModal}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-background rounded-2xl w-full max-w-3xl max-h-[90vh] overflow-y-auto p-6"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-xl font-semibold">Order #{selectedOrderId}</h2>
                  {orderDetail?.createdAt && (
                    <p className="text-xs text-muted-foreground">
                      Placed on{' '}
                      {new Date(orderDetail.createdAt).toLocaleString("en-PH", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </p>
                  )}
                </div>
                <button
                  type="button"
                  onClick={handleCloseModal}
                  className="w-9 h-9 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
                >
                  <Icon name="times" />
                </button>
              </div>

              {detailLoading && (
                <div className="text-sm text-muted-foreground">Loading order details...</div>
              )}

              {detailError && !detailLoading && (
                <div className="text-sm text-destructive mb-3">{detailError}</div>
              )}

              {!detailLoading && !detailError && orderDetail && (
                <div className="space-y-6">
                  {/* Summary */}
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
                    <div className="p-3 rounded-xl bg-muted/40 border">
                      <p className="text-xs text-muted-foreground mb-1">Buyer</p>
                      <p className="font-medium break-all">{orderDetail.buyer?.email ?? "Unknown"}</p>
                      {orderDetail.buyer?.id != null && (
                        <p className="text-[11px] text-muted-foreground">ID: {orderDetail.buyer.id}</p>
                      )}
                    </div>
                    <div className="p-3 rounded-xl bg-muted/40 border">
                      <p className="text-xs text-muted-foreground mb-1">Status</p>
                      <span
                        className={`inline-flex px-2 py-1 rounded-full text-xs font-medium capitalize ${
                          statusColors[orderDetail.status] || "bg-muted text-muted-foreground"
                        }`}
                      >
                        {orderDetail.status}
                      </span>
                      {orderDetail.paymentMethod && (
                        <p className="text-[11px] text-muted-foreground mt-1">
                          Payment: {orderDetail.paymentMethod}
                        </p>
                      )}
                    </div>
                    <div className="p-3 rounded-xl bg-muted/40 border text-right md:text-left">
                      <p className="text-xs text-muted-foreground mb-1">Total</p>
                      <p className="text-lg font-semibold">
                        {formatPrice(orderDetail.total ?? orderDetail.grandTotal ?? 0)}
                      </p>
                    </div>
                    <div className="p-3 rounded-xl bg-muted/40 border">
                      <p className="text-xs text-muted-foreground mb-1">Shop</p>
                      <p className="font-medium text-sm">
                        {orderDetail.store?.name || "Unknown shop"}
                      </p>
                      {orderDetail.store?.email && (
                        <p className="text-[11px] text-muted-foreground break-all">
                          {orderDetail.store.email}
                        </p>
                      )}
                    </div>
                  </div>

                  {/* Shipping address + Rider */}
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                    <div className="p-4 rounded-xl bg-muted/30 border">
                      <p className="font-medium mb-1">Shipping address</p>
                      {orderDetail.shippingAddressParts ? (
                        <div className="text-muted-foreground space-y-0.5">
                          {orderDetail.shippingAddressParts.streetAddress && (
                            <p>{orderDetail.shippingAddressParts.streetAddress}</p>
                          )}
                          <p>
                            {[orderDetail.shippingAddressParts.barangayName, orderDetail.shippingAddressParts.municipalityName]
                              .filter(Boolean)
                              .join(", ")}
                          </p>
                          <p>
                            {[orderDetail.shippingAddressParts.provinceName, orderDetail.shippingAddressParts.regionName]
                              .filter(Boolean)
                              .join(", ")}
                          </p>
                          {orderDetail.shippingAddressParts.postalCode && (
                            <p>Postal code: {orderDetail.shippingAddressParts.postalCode}</p>
                          )}
                        </div>
                      ) : (
                        <p className="text-muted-foreground whitespace-pre-line">
                          {orderDetail.shippingAddress || "No shipping address"}
                        </p>
                      )}
                    </div>

                    <div className="p-4 rounded-xl bg-muted/30 border">
                      <p className="font-medium mb-1">Rider & delivery</p>
                      {orderDetail.riderDelivery ? (
                        <div className="space-y-1 text-sm">
                          <div className="flex items-center gap-2 text-muted-foreground">
                            <span>Status:</span>
                            <span
                              className={`px-2 py-0.5 rounded-full text-[11px] font-medium capitalize ${
                                riderStatusColors[orderDetail.riderDelivery.status || "pending"] ||
                                "bg-muted text-muted-foreground"
                              }`}
                            >
                              {orderDetail.riderDelivery.status || "pending"}
                            </span>
                          </div>
                          {orderDetail.riderDelivery.rider ? (
                            <>
                              <p className="text-muted-foreground">
                                Rider:{" "}
                                <span className="font-medium">
                                  {orderDetail.riderDelivery.rider.name ||
                                    orderDetail.riderDelivery.rider.email ||
                                    `Rider #${orderDetail.riderDelivery.rider.id}`}
                                </span>
                              </p>
                              {orderDetail.riderDelivery.rider.id != null && (
                                <Link
                                  href={`/admin/riders?userId=${orderDetail.riderDelivery.rider.id}`}
                                  className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
                                >
                                  <Icon name="truck" size="sm" />
                                  <span>View rider</span>
                                </Link>
                              )}
                            </>
                          ) : (
                            <p className="text-muted-foreground">Rider assigned, details not available.</p>
                          )}

                          {(orderDetail.riderDelivery.proofPhotoUrl || orderDetail.riderDelivery.proofNote) && (
                            <div className="mt-3 p-2 rounded-lg bg-muted/40 space-y-1">
                              <p className="text-[11px] font-medium text-muted-foreground">Proof of delivery</p>
                              {orderDetail.riderDelivery.proofPhotoUrl && (
                                <a
                                  href={orderDetail.riderDelivery.proofPhotoUrl}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="inline-flex items-center gap-2 text-xs text-primary hover:underline"
                                >
                                  <img
                                    src={orderDetail.riderDelivery.proofPhotoUrl}
                                    alt="Proof of delivery"
                                    className="w-12 h-12 rounded-md object-cover border bg-background"
                                  />
                                  <span>View photo</span>
                                </a>
                              )}
                              {orderDetail.riderDelivery.proofNote && (
                                <p className="text-[11px] text-muted-foreground break-words">
                                  <span className="font-medium">Note:</span> {orderDetail.riderDelivery.proofNote}
                                </p>
                              )}
                            </div>
                          )}
                        </div>
                      ) : (
                        <p className="text-muted-foreground">Not out for delivery</p>
                      )}
                    </div>
                  </div>

                  {/* Items */}
                  <div className="p-4 rounded-xl bg-muted/10 border text-sm">
                    <p className="font-medium mb-3">Items</p>
                    {orderDetail.items.length === 0 ? (
                      <p className="text-muted-foreground text-xs">No items found for this order.</p>
                    ) : (
                      <div className="space-y-3">
                        {orderDetail.items.map((item) => {
                          const productName = item.product?.name ?? `Product #${item.productId}`
                          const lineTotal = (item.unitPrice ?? 0) * (item.quantity ?? 0)
                          return (
                            <div
                              key={item.id}
                              className="flex items-start justify-between gap-3 border-b last:border-0 pb-2"
                            >
                              <div>
                                <p className="font-medium text-sm">{productName}</p>
                                <p className="text-xs text-muted-foreground">
                                  Qty: {item.quantity} × {formatPrice(item.unitPrice ?? 0)}
                                </p>
                              </div>
                              <p className="text-sm font-semibold">{formatPrice(lineTotal)}</p>
                            </div>
                          )
                        })}
                      </div>
                    )}
                  </div>
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
