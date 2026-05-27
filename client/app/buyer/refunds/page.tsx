"use client"

import { useEffect, useState, useCallback } from "react"
import Link from "next/link"
import Image from "next/image"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import Swal from "sweetalert2"
import { toast } from "sonner"
import { formatPrice } from "@/lib/format"
import { ordersApi, resolveImageUrl } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import { StoreNameLink } from "@/components/store/store-name-link"

interface RefundOrderItem {
  productName: string
  quantity: number
  unitPrice: number
  variation?: string | null
  imageUrl?: string | null
}

interface RefundOrderInfo {
  id: number
  displayId: string
  status: string
  totalAmount: number
  shippingFee: number
  grandTotal: number
  paymentMethod?: string | null
  createdAt?: string | null
  items: RefundOrderItem[]
}

interface RefundStoreInfo {
  id: number
  name?: string | null
}

interface BuyerRefundDto {
  id: number
  transactionId: number | null
  orderId: number | null
  amount: number
  reason?: string | null
  status: string
  createdAt: string | null
  updatedAt?: string | null
  paymentStatus?: string | null
  store?: RefundStoreInfo | null
  order?: RefundOrderInfo | null
  canDispute?: boolean
  sellerResponseNote?: string | null
}

const statusStyles: Record<string, string> = {
  requested: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300",
  approved_by_seller: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300",
  rejected_by_seller: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
  disputed: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300",
  evidence_requested: "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300",
  approved: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300",
  rejected: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
  processing: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300",
  completed: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300",
  declined: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
}

function formatStatus(status: string) {
  const s = status.toLowerCase()
  if (s === "requested") return "Pending review"
  if (s === "approved_by_seller") return "Approved by seller"
  if (s === "rejected_by_seller") return "Rejected by seller"
  return s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}

