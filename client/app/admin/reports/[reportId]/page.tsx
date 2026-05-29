"use client"

import { useCallback, useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { adminReportsApi, resolveImageUrl } from "@/lib/api"
import { toast } from "sonner"
import type { ProblemReportDto, ReportEvidenceDto, PunishmentDto, PunishmentSeverityType } from "@/lib/types"

const STATUS_OPTIONS = ["pending", "under_review", "investigating", "resolved", "dismissed"] as const
const SEVERITY_OPTIONS: PunishmentSeverityType[] = ["warning", "restriction", "ban"]

interface RestrictionOption {
  value: string
  label: string
  severity: PunishmentSeverityType
}

const RESTRICTION_OPTIONS: RestrictionOption[] = [
  { value: "", label: "None", severity: "warning" },
  { value: "messaging_disabled", label: "Messaging Disabled", severity: "restriction" },
  { value: "no_ordering", label: "No Ordering (3 days)", severity: "restriction" },
  { value: "order_limit", label: "Order Limit Reduced", severity: "restriction" },
  { value: "refund_limited", label: "Refund Request Limited", severity: "restriction" },
  { value: "review_disabled", label: "Review Posting Disabled", severity: "restriction" },
  { value: "listing_suspended", label: "Listing Suspended", severity: "restriction" },
  { value: "delivery_suspension", label: "Delivery Suspension (1 week)", severity: "restriction" },
  { value: "withdrawal_freeze", label: "Withdrawal Freeze", severity: "restriction" },
  { value: "assignment_reduced", label: "Reduced Assignments", severity: "restriction" },
  { value: "tracking_disabled", label: "Tracking Disabled / Investigation", severity: "restriction" },
  { value: "communication_restricted", label: "Communication Restricted", severity: "restriction" },
  { value: "account_removed", label: "Account / Store Removed", severity: "ban" },
  { value: "permanent_ban", label: "Permanent Account Ban", severity: "ban" },
]

export default function AdminReportDetailPage() {
  const params = useParams()
  const router = useRouter()
  const reportId = Number(params.reportId)

  const [report, setReport] = useState<ProblemReportDto | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const [adminNotes, setAdminNotes] = useState("")
  const [statusUpdating, setStatusUpdating] = useState(false)

  const [showPunishForm, setShowPunishForm] = useState(false)
  const [punishSeverity, setPunishSeverity] = useState<PunishmentSeverityType>("warning")
  const [punishUserId, setPunishUserId] = useState<number | null>(null)
  const [punishRestriction, setPunishRestriction] = useState("")
  const [punishReason, setPunishReason] = useState("")
  const [punishEndDate, setPunishEndDate] = useState("")
  const [punishing, setPunishing] = useState(false)

  const fetchReport = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await adminReportsApi.get(reportId)
      const r = res.data.report as unknown as ProblemReportDto
      setReport(r)
      setAdminNotes(r.adminNotes || "")
      if (r.targetUserId) setPunishUserId(r.targetUserId)
    } catch {
      setError("Failed to load report")
    } finally {
      setLoading(false)
    }
  }, [reportId])

  useEffect(() => {
    void fetchReport()
  }, [fetchReport])

  const handleStatusChange = async (status: string) => {
    setStatusUpdating(true)
    try {
      await adminReportsApi.update(reportId, { status })
      setReport((prev) => (prev ? { ...prev, status: status as ProblemReportDto["status"] } : prev))
      toast.success("Status updated")
    } catch {
      toast.error("Failed to update status")
    } finally {
      setStatusUpdating(false)
    }
  }

  const handleSaveNotes = async () => {
    try {
      await adminReportsApi.update(reportId, { adminNotes })
      toast.success("Notes saved")
    } catch {
      toast.error("Failed to save notes")
    }
  }

  const handleIssuePunishment = async () => {
    if (!punishUserId || !punishReason.trim()) {
      toast.error("User and reason are required")
      return
    }
    setPunishing(true)
    try {
      await adminReportsApi.issuePunishment(reportId, {
        severity: punishSeverity,
        userId: punishUserId,
        restrictionType: punishRestriction || undefined,
        reason: punishReason.trim(),
        endDate: punishEndDate || undefined,
      })
      toast.success("Punishment issued")
      setShowPunishForm(false)
      setPunishReason("")
      setPunishEndDate("")
      void fetchReport()
    } catch {
      toast.error("Failed to issue punishment")
    } finally {
      setPunishing(false)
    }
  }

  const revokePunishment = async (p: PunishmentDto) => {
    try {
      await adminReportsApi.updatePunishment(p.id, { isActive: false, endDate: new Date().toISOString() })
      toast.success("Punishment revoked")
      void fetchReport()
    } catch {
      toast.error("Failed to revoke punishment")
    }
  }

  const statusBadge = (status: string) => {
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

  const priorityBadge = (p: string) => {
    const map: Record<string, string> = {
      low: "bg-gray-100 text-gray-600",
      medium: "bg-blue-100 text-blue-600",
      high: "bg-orange-100 text-orange-600",
      critical: "bg-red-100 text-red-600",
    }
    return map[p] || map.medium
  }

  if (loading) {
    return <div className="text-center py-12 text-muted-foreground">Loading report...</div>
  }

  if (error || !report) {
    return (
      <div className="text-center py-12">
        <p className="text-destructive mb-4">{error || "Report not found"}</p>
        <button
          type="button"
          onClick={() => router.push("/admin/reports")}
          className="text-primary hover:underline"
        >
          Back to reports
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => router.push("/admin/reports")}
          className="p-2 rounded-lg hover:bg-muted"
        >
          <Icon name="chevron-left" />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Report #{report.id}</h1>
          <p className="text-sm text-muted-foreground">
            Filed by <span className="font-medium text-foreground">{report.reporterName || `User #${report.reporterUserId}`}</span>
            {" ("}{report.reporterRole}{")"}
            {report.targetRole && (
              <> against <span className="font-medium text-foreground">{report.targetName || `User #${report.targetUserId}`}</span>
              {" ("}{report.targetRole}{")"}</>
            )}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-card border rounded-2xl p-6 space-y-4">
            <div className="flex flex-wrap gap-2">
              <span className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${statusBadge(report.status)}`}>
                {report.status.replace("_", " ")}
              </span>
              <span className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${priorityBadge(report.priority)}`}>
                {report.priority}
              </span>
              {report.reportType && (
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-muted">
                  {report.reportType}
                </span>
              )}
            </div>

            <div>
              <h3 className="text-sm font-medium text-muted-foreground mb-1">Description</h3>
              <p className="text-sm whitespace-pre-wrap">{report.description}</p>
            </div>

            {report.store && (
              <div className="text-xs">
                <span className="text-muted-foreground">Store: </span>
                <span className="font-medium text-foreground">{report.store.name || `Store #${report.store.id}`}</span>
              </div>
            )}
            {report.storeId != null && !report.store && (
              <p className="text-xs text-muted-foreground">Store ID: {report.storeId}</p>
            )}
            {report.order && (
              <div className="text-xs space-y-0.5">
                <div>
                  <span className="text-muted-foreground">Order: </span>
                  <span className="font-medium text-foreground">{report.order.displayId}</span>
                  <span className="ml-1 text-muted-foreground">({report.order.status})</span>
                </div>
                {report.productNames && report.productNames.length > 0 && (
                  <div>
                    <span className="text-muted-foreground">Products: </span>
                    <span className="text-foreground">{report.productNames.join(", ")}</span>
                  </div>
                )}
              </div>
            )}
            {report.orderId != null && !report.order && (
              <p className="text-xs text-muted-foreground">Order ID: {report.orderId}</p>
            )}

            <p className="text-xs text-muted-foreground">
              Submitted: {report.createdAt ? new Date(report.createdAt).toLocaleString() : "—"}
            </p>
          </div>

          <div className="bg-card border rounded-2xl p-6 space-y-4">
            <h2 className="font-semibold">Evidence ({(report.evidence ?? []).length})</h2>
            {(report.evidence ?? []).length === 0 ? (
              <p className="text-sm text-muted-foreground">No evidence uploaded.</p>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {(report.evidence ?? []).map((ev: ReportEvidenceDto) => {
                  const fileUrl =
                    resolveImageUrl(ev.fileUrl) ||
                    resolveImageUrl(ev.filePath) ||
                    resolveImageUrl(`/static/${ev.filePath}`)
                  if (!fileUrl) return null
                  const isPdf =
                    ev.fileType === "pdf" ||
                    (ev.originalFilename || ev.filePath).toLowerCase().endsWith(".pdf")
                  if (isPdf) {
                    return (
                      <a
                        key={ev.id}
                        href={fileUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex aspect-square items-center justify-center rounded-lg border bg-muted p-3 text-center text-sm font-medium hover:bg-muted/80"
                      >
                        {ev.originalFilename || "View PDF"}
                      </a>
                    )
                  }
                  return (
                    <a
                      key={ev.id}
                      href={fileUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block aspect-square rounded-lg overflow-hidden border bg-muted hover:opacity-80 transition-opacity"
                    >
                      <img
                        src={fileUrl}
                        alt={ev.originalFilename || "Evidence"}
                        className="w-full h-full object-cover"
                      />
                    </a>
                  )
                })}
              </div>
            )}
          </div>

          <div className="bg-card border rounded-2xl p-6 space-y-4">
            <h2 className="font-semibold">Admin Notes</h2>
            <textarea
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              rows={4}
              className="w-full border rounded-xl px-4 py-3 text-sm bg-background resize-y"
              placeholder="Add internal notes about this report..."
            />
            <button
              type="button"
              onClick={() => void handleSaveNotes()}
              className="px-4 py-2 rounded-lg bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90"
            >
              Save Notes
            </button>
          </div>

          <div className="bg-card border rounded-2xl p-6 space-y-4">
            <h2 className="font-semibold">Violation History</h2>
            {report.punishments.length === 0 ? (
              <p className="text-sm text-muted-foreground">No violations recorded.</p>
            ) : (
              <div className="space-y-3">
                {report.punishments.map((p: PunishmentDto) => (
                  <div
                    key={p.id}
                    className={`border rounded-xl p-4 ${!p.isActive ? "opacity-50" : ""}`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium capitalize ${
                          p.severity === "ban"
                            ? "bg-red-100 text-red-700"
                            : p.severity === "restriction"
                              ? "bg-orange-100 text-orange-700"
                              : "bg-yellow-100 text-yellow-700"
                        }`}>
                          {p.severity}
                        </span>
                        {p.restrictionType && (
                          <span className="ml-2 text-xs text-muted-foreground">
                            {p.restrictionType.replace(/_/g, " ")}
                          </span>
                        )}
                        {!p.isActive && (
                          <span className="ml-2 text-xs text-muted-foreground">(Revoked)</span>
                        )}
                      </div>
                      <div className="flex gap-2">
                        {p.isActive && (
                          <button
                            type="button"
                            onClick={() => void revokePunishment(p)}
                            className="text-xs text-destructive hover:underline"
                          >
                            Revoke
                          </button>
                        )}
                      </div>
                    </div>
                    <p className="text-sm mt-2">{p.reason}</p>
                    <p className="text-xs text-muted-foreground mt-1">
                      {p.startDate && new Date(p.startDate).toLocaleDateString()}
                      {p.endDate && <> — {new Date(p.endDate).toLocaleDateString()}</>}
                      {p.isActive && !p.endDate && " (Permanent)"}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-card border rounded-2xl p-6 space-y-4">
            <h2 className="font-semibold">Actions</h2>

            <div>
              <label className="text-xs text-muted-foreground block mb-1">Status</label>
              <select
                value={report.status}
                disabled={statusUpdating}
                onChange={(e) => void handleStatusChange(e.target.value)}
                className="w-full border rounded-lg px-3 py-2 text-sm bg-background"
              >
                {STATUS_OPTIONS.map((s) => (
                  <option key={s} value={s}>
                    {s.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())}
                  </option>
                ))}
              </select>
            </div>

            <hr className="border-t" />

            <div>
              <button
                type="button"
                onClick={() => setShowPunishForm(!showPunishForm)}
                className="w-full py-2 rounded-lg bg-destructive text-destructive-foreground text-sm font-medium hover:bg-destructive/90"
              >
                {showPunishForm ? "Cancel" : "Issue Punishment"}
              </button>
            </div>

            {showPunishForm && (
              <div className="space-y-3 border rounded-xl p-4 bg-muted/30">
                <div>
                  <label className="text-xs text-muted-foreground block mb-1">Severity</label>
                  <select
                    value={punishSeverity}
                    onChange={(e) => {
                      setPunishSeverity(e.target.value as PunishmentSeverityType)
                      setPunishRestriction("")
                    }}
                    className="w-full border rounded-lg px-3 py-2 text-sm bg-background"
                  >
                    {SEVERITY_OPTIONS.map((s) => (
                      <option key={s} value={s}>
                        {s.charAt(0).toUpperCase() + s.slice(1)}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1">User ID</label>
                  <input
                    type="number"
                    value={punishUserId ?? ""}
                    onChange={(e) => setPunishUserId(Number(e.target.value) || null)}
                    className="w-full border rounded-lg px-3 py-2 text-sm bg-background"
                    placeholder="User ID to punish"
                  />
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1">Restriction Type</label>
                  <select
                    value={punishRestriction}
                    onChange={(e) => setPunishRestriction(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 text-sm bg-background"
                  >
                    {RESTRICTION_OPTIONS.filter(
                      (o) =>
                        o.severity === punishSeverity ||
                        (punishSeverity === "ban" && o.severity === "ban") ||
                        o.value === ""
                    ).map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1">End Date (optional)</label>
                  <input
                    type="date"
                    value={punishEndDate}
                    onChange={(e) => setPunishEndDate(e.target.value)}
                    className="w-full border rounded-lg px-3 py-2 text-sm bg-background"
                  />
                  {punishSeverity === "ban" && !punishEndDate && (
                    <p className="text-xs text-muted-foreground mt-1">Leave empty for permanent ban</p>
                  )}
                </div>

                <div>
                  <label className="text-xs text-muted-foreground block mb-1">Reason</label>
                  <textarea
                    value={punishReason}
                    onChange={(e) => setPunishReason(e.target.value)}
                    rows={3}
                    className="w-full border rounded-lg px-3 py-2 text-sm bg-background resize-y"
                    placeholder="Explain the reason for this punishment..."
                  />
                </div>

                <button
                  type="button"
                  onClick={() => void handleIssuePunishment()}
                  disabled={punishing}
                  className="w-full py-2 rounded-lg bg-destructive text-destructive-foreground text-sm font-medium hover:bg-destructive/90 disabled:opacity-50"
                >
                  {punishing ? "Issuing..." : `Issue ${punishSeverity.charAt(0).toUpperCase() + punishSeverity.slice(1)}`}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
