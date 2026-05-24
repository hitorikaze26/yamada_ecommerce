"use client"

import { useEffect, useState, type ReactNode } from "react"
import Link from "next/link"
import { fetchSellerStoreGate } from "@/lib/seller-store-guard"
import { Button } from "@/components/ui/button"

export function PendingStoreGate({ children }: { children: ReactNode }) {
  const [canManage, setCanManage] = useState<boolean | null>(null)

  useEffect(() => {
    void fetchSellerStoreGate().then((g) => setCanManage(g.canManageStore))
  }, [])

  if (canManage === null) {
    return (
      <p className="text-sm text-muted-foreground py-12 text-center">Loading…</p>
    )
  }

  if (!canManage) {
    return (
      <div className="max-w-md mx-auto py-16 text-center space-y-4">
        <h2 className="text-xl font-semibold">Store pending approval</h2>
        <p className="text-sm text-muted-foreground">
          You cannot add or manage products until your store is approved. Check your
          account hub for status updates.
        </p>
        <Button asChild>
          <Link href="/seller">Go to dashboard</Link>
        </Button>
      </div>
    )
  }

  return <>{children}</>
}
