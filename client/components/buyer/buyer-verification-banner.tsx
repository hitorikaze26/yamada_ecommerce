"use client"

import Link from "next/link"
import { Icon } from "@/components/ui/icon"

export const BUYER_VERIFICATION_MESSAGE =
  "Your account is not yet verified. Please wait for admin approval before placing orders."

interface BuyerVerificationBannerProps {
  className?: string
  showHelpLink?: boolean
}

export function BuyerVerificationBanner({
  className = "",
  showHelpLink = true,
}: BuyerVerificationBannerProps) {
  return (
    <div
      className={`bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-2xl p-4 text-sm flex items-start gap-3 ${className}`}
      role="status"
    >
      <Icon name="info-circle" className="mt-0.5 text-amber-600 dark:text-amber-400 flex-shrink-0" />
      <div className="min-w-0">
        <p>{BUYER_VERIFICATION_MESSAGE}</p>
        {showHelpLink && (
          <Link href="/buyer/help" className="text-primary hover:underline font-medium mt-2 inline-block">
            Learn more in Help Center
          </Link>
        )}
      </div>
    </div>
  )
}

export function shouldShowBuyerVerificationBanner(
  isAuthenticated: boolean,
  role: string | null,
  isVerified: boolean,
): boolean {
  if (!isAuthenticated || role !== "buyer" || isVerified) return false
  return true
}
