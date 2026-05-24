"use client"

import { useEffect, useState } from "react"
import { buyerApi } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import { Icon } from "@/components/ui/icon"

interface Coupon {
  id: number
  code: string
  title: string
  description: string
  discountType: string
  discountValue: number
  minOrderAmount: number
  scope: string
  expiresAt?: string | null
}

export default function BuyerCouponsPage() {
  const [coupons, setCoupons] = useState<Coupon[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getCoupons()
        setCoupons(unwrapBuyerList<Coupon>(res.data, ["coupons"]))
      } catch (err) {
        console.error(err)
        setError(getBuyerFetchError(err, "Failed to load coupons."))
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [])

  const formatDiscount = (c: Coupon) => {
    if (c.discountType === "percent") return `${c.discountValue}% off`
    return `₱${c.discountValue} off`
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Vouchers & Coupons</h1>
        <p className="text-muted-foreground">Available offers for your next order.</p>
      </div>

      {loading && <div className="bg-card border rounded-2xl p-4">Loading...</div>}
      {error && <div className="text-destructive text-sm">{error}</div>}

      {!loading && !error && coupons.length === 0 && (
        <div className="bg-card border rounded-2xl p-8 text-center text-muted-foreground">
          <Icon name="ticket-alt" size="xl" className="mx-auto mb-3 opacity-50" />
          No coupons available right now.
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        {coupons.map((c) => (
          <div key={c.id} className="bg-card border rounded-2xl p-5 border-dashed">
            <div className="flex justify-between items-start gap-2">
              <div>
                <p className="font-semibold">{c.title || c.code}</p>
                <p className="text-sm text-muted-foreground mt-1">{c.description}</p>
              </div>
              <span className="text-primary font-bold whitespace-nowrap">{formatDiscount(c)}</span>
            </div>
            <div className="mt-4 flex flex-wrap gap-2 text-xs text-muted-foreground">
              <span className="px-2 py-1 bg-muted rounded-full font-mono">{c.code}</span>
              {c.minOrderAmount > 0 && <span>Min. ₱{c.minOrderAmount}</span>}
              <span className="capitalize">{c.scope}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
