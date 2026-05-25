"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { buyerApi } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import { Icon } from "@/components/ui/icon"
import { ShopLogo } from "@/components/store/shop-logo"

interface FollowedStore {
  storeId: number
  name: string
  tagline?: string | null
  logoUrl?: string | null
  rating?: number
  reviewCount?: number
  isVerified?: boolean
  followedAt?: string | null
}

function formatFollowedAt(iso: string | null | undefined) {
  if (!iso) return null
  const d = new Date(iso)
  return d.toLocaleString("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })
}

export default function FollowingStoresPage() {
  const [stores, setStores] = useState<FollowedStore[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getFollowingStores()
        const raw = unwrapBuyerList<Record<string, unknown>>(res.data, ["stores"])
        setStores(
          raw.map((s) => ({
            storeId: Number(s.storeId ?? s.id ?? 0),
            name: String(s.name ?? s.store_name ?? "Store"),
            tagline: (s.tagline as string) ?? null,
            logoUrl:
              (s.logoUrl as string) ??
              (s.logo_url as string) ??
              (s.image_url as string) ??
              null,
            rating: typeof s.rating === "number" ? s.rating : undefined,
            reviewCount: typeof s.review_count === "number" ? s.review_count : undefined,
            isVerified: Boolean(s.is_verified),
            followedAt: (s.followedAt as string) ?? null,
          })),
        )
      } catch (err) {
        console.error(err)
        setError(getBuyerFetchError(err, "Failed to load following stores."))
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [])

  const unfollow = async (storeId: number) => {
    try {
      await buyerApi.unfollowStore(storeId)
      setStores((prev) => prev.filter((s) => s.storeId !== storeId))
    } catch {
      alert("Could not unfollow store.")
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Following stores</h1>
        <p className="text-muted-foreground">Boutiques you follow for updates and quicker browsing.</p>
      </div>

      {loading && (
        <div className="bg-card border rounded-2xl p-8 flex items-center justify-center gap-2 text-muted-foreground">
          <Icon name="spinner" className="animate-spin" />
          Loading…
        </div>
      )}

      {error && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!loading && stores.length === 0 && !error && (
        <div className="bg-card border rounded-2xl p-10 text-center">
          <Icon name="store" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h2 className="text-lg font-semibold mb-1">No boutiques followed yet</h2>
          <p className="text-sm text-muted-foreground mb-6">
            Follow stores you love from a product page using &quot;Follow store&quot;.
          </p>
          <Link
            href="/search"
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-medium"
          >
            <Icon name="search" />
            Browse boutiques
          </Link>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {stores.map((store) => {
          const followedLabel = formatFollowedAt(store.followedAt)

          return (
            <div
              key={store.storeId}
              className="bg-card border rounded-2xl p-4 flex gap-4 hover:border-primary/25 transition-colors"
            >
              <Link
                href={`/store/${store.storeId}`}
                className="w-16 h-16 rounded-xl bg-muted overflow-hidden flex-shrink-0 border"
              >
                <ShopLogo
                  src={store.logoUrl}
                  alt={store.name}
                  width={64}
                  height={64}
                  containerClassName="w-16 h-16"
                />
              </Link>
              <div className="flex-1 min-w-0">
                <div className="flex items-start gap-2 flex-wrap">
                  <Link
                    href={`/store/${store.storeId}`}
                    className="font-semibold hover:text-primary truncate"
                  >
                    {store.name}
                  </Link>
                  {store.isVerified && (
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-primary/10 text-primary font-medium">
                      Verified
                    </span>
                  )}
                </div>
                {store.tagline && (
                  <p className="text-xs text-muted-foreground line-clamp-2 mt-0.5">{store.tagline}</p>
                )}
                {(store.rating != null || store.reviewCount != null) && (
                  <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
                    <Icon name="star" className="text-amber-500" />
                    {store.rating?.toFixed(1) ?? "0.0"}
                    {store.reviewCount != null ? ` (${store.reviewCount} reviews)` : ""}
                  </p>
                )}
                {followedLabel && (
                  <p className="text-xs text-muted-foreground mt-2 flex items-center gap-1">
                    <Icon name="clock" size="sm" />
                    Followed {followedLabel}
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={() => void unfollow(store.storeId)}
                className="text-sm px-3 py-1.5 border rounded-lg hover:bg-muted self-start shrink-0"
              >
                Unfollow
              </button>
            </div>
          )
        })}
      </div>
    </div>
  )
}
