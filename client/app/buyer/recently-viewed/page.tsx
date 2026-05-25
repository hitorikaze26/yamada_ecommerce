"use client"

import { useEffect, useState } from "react"
import Image from "next/image"
import Link from "next/link"
import { buyerApi, resolveImageUrl } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import { Icon } from "@/components/ui/icon"
import type { Product } from "@/lib/types"

export default function RecentlyViewedPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [recentImageErrors, setRecentImageErrors] = useState<Record<string, boolean>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getRecentlyViewed()
        const list = unwrapBuyerList<Product>(res.data, ["products"])
        setProducts(list)
      } catch (err) {
        console.error(err)
        setError(getBuyerFetchError(err, "Failed to load recently viewed."))
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [])

  const clearAll = async () => {
    try {
      await buyerApi.clearRecentlyViewed()
      setProducts([])
    } catch {
      alert("Could not clear history.")
    }
  }

  const formatPrice = (n: number) =>
    new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(n)

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-3xl font-bold mb-2">Recently Viewed</h1>
          <p className="text-muted-foreground">Pick up where you left off.</p>
        </div>
        {products.length > 0 && (
          <button type="button" onClick={() => void clearAll()} className="text-sm text-destructive hover:underline">
            Clear all
          </button>
        )}
      </div>

      {loading && <div className="bg-card border rounded-2xl p-4">Loading...</div>}
      {error && <div className="text-destructive text-sm">{error}</div>}

      {!loading && products.length === 0 && (
        <div className="bg-card border rounded-2xl p-8 text-center text-muted-foreground">
          No recently viewed products yet.
        </div>
      )}

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {products.map((p) => {
          const img = p.images?.[0] ? resolveImageUrl(p.images[0]) : "/placeholder.svg"
          return (
            <Link
              key={p.id}
              href={`/product/${encodeURIComponent(p.slug || p.id)}`}
              className="bg-card border rounded-2xl overflow-hidden hover:shadow-md transition-shadow"
            >
              <div className="aspect-square relative bg-muted">
                {recentImageErrors[p.id] ? (
                  <div className="w-full h-full flex items-center justify-center bg-muted">
                    <Icon name="image" className="text-muted-foreground/50" />
                  </div>
                ) : (
                  <Image
                    src={img || "/placeholder.svg"}
                    alt={p.name}
                    fill
                    className="object-cover"
                    onError={() => setRecentImageErrors((prev) => ({ ...prev, [p.id]: true }))}
                  />
                )}
              </div>
              <div className="p-3">
                <p className="text-sm font-medium line-clamp-2">{p.name}</p>
                <p className="text-primary font-semibold mt-1">
                  {formatPrice(p.salePrice ?? p.price)}
                </p>
              </div>
            </Link>
          )
        })}
      </div>
    </div>
  )
}