function formatDateTime(iso: string | null | undefined) {
  if (!iso) return "—"
  return new Date(iso).toLocaleString("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })
}

function parseVariation(variation?: string | null): { color?: string; size?: string } {
  if (!variation) return {}
  try {
    const parsed = JSON.parse(variation) as { color?: string; size?: string }
    return { color: parsed.color, size: parsed.size }
  } catch {
    try {
      const jsonLike = variation.replace(/'/g, '"')
      const parsed = JSON.parse(jsonLike) as { color?: string; size?: string }
      return { color: parsed.color, size: parsed.size }
    } catch {
      return {}
    }
  }
}

export default function BuyerRefundsPage() {
  const [refunds, setRefunds] = useState<BuyerRefundDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedId, setExpandedId] = useState<number | null>(null)
  const [refundImageErrors, setRefundImageErrors] = useState<Record<string, boolean>>({})

  useEffect(() => {
    const fetchRefunds = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await ordersApi.getRefundRequests()
        setRefunds(unwrapBuyerList<BuyerRefundDto>(res.data, ["refunds"]))
      } catch (err) {
        console.error("Failed to load refunds", err)
        setError(getBuyerFetchError(err, "Failed to load refund history. Please try again."))
      } finally {
        setIsLoading(false)
      }
    }

    void fetchRefunds()
  }, [])

  const handleDispute = useCallback(async (refund: BuyerRefundDto) => {
    const result = await Swal.fire({
      title: "Dispute this decision?",
      text: "An admin will review the dispute.",
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Yes, dispute",
      cancelButtonText: "Cancel",
    })
    if (!result.isConfirmed) return
    try {
      await ordersApi.disputeRefund(refund.id)
      void Swal.fire({ title: "Disputed", text: "Your dispute has been submitted.", icon: "success", timer: 2000, showConfirmButton: false })
      const res = await ordersApi.getRefundRequests()
      setRefunds(unwrapBuyerList<BuyerRefundDto>(res.data, ["refunds"]))
    } catch {
      void Swal.fire({ title: "Error", text: "Failed to submit dispute.", icon: "error" })
    }
  }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Refund requests</h1>
        <p className="text-muted-foreground">
          Sellers review refund requests first. If a seller rejects your request, you can dispute for admin review.
        </p>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-8 flex items-center justify-center gap-3 text-muted-foreground">
          <Icon name="spinner" className="animate-spin" />
          Loading refunds…
        </div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm flex items-start gap-2">
          <Icon name="exclamation-circle" className="mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {!isLoading && !error && refunds.length === 0 && (
        <div className="bg-card border rounded-2xl p-10 text-center">
          <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
            <Icon name="receipt-refund" size="xl" className="text-muted-foreground" />
          </div>
          <h2 className="text-lg font-semibold mb-1">No refund requests</h2>
          <p className="text-sm text-muted-foreground max-w-sm mx-auto">
            When you request a refund on a delivered order, it will appear here with live status updates.
          </p>
          <Link
            href="/buyer/orders"
            className="inline-flex mt-6 text-sm font-medium text-primary hover:underline"
          >
            View my orders
          </Link>
        </div>
      )}

      {!isLoading && !error && refunds.length > 0 && (
        <div className="space-y-4">
          {refunds.map((r) => {
            const statusKey = r.status.toLowerCase()
            const badgeClass = statusStyles[statusKey] ?? "bg-muted text-muted-foreground"
            const order = r.order
            const isExpanded = expandedId === r.id
            const firstItem = order?.items?.[0]

            return (
              <div
                key={r.id}
                className="bg-card border rounded-2xl overflow-hidden hover:border-primary/20 transition-colors"
              >
                <button
                  type="button"
                  className="w-full text-left p-5"
                  onClick={() => setExpandedId(isExpanded ? null : r.id)}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3 mb-4">
                    <div>
                      <p className="text-xs text-muted-foreground uppercase tracking-wide">Refund</p>
                      <p className="text-lg font-bold">#{r.id}</p>
                      {order?.displayId && (
                        <p className="text-sm text-muted-foreground mt-0.5">{order.displayId}</p>
                      )}
                    </div>
                    <span className={`inline-flex px-3 py-1 rounded-full text-xs font-semibold ${badgeClass}`}>
                      {formatStatus(r.status)}
                    </span>
                  </div>

                  <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
                    <div>
                      <p className="text-xs text-muted-foreground mb-0.5">Amount</p>
                      <p className="font-semibold text-primary">{formatPrice(r.amount)}</p>
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground mb-0.5">Order</p>
                      {r.orderId ? (
                        <span className="font-medium text-primary">#{r.orderId}</span>
                      ) : (
                        <p className="font-medium">—</p>
                      )}
                    </div>
                    {r.store?.name && (
                      <div>
                        <p className="text-xs text-muted-foreground mb-0.5">Store</p>
                        <StoreNameLink
                          storeId={r.store.id}
                          storeName={r.store.name}
                          className="text-sm font-medium"
                        />
                      </div>
                    )}
                    <div>
                      <p className="text-xs text-muted-foreground mb-0.5">Requested</p>
                      <p className="font-medium">{formatDateTime(r.createdAt)}</p>
                    </div>
                  </div>

                  {firstItem && !isExpanded && (
                    <div className="mt-4 flex items-center gap-3 text-sm">
                      {firstItem.imageUrl && (
                        <div className="relative w-12 h-12 rounded-lg overflow-hidden bg-muted shrink-0">
                          {refundImageErrors[`first-${r.id}`] ? (
                            <div className="w-full h-full flex items-center justify-center bg-muted">
                              <Icon name="image" className="text-muted-foreground/50" />
                            </div>
                          ) : (
                            <Image
                              src={resolveImageUrl(firstItem.imageUrl) || "/placeholder.svg"}
                              alt={firstItem.productName}
                              fill
                              className="object-cover"
                              onError={() => setRefundImageErrors((prev) => ({ ...prev, [`first-${r.id}`]: true }))}
                            />
                          )}
                        </div>
                      )}
                      <div className="min-w-0">
                        <p className="font-medium truncate">{firstItem.productName}</p>
                        {order && order.items.length > 1 && (
                          <p className="text-xs text-muted-foreground">
                            +{order.items.length - 1} more item{order.items.length > 2 ? "s" : ""}
                          </p>
                        )}
                      </div>
                    </div>
                  )}

                  <div className="mt-3 flex items-center gap-1 text-xs text-muted-foreground">
                    <Icon name={isExpanded ? "chevron-up" : "chevron-down"} className="w-3.5 h-3.5" />
                    {isExpanded ? "Hide details" : "Show details"}
                  </div>
                </button>

                {isExpanded && (
                  <div className="px-5 pb-5 pt-0 space-y-4 border-t bg-muted/10">
                    <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3 text-sm pt-4">
                      {r.paymentStatus && (
                        <div>
                          <p className="text-xs text-muted-foreground">Payment status</p>
                          <p className="font-medium capitalize">{formatStatus(r.paymentStatus)}</p>
                        </div>
                      )}
                      {r.transactionId != null && (
                        <div>
                          <p className="text-xs text-muted-foreground">Transaction ID</p>
                          <p className="font-medium">#{r.transactionId}</p>
                        </div>
                      )}
                      {r.updatedAt && r.updatedAt !== r.createdAt && (
                        <div>
                          <p className="text-xs text-muted-foreground">Last updated</p>
                          <p className="font-medium">{formatDateTime(r.updatedAt)}</p>
                        </div>
                      )}
                    </div>

                    {order && (
                      <div className="rounded-xl border bg-card p-3 text-sm space-y-3">
                        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                          Order summary
                        </p>
                        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-2">
                          <p>
                            <span className="text-muted-foreground">Subtotal: </span>
                            <span className="font-medium">{formatPrice(order.totalAmount)}</span>
                          </p>
                          <p>
                            <span className="text-muted-foreground">Shipping: </span>
                            <span className="font-medium">{formatPrice(order.shippingFee)}</span>
                          </p>
                          <p>
                            <span className="text-muted-foreground">Total: </span>
                            <span className="font-semibold">{formatPrice(order.grandTotal)}</span>
                          </p>
                          {order.paymentMethod && (
                            <p>
                              <span className="text-muted-foreground">Payment: </span>
                              <span className="font-medium capitalize">{order.paymentMethod}</span>
                            </p>
                          )}
                        </div>
                        {order.items.length > 0 && (
                          <ul className="border-t pt-2 space-y-3">
                            {order.items.map((item, idx) => {
                              const v = parseVariation(item.variation)
                              const img = resolveImageUrl(item.imageUrl) || "/placeholder.svg"
                              return (
                                <li key={idx} className="flex gap-3 text-sm">
                                  <div className="relative w-14 h-14 rounded-lg overflow-hidden bg-muted shrink-0">
                                  {refundImageErrors[`item-${r.id}-${idx}`] ? (
                                    <div className="w-full h-full flex items-center justify-center bg-muted">
                                      <Icon name="image" className="text-muted-foreground/50" />
                                    </div>
                                  ) : (
                                    <Image
                                      src={img}
                                      alt={item.productName}
                                      fill
                                      className="object-cover"
                                      onError={() => setRefundImageErrors((prev) => ({ ...prev, [`item-${r.id}-${idx}`]: true }))}
                                    />
                                  )}
                                </div>
                                  <div className="flex-1 min-w-0 flex justify-between gap-2">
                                    <div>
                                      <span className="font-medium">{item.productName}</span>
                                      <span className="text-muted-foreground text-xs block">
                                        {[
                                          v.color && `Color: ${v.color}`,
                                          v.size && `Size: ${v.size}`,
                                          `Qty: ${item.quantity}`,
                                        ]
                                          .filter(Boolean)
                                          .join(" · ")}
                                      </span>
                                    </div>
                                    <span className="font-medium shrink-0">
                                      {formatPrice(item.unitPrice * item.quantity)}
                                    </span>
                                  </div>
                                </li>
                              )
                            })}
                          </ul>
                        )}
                        {r.orderId && (
                          <Link
                            href={`/orders/${r.orderId}`}
                            className="inline-flex text-sm font-medium text-primary hover:underline"
                          >
                            View full order details
                          </Link>
                        )}
                      </div>
                    )}

                    {r.sellerResponseNote && (
                      <div className="rounded-xl bg-muted/50 px-4 py-3 text-sm">
                        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-1">
                          Seller response
                        </p>
                        <p>{r.sellerResponseNote}</p>
                      </div>
                    )}

                    {(r.canDispute || r.status === "rejected_by_seller") && (
                      <div className="flex justify-end">
                        <Button size="sm" onClick={() => void handleDispute(r)}>
                          Dispute decision
                        </Button>
                      </div>
                    )}

                    <div className="rounded-xl bg-muted/50 px-4 py-3 text-sm">
                      <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-1">
                        Reason
                      </p>
                      <p className="text-foreground break-words">
                        {r.reason?.trim() ? r.reason : "No reason provided."}
                      </p>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
