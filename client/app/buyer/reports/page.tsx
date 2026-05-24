"use client"

import { useEffect, useMemo, useState } from "react"
import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { reportsApi, resolveImageUrl } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import type { ProblemReportDto, ReportStatusType } from "@/lib/types"
import { StoreNameLink } from "@/components/store/store-name-link"

const STATUS_FILTERS: { key: "all" | ReportStatusType; label: string }[] = [
  { key: "all", label: "All" },
  { key: "pending", label: "Pending" },
  { key: "under_review", label: "Under review" },
  { key: "investigating", label: "Investigating" },
  { key: "resolved", label: "Resolved" },
  { key: "dismissed", label: "Dismissed" },
]

const statusStyles: Record<string, string> = {
  pending: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300",
  under_review: "bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300",
  investigating: "bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300",
  resolved: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300",
  dismissed: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-300",
}

function formatStatus(status: string) {
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

export default function BuyerReportsPage() {
  const [reports, setReports] = useState<ProblemReportDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<"all" | ReportStatusType>("all")
  const [expandedId, setExpandedId] = useState<number | null>(null)

  useEffect(() => {
    const fetchReports = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await reportsApi.getMyReports()
        setReports(unwrapBuyerList<ProblemReportDto>(res.data, ["reports"]))
      } catch (err) {
        console.error("Failed to load reports", err)
        setError(getBuyerFetchError(err, "Failed to load your reports. Please try again."))
      } finally {
        setIsLoading(false)
      }
    }
    void fetchReports()
  }, [])

  const filtered = useMemo(() => {
    if (statusFilter === "all") return reports
    return reports.filter((r) => r.status === statusFilter)
  }, [reports, statusFilter])

  const openCount = reports.filter((r) =>
    ["pending", "under_review", "investigating"].includes(r.status),
  ).length

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">My Reports</h1>
        <p className="text-muted-foreground">
          Track problems you reported about stores, riders, or orders. Our team reviews each submission.
        </p>
      </div>

      <div className="bg-card border rounded-2xl p-4 flex flex-wrap items-center gap-3 justify-between">
        <div className="flex flex-wrap gap-2">
          {STATUS_FILTERS.map((f) => (
            <button
              key={f.key}
              type="button"
              onClick={() => setStatusFilter(f.key)}
              className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
                statusFilter === f.key
                  ? "bg-primary text-primary-foreground border-primary"
                  : "border-border hover:bg-muted"
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
        <Link
          href="/buyer/help"
          className="inline-flex items-center gap-2 text-sm text-primary hover:underline font-medium"
        >
          <Icon name="exclamation" size="sm" />
          Report a new problem
        </Link>
      </div>

      {!isLoading && !error && openCount > 0 && (
        <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-2xl p-4 text-sm text-amber-900 dark:text-amber-200">
          You have <strong>{openCount}</strong> report{openCount === 1 ? "" : "s"} still being reviewed.
        </div>
      )}

      {isLoading && (
        <div className="bg-card border rounded-2xl p-6 text-muted-foreground">Loading reports...</div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && filtered.length === 0 && (
        <div className="bg-card border rounded-2xl p-10 text-center">
          <Icon name="exclamation" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h2 className="text-lg font-semibold mb-2">No reports yet</h2>
          <p className="text-sm text-muted-foreground mb-4 max-w-md mx-auto">
            Use the <strong>Report</strong> button on a store profile or order if something went wrong.
            Your submissions will appear here with status updates.
          </p>
          <Link
            href="/buyer/orders"
            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-primary text-primary-foreground text-sm font-medium"
          >
            Go to My Orders
          </Link>
        </div>
      )}

      {!isLoading && !error && filtered.length > 0 && (
        <div className="space-y-4">
          {filtered.map((report) => {
            const expanded = expandedId === report.id
            const evidence = report.evidence ?? []
            return (
              <div key={report.id} className="bg-card border rounded-2xl overflow-hidden">
                <button
                  type="button"
                  onClick={() => setExpandedId(expanded ? null : report.id)}
                  className="w-full text-left p-5 hover:bg-muted/30 transition-colors"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="space-y-1 min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-semibold text-sm">
                          {report.reportType || "Report"}
                        </span>
                        <span
                          className={`px-2 py-0.5 rounded-full text-[11px] font-medium ${statusStyles[report.status] || statusStyles.pending}`}
                        >
                          {formatStatus(report.status)}
                        </span>
                        {report.reportTypeCategory && (
                          <span className="px-2 py-0.5 rounded-full text-[11px] bg-muted capitalize">
                            {report.reportTypeCategory.replace(/_/g, " ")}
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-muted-foreground">
                        Report #{report.id} · Submitted {formatDateTime(report.createdAt)}
                      </p>
                      {report.targetLabel && (
                        <p className="text-sm">
                          Against{" "}
                          <span className="font-medium capitalize">{report.targetRole}</span>
                          {": "}
                          <span className="text-muted-foreground">{report.targetLabel}</span>
                        </p>
                      )}
                      {!expanded && (
                        <p className="text-sm text-muted-foreground line-clamp-2 pt-1">{report.description}</p>
                      )}
                    </div>
                    <Icon name={expanded ? "angle-up" : "angle-down"} className="text-muted-foreground shrink-0" />
                  </div>
                </button>

                {expanded && (
                  <div className="px-5 pb-5 pt-0 border-t space-y-4">
                    <div>
                      <p className="text-xs font-medium text-muted-foreground mb-1">Description</p>
                      <p className="text-sm whitespace-pre-wrap">{report.description}</p>
                    </div>

                    <div className="grid sm:grid-cols-2 gap-3 text-sm">
                      {report.store && (
                        <div>
                          <p className="text-xs text-muted-foreground mb-0.5">Store</p>
                          <StoreNameLink storeId={report.store.id} storeName={report.store.name || "Store"} />
                        </div>
                      )}
                      {report.order && (
                        <div>
                          <p className="text-xs text-muted-foreground mb-0.5">Order</p>
                          <Link href={`/orders/${report.order.id}`} className="text-primary hover:underline font-medium">
                            {report.order.displayId}
                          </Link>
                          <p className="text-xs text-muted-foreground capitalize mt-0.5">
                            {report.order.status.replace(/_/g, " ")}
                          </p>
                        </div>
                      )}
                      {report.updatedAt && report.updatedAt !== report.createdAt && (
                        <div>
                          <p className="text-xs text-muted-foreground mb-0.5">Last updated</p>
                          <p>{formatDateTime(report.updatedAt)}</p>
                        </div>
                      )}
                      {report.resolvedAt && (
                        <div>
                          <p className="text-xs text-muted-foreground mb-0.5">Resolved</p>
                          <p>{formatDateTime(report.resolvedAt)}</p>
                        </div>
                      )}
                    </div>

                    {evidence.length > 0 && (
                      <div>
                        <p className="text-xs font-medium text-muted-foreground mb-2">
                          Evidence ({evidence.length})
                        </p>
                        <div className="flex flex-wrap gap-2">
                          {evidence.map((ev) => {
                            const url =
                              resolveImageUrl(ev.fileUrl) ||
                              resolveImageUrl(ev.filePath) ||
                              resolveImageUrl(`/static/${ev.filePath}`)
                            if (!url) return null
                            const isPdf =
                              ev.fileType === "pdf" ||
                              (ev.originalFilename || ev.filePath || "").toLowerCase().endsWith(".pdf")
                            if (isPdf) {
                              return (
                                <a
                                  key={ev.id}
                                  href={url}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="px-3 py-2 rounded-lg border text-xs font-medium hover:bg-muted"
                                >
                                  {ev.originalFilename || "View PDF"}
                                </a>
                              )
                            }
                            return (
                              <a
                                key={ev.id}
                                href={url}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="block w-20 h-20 rounded-lg overflow-hidden border bg-muted"
                              >
                                <img
                                  src={url}
                                  alt={ev.originalFilename || "Evidence"}
                                  className="w-full h-full object-cover"
                                />
                              </a>
                            )
                          })}
                        </div>
                      </div>
                    )}

                    <div className="flex flex-wrap gap-2 pt-2">
                      {report.order && (
                        <Link
                          href={`/orders/${report.order.id}`}
                          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-xs font-medium hover:bg-muted"
                        >
                          <Icon name="shopping-bag" size="sm" />
                          View order
                        </Link>
                      )}
                      {report.store && (
                        <Link
                          href={`/store/${report.store.id}`}
                          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-xs font-medium hover:bg-muted"
                        >
                          <Icon name="store" size="sm" />
                          View store
                        </Link>
                      )}
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
