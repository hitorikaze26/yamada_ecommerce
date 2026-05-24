"use client"

import { Suspense, useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { reportsApi } from "@/lib/api"
import { ReportForm } from "@/components/report/report-form"
import { ReportContextBanner } from "@/components/report/report-context-banner"
import { toast } from "sonner"
import type { ReportTargetRole } from "@/lib/report-links"

function RiderReportContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [reportTypes, setReportTypes] = useState<
    { id: number; typeKey: string; displayName: string; category?: string }[]
  >([])
  const [loading, setLoading] = useState(true)

  const targetRole = (searchParams.get("targetRole") || "seller") as ReportTargetRole
  const targetUserId = searchParams.get("targetUserId")
  const orderId = searchParams.get("orderId")
  const storeId = searchParams.get("storeId")
  const contextLabel = searchParams.get("label")
  const hasContext = Boolean(orderId)

  useEffect(() => {
    if (!orderId || !targetRole) return
    reportsApi
      .getReportTypes(targetRole)
      .then((res) => {
        const types = (res.data.types || []).map((t: Record<string, unknown>) => ({
          id: t.id as number,
          typeKey: t.typeKey as string,
          displayName: t.displayName as string,
          category: t.category as string | undefined,
        }))
        setReportTypes(types)
      })
      .catch(() => toast.error("Failed to load report types"))
      .finally(() => setLoading(false))
  }, [targetRole, orderId])

  const handleSubmit = async (formData: FormData) => {
    if (!orderId) {
      toast.error("Open a report from a delivery to submit.")
      return
    }
    formData.append("targetRole", targetRole)
    if (targetUserId) formData.append("targetUserId", targetUserId)
    formData.append("orderId", orderId)
    if (storeId) formData.append("storeId", storeId)

    await reportsApi.submitReport(formData)
    toast.success("Report submitted. Our team will review it shortly.")
    router.push("/rider/deliveries")
  }

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <button
          type="button"
          onClick={() => router.back()}
          className="text-sm text-muted-foreground hover:text-foreground mb-2 flex items-center gap-1"
        >
          <Icon name="chevron-left" />
          Back
        </button>
        <h1 className="text-2xl font-bold">
          {targetRole === "buyer" ? "Report Buyer" : "Report Seller"}
        </h1>
        <p className="text-muted-foreground text-sm mt-1">
          Report issues with {targetRole === "buyer" ? "the customer" : "the store"} on this delivery.
        </p>
      </div>

      {hasContext && (
        <ReportContextBanner
          targetRole={targetRole}
          label={contextLabel}
          orderId={orderId}
          storeId={storeId}
        />
      )}

      {!hasContext && (
        <div className="rounded-xl border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
          Use <strong>Report seller</strong> or <strong>Report buyer</strong> on a delivery in Deliveries
          or History.
        </div>
      )}

      <div className="bg-card border rounded-2xl p-6">
        {loading ? (
          <div className="text-center py-8 text-muted-foreground">Loading...</div>
        ) : (
          <ReportForm
            reportTypes={reportTypes}
            onSubmit={handleSubmit}
            descriptionPlaceholder="Describe the issue in detail..."
          />
        )}
      </div>
    </div>
  )
}

export default function RiderReportPage() {
  return (
    <Suspense fallback={<div className="py-12 text-center text-muted-foreground">Loading…</div>}>
      <RiderReportContent />
    </Suspense>
  )
}
