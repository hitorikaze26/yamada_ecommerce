"use client"

import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { buildReportPath, type ReportLinkParams } from "@/lib/report-links"

interface ReportLinkButtonProps {
  reporterRole: "buyer" | "seller" | "rider"
  params: ReportLinkParams
  variant?: "default" | "outline" | "ghost" | "destructive"
  size?: "sm" | "md"
  className?: string
  children?: React.ReactNode
}

const variantClasses: Record<NonNullable<ReportLinkButtonProps["variant"]>, string> = {
  default: "bg-destructive/10 text-destructive border border-destructive/30 hover:bg-destructive/15",
  outline: "border border-destructive/40 text-destructive hover:bg-destructive/10",
  ghost: "text-destructive hover:bg-destructive/10",
  destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/90",
}

const sizeClasses: Record<NonNullable<ReportLinkButtonProps["size"]>, string> = {
  sm: "px-3 py-1.5 text-xs",
  md: "px-4 py-2 text-sm",
}

export function ReportLinkButton({
  reporterRole,
  params,
  variant = "outline",
  size = "sm",
  className = "",
  children,
}: ReportLinkButtonProps) {
  const href = buildReportPath(reporterRole, params)

  return (
    <Link
      href={href}
      className={`inline-flex items-center gap-1.5 rounded-xl font-medium transition-colors ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
    >
      <Icon name="exclamation" className="w-3.5 h-3.5 shrink-0" />
      {children ?? "Report"}
    </Link>
  )
}
