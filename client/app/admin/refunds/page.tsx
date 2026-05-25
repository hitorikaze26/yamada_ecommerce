"use client"

import { useCallback, useEffect, useState } from "react"
import Link from "next/link"
import Swal from "sweetalert2"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { formatPrice } from "@/lib/format"
import { adminApi } from "@/lib/api"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"
import { toast } from "sonner"

interface AdminRefundDto {
  id: number
  orderId: number | null
  amount: number
  status: string
  reason?: string | null
  createdAt?: string | null
  buyerEvidenceNote?: string | null
  sellerResponseNote?: string | null
  adminNote?: string | null
  isTransactionFrozen?: boolean
  buyer?: { id?: number; email?: string; givenName?: string; surname?: string }
}

const statusStyles: Record<string, string> = {
  disputed: "bg-orange-100 text-orange-800",
  evidence_requested: "bg-purple-100 text-purple-800",
  admin_review: "bg-indigo-100 text-indigo-800",
  approved: "bg-green-100 text-green-800",
  rejected: "bg-red-100 text-red-800",
  requested: "bg-amber-100 text-amber-800",
}

function formatStatus(status: string) {
  return status.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
}



export default function AdminRefundsPage() {
  const [refunds, setRefunds] = useState<AdminRefundDto[]>([])
  const [showAll, setShowAll] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionId, setActionId] = useState<number | null>(null)

  const fetchRefunds = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await adminApi.getRefundRequests(showAll ? { all: true } : { queue: "disputes" })
      setRefunds(unwrapAdminList<AdminRefundDto>(res.data, ["refunds"]))
    } catch (err) {
      setError(getAdminFetchError(err, "Failed to load refund disputes."))
      setRefunds([])
    } finally {
      setIsLoading(false)
    }
  }, [showAll])

  useEffect(() => {
    void fetchRefunds()
  }, [fetchRefunds])

  const runAction = async (refundId: number, action: string) => {
    setActionId(refundId)
    try {
      if (action === "approve") {
        await adminApi.approveRefund(refundId)
        toast.success("Refund approved and settled")
      } else if (action === "reject") {
        const result = await Swal.fire({
          title: "Reject refund",
          input: "textarea",
          inputLabel: "Reason for rejection (optional)",
          showCancelButton: true,
          confirmButtonText: "Reject",
        })
        if (!result.isConfirmed) return
        await adminApi.rejectRefund(refundId, result.value || undefined)
        toast.success("Refund rejected")
      } else if (action === "evidence") {
        const result = await Swal.fire({
          title: "Request evidence",
          input: "textarea",
          inputLabel: "What should the buyer provide?",
          inputValidator: (v) => (!v?.trim() ? "Note is required" : undefined),
          showCancelButton: true,
        })
        if (!result.isConfirmed || !result.value) return
        await adminApi.requestRefundEvidence(refundId, result.value)
        toast.success("Evidence requested")
      } else if (action === "freeze") {
        const confirm = await Swal.fire({
          title: "Freeze transaction?",
          text: "This prevents further settlement until unfrozen.",
          icon: "warning",
          showCancelButton: true,
        })
        if (!confirm.isConfirmed) return
        await adminApi.freezeRefund(refundId)
        toast.success("Transaction frozen")
      }
      await fetchRefunds()
    } catch (err: unknown) {
      const msg =
        err && typeof err === "object" && "response" in err
          ? (err as { response?: { data?: { msg?: string } } }).response?.data?.msg
          : undefined
      toast.error(msg || "Action failed")
    } finally {
      setActionId(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Refund disputes</h1>
          <p className="text-sm text-muted-foreground">
            Seller-first refunds auto-settle on approval. This queue is for buyer disputes and admin review only.
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant={showAll ? "outline" : "default"} size="sm" onClick={() => setShowAll(false)}>
            Dispute queue
          </Button>
          <Button variant={showAll ? "default" : "outline"} size="sm" onClick={() => setShowAll(true)}>
            All refunds
          </Button>
          <Button variant="outline" size="sm" onClick={() => void fetchRefunds()} disabled={isLoading}>
            Refresh
          </Button>
        </div>
      </div>

      {isLoading && (
        <div className="border rounded-xl p-8 text-center text-muted-foreground">
          <Icon name="spinner" className="animate-spin mr-2" /> Loading…
        </div>
      )}

      {error && !isLoading && (
        <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm">{error}</div>
      )}

      {!isLoading && !error && refunds.length === 0 && (
        <div className="border rounded-xl p-10 text-center text-muted-foreground">
          <Icon name="receipt-refund" className="text-4xl mb-3 opacity-50" />
          <p>No refunds in this view.</p>
        </div>
      )}

      {!isLoading && refunds.length > 0 && (
        <div className="space-y-4">
          {refunds.map((r) => {
            const badge = statusStyles[r.status] ?? "bg-muted text-muted-foreground"
            const buyerName = [r.buyer?.givenName, r.buyer?.surname].filter(Boolean).join(" ") || r.buyer?.email
            const busy = actionId === r.id

            return (
              <div key={r.id} className="border rounded-xl p-5 space-y-4 bg-card">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-xs text-muted-foreground uppercase">Refund #{r.id}</p>
                    {r.orderId && (
                      <p className="text-sm text-muted-foreground">
                        Order{" "}
                        <Link href="/admin/orders" className="text-primary font-medium">
                          #{r.orderId}
                        </Link>
                      </p>
                    )}
                  </div>
                  <Badge className={badge}>{formatStatus(r.status)}</Badge>
                </div>

                <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-3 text-sm">
                  <div>
                    <p className="text-xs text-muted-foreground">Amount</p>
                    <p className="font-semibold">{formatPrice(r.amount)}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Buyer</p>
                    <p className="font-medium">{buyerName || "—"}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Requested</p>
                    <p>{r.createdAt ? new Date(r.createdAt).toLocaleString() : "—"}</p>
                  </div>
                  {r.isTransactionFrozen && (
                    <div>
                      <p className="text-xs text-muted-foreground">Frozen</p>
                      <p className="text-red-600 font-medium">Yes</p>
                    </div>
                  )}
                </div>

                {r.reason && (
                  <div className="text-sm rounded-lg bg-muted/40 p-3">
                    <p className="text-xs font-semibold text-muted-foreground mb-1">Buyer reason</p>
                    <p>{r.reason}</p>
                  </div>
                )}
                {r.sellerResponseNote && (
                  <div className="text-sm rounded-lg bg-muted/40 p-3">
                    <p className="text-xs font-semibold text-muted-foreground mb-1">Seller response</p>
                    <p>{r.sellerResponseNote}</p>
                  </div>
                )}
                {r.buyerEvidenceNote && (
                  <div className="text-sm rounded-lg bg-muted/40 p-3">
                    <p className="text-xs font-semibold text-muted-foreground mb-1">Buyer dispute note</p>
                    <p>{r.buyerEvidenceNote}</p>
                  </div>
                )}

                <div className="flex flex-wrap gap-2 pt-2 border-t">
                  <Button size="sm" disabled={busy} onClick={() => void runAction(r.id, "approve")}>
                    Approve
                  </Button>
                  <Button size="sm" variant="outline" disabled={busy} onClick={() => void runAction(r.id, "reject")}>
                    Reject
                  </Button>
                  <Button size="sm" variant="outline" disabled={busy} onClick={() => void runAction(r.id, "evidence")}>
                    Request evidence
                  </Button>
                  <Button size="sm" variant="outline" disabled={busy} onClick={() => void runAction(r.id, "freeze")}>
                    Freeze
                  </Button>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
