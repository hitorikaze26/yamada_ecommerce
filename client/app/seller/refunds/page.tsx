"use client"

import { useEffect, useState } from "react"
import Swal from "sweetalert2"
import { AnimatePresence, motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { sellerApi } from "@/lib/api"

interface RefundOrderItem {
  productName: string
  quantity: number
  unitPrice: number
  variation?: string | null
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

interface RefundBuyerInfo {
  id: number
  name?: string | null
  email?: string | null
  contactNumber?: string | null
}

interface SellerRefundDto {
  id: number
  transactionId: number | null
  orderId: number | null
  amount: number
  platformFee: number
  netAmount: number
  status: string
  reason?: string | null
  createdAt: string | null
  updatedAt?: string | null
  paymentStatus?: string | null
  buyer?: RefundBuyerInfo | null
  order?: RefundOrderInfo | null
}

const statusStyles: Record<string, string> = {
  requested: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300",
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300",
  approved_by_seller: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300",
  rejected_by_seller: "bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300",
  approved: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300",
  rejected: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300",
  disputed: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-300",
  evidence_requested: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300",
  completed: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300",
}

function formatStatus(status: string) {
  const s = status.toLowerCase()
  if (s === "requested") return "Pending review"
  if (s === "approved_by_seller") return "Approved by you"
  if (s === "rejected_by_seller") return "Rejected by you"
  return s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}

function formatOrderStatus(status: string) {
  return status.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
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

function formatShortDate(iso: string | null | undefined) {
  if (!iso) return "—"
  return new Date(iso).toLocaleDateString("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
  })
}

function parseVariation(variation?: string | null): { color?: string; size?: string } {
  if (!variation) return {}
  try {
    const parsed = JSON.parse(variation) as { color?: string; size?: string }
    return { color: parsed.color, size: parsed.size }
  } catch {
    return {}
  }
}

function canActOnRefund(status: string) {
  const s = status.toLowerCase()
  return s === "requested" || s === "pending"
}

function RefundExpandedDetails({
  r,
  actingId,
  onApprove,
  onReject,
  formatPrice,
}: {
  r: SellerRefundDto
  actingId: number | null
  onApprove: (r: SellerRefundDto) => void
  onReject: (r: SellerRefundDto) => void
  formatPrice: (n: number) => string
}) {
  const order = r.order
  const buyer = r.buyer
  const showActions = canActOnRefund(r.status)

  return (
    <div className="px-4 pb-4 pt-2 space-y-4 border-t bg-muted/10">
      <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3 text-sm">
        <div>
          <p className="text-xs text-muted-foreground">Gross payment</p>
          <p className="font-medium">{formatPrice(r.amount)}</p>
        </div>
        <div>
          <p className="text-xs text-muted-foreground">Platform fee</p>
          <p className="font-medium">{formatPrice(r.platformFee)}</p>
        </div>
        {r.transactionId != null && (
          <div>
            <p className="text-xs text-muted-foreground">Transaction ID</p>
            <p className="font-medium">#{r.transactionId}</p>
          </div>
        )}
        {r.paymentStatus && (
          <div>
            <p className="text-xs text-muted-foreground">Payment status</p>
            <p className="font-medium capitalize">{formatOrderStatus(r.paymentStatus)}</p>
          </div>
        )}
        <div>
          <p className="text-xs text-muted-foreground">Requested</p>
          <p className="font-medium">{formatDateTime(r.createdAt)}</p>
        </div>
        {r.updatedAt && (
          <div>
            <p className="text-xs text-muted-foreground">Last updated</p>
            <p className="font-medium">{formatDateTime(r.updatedAt)}</p>
          </div>
        )}
      </div>

      {buyer && (
        <div className="rounded-xl border bg-card p-3 text-sm">
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">
            Buyer
          </p>
          <div className="grid sm:grid-cols-2 gap-2">
            <p>
              <span className="text-muted-foreground">Name: </span>
              <span className="font-medium">{buyer.name || "—"}</span>
            </p>
            <p className="break-all">
              <span className="text-muted-foreground">Email: </span>
              <span className="font-medium">{buyer.email || "—"}</span>
            </p>
            {buyer.contactNumber && (
              <p>
                <span className="text-muted-foreground">Phone: </span>
                <span className="font-medium">{buyer.contactNumber}</span>
              </p>
            )}
          </div>
        </div>
      )}

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
                <span className="font-medium">{order.paymentMethod}</span>
              </p>
            )}
          </div>
          {order.items.length > 0 && (
            <ul className="border-t pt-2 space-y-2">
              {order.items.map((item, idx) => {
                const v = parseVariation(item.variation)
                return (
                  <li key={idx} className="flex justify-between gap-2 text-sm">
                    <span className="min-w-0">
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
                    </span>
                    <span className="font-medium shrink-0">
                      {formatPrice(item.unitPrice * item.quantity)}
                    </span>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      )}

      <div className="rounded-xl bg-muted/50 px-3 py-2 text-sm">
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-1">
          Buyer reason
        </p>
        <p className="break-words">{r.reason?.trim() ? r.reason : "No reason provided."}</p>
      </div>

      {showActions && (
        <div className="flex flex-wrap gap-2" onClick={(e) => e.stopPropagation()}>
          <Button size="sm" disabled={actingId === r.id} onClick={() => onApprove(r)}>
            Approve refund
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="border-destructive text-destructive hover:bg-destructive/10"
            disabled={actingId === r.id}
            onClick={() => onReject(r)}
          >
            Reject refund
          </Button>
        </div>
      )}
    </div>
  )
}

export default function SellerRefundsPage() {
  const [refunds, setRefunds] = useState<SellerRefundDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actingId, setActingId] = useState<number | null>(null)
  const [expandedId, setExpandedId] = useState<number | null>(null)

  const loadRefunds = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await sellerApi.getRefundRequests()
      setRefunds((res.data.refunds as SellerRefundDto[]) ?? [])
    } catch (err) {
      console.error("Failed to load seller refunds", err)
      setError("Failed to load refund history. Please try again.")
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void loadRefunds()
  }, [])

  const formatPrice = (amount: number) =>
    new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(amount)

  const handleApprove = async (r: SellerRefundDto) => {
    const orderLabel = r.order?.displayId ?? (r.orderId ? `#${r.orderId}` : "—")
    const result = await Swal.fire({
      title: "Approve refund?",
      text: `Approve refund of ${formatPrice(r.netAmount)} for order ${orderLabel}?`,
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Approve",
    })
    if (!result.isConfirmed) return
    setActingId(r.id)
    try {
      await sellerApi.approveRefund(r.id)
      await loadRefunds()
      setExpandedId(null)
    } catch {
      Swal.fire("Error", "Failed to approve refund.", "error")
    } finally {
      setActingId(null)
    }
  }

  const handleReject = async (r: SellerRefundDto) => {
    const result = await Swal.fire({
      title: "Reject refund?",
      text: "The buyer will be notified of your decision.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Reject",
      confirmButtonColor: "#ef4444",
    })
    if (!result.isConfirmed) return
    setActingId(r.id)
    try {
      await sellerApi.rejectRefund(r.id)
      await loadRefunds()
      setExpandedId(null)
    } catch {
      Swal.fire("Error", "Failed to reject refund.", "error")
    } finally {
      setActingId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Refund requests</h1>
        <p className="text-muted-foreground">
          Tap a request to view full details. Approve or reject while status is pending.
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
            New refund requests will appear here. Click any row to expand details.
          </p>
        </div>
      )}

      {!isLoading && !error && refunds.length > 0 && (
        <div className="space-y-2">
          {refunds.map((r) => {
            const statusKey = r.status.toLowerCase()
            const badgeClass = statusStyles[statusKey] ?? "bg-muted text-muted-foreground"
            const isExpanded = expandedId === r.id
            const order = r.order
            const buyerName = r.buyer?.name || r.buyer?.email || "Customer"

            return (
              <div
                key={r.id}
                className={`bg-card border rounded-xl overflow-hidden transition-colors ${
                  isExpanded ? "border-primary/40 shadow-sm" : "hover:border-muted-foreground/30"
                }`}
              >
                <button
                  type="button"
                  className="w-full p-4 flex flex-wrap items-center gap-3 text-left hover:bg-muted/30 transition-colors"
                  onClick={() => setExpandedId(isExpanded ? null : r.id)}
                  aria-expanded={isExpanded}
                >
                  <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                    <Icon name="receipt-refund" className="text-primary" size="sm" />
                  </div>

                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-sm">
                      Refund #{r.id}
                      {order && (
                        <span className="text-muted-foreground font-normal">
                          {" "}
                          · {order.displayId}
                        </span>
                      )}
                    </p>
                    <p className="text-xs text-muted-foreground truncate">
                      {buyerName}
                      {r.reason?.trim() ? ` · ${r.reason.slice(0, 60)}${r.reason.length > 60 ? "…" : ""}` : ""}
                    </p>
                  </div>

                  <div className="text-right shrink-0">
                    <p className="font-bold text-primary">{formatPrice(r.netAmount)}</p>
                    <p className="text-xs text-muted-foreground">{formatShortDate(r.createdAt)}</p>
                  </div>

                  <span
                    className={`inline-flex px-2.5 py-0.5 rounded-full text-xs font-medium shrink-0 ${badgeClass}`}
                  >
                    {formatStatus(r.status)}
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
                      <RefundExpandedDetails
                        r={r}
                        actingId={actingId}
                        onApprove={(refund) => void handleApprove(refund)}
                        onReject={(refund) => void handleReject(refund)}
                        formatPrice={formatPrice}
                      />
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
