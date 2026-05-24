"use client"

import Link from "next/link"
import { useAuth } from "@/context/auth-context"
import { Icon } from "@/components/ui/icon"
/** Shown when a seller browses the marketplace as a customer. */
export function SellerShoppingBanner() {
  const { user } = useAuth()
  if (user?.role !== "seller") return null

  return (
    <div className="mb-4 rounded-xl border border-primary/30 bg-primary/5 px-4 py-3 text-sm">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="flex items-start gap-2">
          <Icon name="info-circle" className="text-primary mt-0.5 flex-shrink-0" />
          <p>
            You&apos;re shopping as a customer. Browse, search, and checkout like a buyer —
            orders here are separate from your seller dashboard.
          </p>
        </div>
        <Link
          href="/seller"
          className="inline-flex items-center justify-center rounded-lg bg-primary px-4 py-2 text-primary-foreground text-sm font-medium hover:bg-primary/90 whitespace-nowrap"
        >
          Back to Seller Center
        </Link>
      </div>
    </div>
  )
}
