export type ReportTargetRole = "buyer" | "seller" | "rider"

export interface ReportLinkParams {
  targetRole: ReportTargetRole
  targetUserId?: number | string
  orderId?: number | string
  storeId?: number | string
  label?: string
}

export function buildReportPath(
  reporterRole: "buyer" | "seller" | "rider",
  params: ReportLinkParams,
): string {
  const base = `/${reporterRole}/report`
  const q = new URLSearchParams()
  q.set("targetRole", params.targetRole)
  if (params.targetUserId != null) q.set("targetUserId", String(params.targetUserId))
  if (params.orderId != null) q.set("orderId", String(params.orderId))
  if (params.storeId != null) q.set("storeId", String(params.storeId))
  if (params.label) q.set("label", params.label)
  return `${base}?${q.toString()}`
}

export function reportTargetLabel(targetRole: ReportTargetRole, label?: string | null): string {
  if (label?.trim()) return label.trim()
  switch (targetRole) {
    case "buyer":
      return "buyer"
    case "seller":
      return "store / seller"
    case "rider":
      return "rider"
    default:
      return "user"
  }
}
