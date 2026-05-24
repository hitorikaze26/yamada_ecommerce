"use client"

import { reportTargetLabel, type ReportTargetRole } from "@/lib/report-links"

interface ReportContextBannerProps {
  targetRole: ReportTargetRole
  label?: string | null
  orderId?: number | string | null
  storeId?: number | string | null
}

export function ReportContextBanner({ targetRole, label, orderId, storeId }: ReportContextBannerProps) {
  return (
    <div className="rounded-xl border border-amber-200/80 bg-amber-50/80 dark:bg-amber-950/20 dark:border-amber-800/50 px-4 py-3 text-sm">
      <p className="font-medium text-amber-900 dark:text-amber-200">
        Reporting: {reportTargetLabel(targetRole, label)}
      </p>
      <p className="text-xs text-amber-800/80 dark:text-amber-300/80 mt-0.5">
        {orderId != null && <span className="mr-3">Order #{orderId}</span>}
        {storeId != null && <span>Store #{storeId}</span>}
      </p>
    </div>
  )
}
