"use client"

import { useCallback, useEffect, useState } from "react"
import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { adminReportsApi } from "@/lib/api"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"
import { toast } from "sonner"

interface ProblemReportListDto {
  id: number
  reporterUserId: number
  reporterRole: string
  reportType: string | null
  description: string
  status: string
  priority: string
  targetUserId: number | null
  targetRole: string | null
  storeId: number | null
  orderId: number | null
  createdAt: string | null
  reporterName?: string | null
  targetName?: string | null
  productNames?: string[] | null
  store?: { id: number; name: string | null } | null
  order?: {
    id: number
    displayId: string
    status: string
    totalAmount: number
    grandTotal: number
    createdAt: string | null
  } | null
}

const STATUS_OPTIONS = ["pending", "under_review", "investigating", "resolved", "dismissed"] as const

export default function AdminReportsPage() {
  const [reports, setReports] = useState<ProblemReportListDto[]>([])
  const [statusFilter, setStatusFilter] = useState<string>("")
  const [roleFilter, setRoleFilter] = useState<string>("")
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchReports = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await adminReportsApi.list({
        status: statusFilter || undefined,
        reporterRole: roleFilter || undefined,
      })
      setReports(unwrapAdminList<ProblemReportListDto>(res.data, ["reports"]))
    } catch (err) {
      console.error("Failed to load problem reports", err)
      setError(getAdminFetchError(err, "Failed to load problem reports. Please try again."))
    } finally {
      setIsLoading(false)
    }
  }, [statusFilter, roleFilter])

  useEffect(() => {
    void fetchReports()
  }, [fetchReports])

  const getStatusBadgeClasses = (status: string) => {
    const s = status.toLowerCase()
    const map: Record<string, string> = {
      pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300",
      under_review: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300",
      investigating: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300",
      resolved: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300",
      dismissed: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-300",
    }
    return map[s] || map.pending
  }

  const getPriorityBadgeClasses = (p: string) => {
    const map: Record<string, string> = {
      low: "bg-gray-100 text-gray-600",
      medium: "bg-blue-100 text-blue-600",
      high: "bg-orange-100 text-orange-600",
      critical: "bg-red-100 text-red-600",
    }
    return map[p] || map.medium
  }

  const formatDate = (value: string | null) => {
    if (!value) return "—"
    return new Date(value).toLocaleString()
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Problem Reports</h1>
        <p className="text-muted-foreground">
          Review and manage user-submitted reports across all roles.
        </p>
      </div>

      <div className="bg-card border rounded-2xl p-4 flex flex-wrap gap-4 items-end">
        <div>
          <label className="text-xs text-muted-foreground block mb-1">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="border rounded-lg px-3 py-2 text-sm bg-background min-w-[140px]"
          >
            <option value="">All statuses</option>
            {STATUS_OPTIONS.map((s) => (
              <option key={s} value={s}>
                {s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="text-xs text-muted-foreground block mb-1">Reporter Role</label>
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="border rounded-lg px-3 py-2 text-sm bg-background min-w-[140px]"
          >
            <option value="">All roles</option>
            <option value="buyer">Buyer</option>
            <option value="seller">Seller</option>
            <option value="rider">Rider</option>
          </select>
        </div>
        <button
          type="button"
          onClick={() => void fetchReports()}
          className="px-4 py-2 rounded-lg border text-sm font-medium hover:bg-muted transition-colors"
        >
          Refresh
        </button>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4">Loading reports...</div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && reports.length === 0 && (
        <div className="bg-card border rounded-2xl p-8 text-center">
          <Icon name="exclamation" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h2 className="text-lg font-semibold mb-1">No reports found</h2>
          <p className="text-sm text-muted-foreground">
            Reports from users will appear here for review.
          </p>
        </div>
      )}

      {!isLoading && !error && reports.length > 0 && (
        <div className="bg-card border rounded-2xl overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="p-4 font-medium">ID</th>
                <th className="p-4 font-medium">From</th>
                <th className="p-4 font-medium">Type</th>
                <th className="p-4 font-medium">Description</th>
                <th className="p-4 font-medium">Against</th>
                <th className="p-4 font-medium">Status</th>
                <th className="p-4 font-medium">Submitted</th>
                <th className="p-4 font-medium" />
              </tr>
            </thead>
            <tbody>
              {reports.map((report) => (
                <tr key={report.id} className="border-b last:border-0 align-top hover:bg-muted/30">
                  <td className="p-4 font-mono text-xs">#{report.id}</td>
                  <td className="p-4">
                    <span className="capitalize text-xs font-medium bg-muted px-2 py-0.5 rounded-full">
                      {report.reporterRole}
                    </span>
                    <span className="block text-xs font-medium mt-0.5">
                      {report.reporterName || `User #${report.reporterUserId}`}
                    </span>
                  </td>
                  <td className="p-4 max-w-[120px]">
                    {report.reportType ? (
                      <span className="text-xs">{report.reportType}</span>
                    ) : (
                      <span className="text-xs text-muted-foreground">—</span>
                    )}
                  </td>
                  <td className="p-4 max-w-xs">
                    <p className="line-clamp-2">{report.description}</p>
                  </td>
                  <td className="p-4 text-xs text-muted-foreground">
                    {report.targetRole ? (
                      <>
                        <span className="capitalize font-medium text-foreground">{report.targetRole}</span>
                        <span className="block">{report.targetName || `User #${report.targetUserId}`}</span>
                      </>
                    ) : (
                      "—"
                    )}
                    {report.store && (
                      <span className="block mt-1 font-medium text-foreground">{report.store.name || `Store #${report.store.id}`}</span>
                    )}
                    {report.storeId != null && !report.store && (
                      <span className="block mt-1">Store #{report.storeId}</span>
                    )}
                    {report.order && (
                      <span className="block">{report.order.displayId} ({report.order.status})</span>
                    )}
                    {report.orderId != null && !report.order && (
                      <span className="block">Order #{report.orderId}</span>
                    )}
                    {report.productNames && report.productNames.length > 0 && (
                      <span className="block text-xs truncate max-w-[160px]" title={report.productNames.join(", ")}>
                        {report.productNames.slice(0, 2).join(", ")}{report.productNames.length > 2 ? "..." : ""}
                      </span>
                    )}
                  </td>
                  <td className="p-4">
                    <div className="flex flex-col gap-1">
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium capitalize ${getStatusBadgeClasses(report.status)}`}
                      >
                        {report.status.replace(/_/g, " ")}
                      </span>
                      <span
                        className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${getPriorityBadgeClasses(report.priority)}`}
                      >
                        {report.priority}
                      </span>
                    </div>
                  </td>
                  <td className="p-4 text-muted-foreground whitespace-nowrap text-xs">
                    {formatDate(report.createdAt)}
                  </td>
                  <td className="p-4">
                    <Link
                      href={`/admin/reports/${report.id}`}
                      className="text-primary hover:underline text-xs font-medium"
                    >
                      View
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
