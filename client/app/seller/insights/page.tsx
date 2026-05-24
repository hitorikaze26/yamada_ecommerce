"use client"

import Link from "next/link"
import { useEffect, useState } from "react"
import { Icon } from "@/components/ui/icon"
import { sellerInsightsApi } from "@/lib/api"

interface InsightsData {
  rating: number
  reviewCount: number
  followersCount: number
  wishlistBuyerCount: number
  ratingBreakdown: Record<string, number>
  wishlistProductBreakdown: {
    productId: number
    productName: string
    wishlistCount: number
  }[]
}

interface Follower {
  userId: number
  name: string
  email: string
  followedAt?: string
}

export default function SellerInsightsPage() {
  const [insights, setInsights] = useState<InsightsData | null>(null)
  const [followers, setFollowers] = useState<Follower[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true)
        setError(null)
        const [insightsRes, followersRes] = await Promise.all([
          sellerInsightsApi.getInsights(),
          sellerInsightsApi.getFollowers(1),
        ])
        setInsights(insightsRes.data)
        setFollowers(followersRes.data?.followers ?? [])
      } catch (err: unknown) {
        const msg =
          (err as { response?: { data?: { msg?: string } } })?.response?.data
            ?.msg ?? "Failed to load store insights."
        setError(msg)
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [])

  if (loading) {
    return (
      <p className="text-sm text-muted-foreground">Loading store insights…</p>
    )
  }

  if (error || !insights) {
    return (
      <div className="rounded-2xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive">
        {error ?? "Insights unavailable."}
      </div>
    )
  }

  return (
    <div className="space-y-8 max-w-3xl">
      <div>
        <Link
          href="/seller"
          className="text-sm text-muted-foreground hover:text-primary inline-flex items-center gap-1 mb-2"
        >
          <Icon name="arrow-left" /> Dashboard
        </Link>
        <h1 className="text-2xl font-bold">Store Insights</h1>
        <p className="text-muted-foreground text-sm">
          Ratings, followers, wishlists, and feedback at a glance.
        </p>
      </div>

      <section className="bg-card border rounded-2xl p-6 space-y-4">
        <h2 className="font-semibold">Ratings overview</h2>
        <div className="flex items-end gap-4">
          <span className="text-4xl font-bold">{insights.rating.toFixed(1)}</span>
          <span className="text-muted-foreground pb-1">
            {insights.reviewCount} review{insights.reviewCount === 1 ? "" : "s"}
          </span>
        </div>
        <div className="space-y-2">
          {[5, 4, 3, 2, 1].map((star) => {
            const count = insights.ratingBreakdown?.[String(star)] ?? 0
            const pct =
              insights.reviewCount > 0
                ? Math.round((count / insights.reviewCount) * 100)
                : 0
            return (
              <div key={star} className="flex items-center gap-2 text-sm">
                <span className="w-8">{star}★</span>
                <div className="flex-1 h-2 bg-muted rounded-full overflow-hidden">
                  <div
                    className="h-full bg-amber-500 rounded-full"
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <span className="w-8 text-right text-muted-foreground">{count}</span>
              </div>
            )
          })}
        </div>
      </section>

      <section className="bg-card border rounded-2xl p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-semibold">Customer feedback</h2>
          <Link
            href="/seller/feedback"
            className="text-sm text-primary hover:underline font-medium"
          >
            Manage all
          </Link>
        </div>
        <p className="text-sm text-muted-foreground">
          Reply to reviews, hide, or archive from feedback management.
        </p>
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="font-semibold">
          Followers ({insights.followersCount})
        </h2>
        {followers.length === 0 ? (
          <p className="text-sm text-muted-foreground">No followers yet.</p>
        ) : (
          <ul className="divide-y">
            {followers.map((f) => (
              <li key={f.userId} className="py-3 flex justify-between text-sm">
                <span className="font-medium">{f.name}</span>
                <span className="text-muted-foreground">
                  {f.followedAt
                    ? new Date(f.followedAt).toLocaleDateString()
                    : ""}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="font-semibold">Wishlist insights</h2>
        <p className="text-sm text-muted-foreground">
          {insights.wishlistBuyerCount} unique buyer
          {insights.wishlistBuyerCount === 1 ? "" : "s"} saved your products.
        </p>
        {(insights.wishlistProductBreakdown ?? []).length === 0 ? (
          <p className="text-sm text-muted-foreground">No wishlist data yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted-foreground border-b">
                <th className="pb-2">Product</th>
                <th className="pb-2 text-right">Saves</th>
              </tr>
            </thead>
            <tbody>
              {insights.wishlistProductBreakdown.map((row) => (
                <tr key={row.productId} className="border-b last:border-0">
                  <td className="py-2">{row.productName}</td>
                  <td className="py-2 text-right">{row.wishlistCount}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
