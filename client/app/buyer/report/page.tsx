"use client"

import { Suspense, useState, useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { reportsApi } from "@/lib/api"
import { ReportForm } from "@/components/report/report-form"
import { ReportContextBanner } from "@/components/report/report-context-banner"
import { toast } from "sonner"
import type { ReportTargetRole } from "@/lib/report-links"

function BuyerReportContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [reportTypes, setReportTypes] = useState<
    { id: number; typeKey: string; displayName: string; category?: string }[]
  >([])
  const [loading, setLoading] = useState(true)

  const targetRole = (searchParams.get("targetRole") || "") as ReportTargetRole | ""
  const targetUserId = searchParams.get("targetUserId")
  const orderId = searchParams.get("orderId")
  const storeId = searchParams.get("storeId")
  const contextLabel = searchParams.get("label")

  const hasContext = Boolean(targetRole && (storeId || orderId))

  useEffect(() => {
    if (!targetRole || (!storeId && !orderId)) return
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
  }, [targetRole, storeId, orderId])

  const handleSubmit = async (formData: FormData) => {
    if (!hasContext) {
      toast.error("Open a report from a store profile or order to submit.")
      return
    }
    if (targetRole) formData.append("targetRole", targetRole)
    if (targetUserId) formData.append("targetUserId", targetUserId)
    if (orderId) formData.append("orderId", orderId)
    if (storeId) formData.append("storeId", storeId)

    await reportsApi.submitReport(formData)
    toast.success("Report submitted. Our team will review it shortly.")
    router.push("/buyer/reports")
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
        <h1 className="text-2xl font-bold">Report a Problem</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Tell us what happened and we&apos;ll investigate.
        </p>
      </div>

      {hasContext && targetRole && (
        <ReportContextBanner
          targetRole={targetRole}
          label={contextLabel}
          orderId={orderId}
          storeId={storeId}
        />
      )}

      {!hasContext && (
        <div className="rounded-xl border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
          To report a store or rider, use the <strong>Report</strong> button on a store profile or order
          page. You can also visit{" "}
          <a href="/buyer/reports" className="text-primary hover:underline">
            My Reports
          </a>{" "}
          to track submissions, or{" "}
          <a href="/buyer/help" className="text-primary hover:underline">
            Help Center
          </a>{" "}
          for general support.
        </div>
      )}

      <div className="bg-card border rounded-2xl p-6">
        {loading ? (
          <div className="text-center py-8 text-muted-foreground">Loading...</div>
        ) : (
          <ReportForm
            reportTypes={reportTypes}
            onSubmit={handleSubmit}
            submitLabel={hasContext ? "Submit Report" : "Submit (context required)"}
          />
        )}
      </div>
    </div>
  )
}

export default function BuyerReportPage() {
  return (
    <Suspense fallback={<div className="py-12 text-center text-muted-foreground">Loading…</div>}>
      <BuyerReportContent />
    </Suspense>
  )
}
