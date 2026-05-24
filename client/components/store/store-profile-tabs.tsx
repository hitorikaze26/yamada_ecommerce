"use client"

import Link from "next/link"
import { useMemo, useState } from "react"
import { ProductCard } from "@/components/product/product-card"
import { Icon } from "@/components/ui/icon"
import { Input } from "@/components/ui/input"
import { CATEGORY_NAME_TO_ID, type Product } from "@/lib/types"
import type { StoreProfile, StoreReview } from "@/lib/stores/types"

export type StoreTabId = "products" | "new" | "best" | "reviews" | "about"

const TABS: { id: StoreTabId; label: string }[] = [
  { id: "products", label: "Products" },
  { id: "new", label: "New" },
  { id: "best", label: "Best" },
  { id: "reviews", label: "Reviews" },
  { id: "about", label: "About" },
]

interface StoreCoupon {
  id: number
  code: string
  title: string
  description?: string
}

interface StoreProfileTabsProps {
  store: StoreProfile
  products: Product[]
  productsNew: Product[]
  productsBest: Product[]
  reviews: StoreReview[]
  ratingBreakdown: Record<string, number>
  coupons?: StoreCoupon[]
  onTabChange?: (tab: StoreTabId) => void
}

export function StoreProfileTabs({
  store,
  products,
  productsNew,
  productsBest,
  reviews,
  ratingBreakdown,
  coupons = [],
  onTabChange,
}: StoreProfileTabsProps) {
  const [activeTab, setActiveTab] = useState<StoreTabId>("products")
  const [search, setSearch] = useState("")
  const [subcategory, setSubcategory] = useState<string | null>(null)

  const subcategories = useMemo(() => {
    const set = new Set<string>()
    for (const p of products) {
      if (p.subcategory) set.add(p.subcategory)
    }
    return Array.from(set).sort()
  }, [products])

  const activeProducts = useMemo(() => {
    const base =
      activeTab === "new" ? productsNew : activeTab === "best" ? productsBest : products
    return base.filter((p) => {
      if (subcategory && p.subcategory !== subcategory) return false
      if (!search.trim()) return true
      const q = search.toLowerCase()
      return (
        p.name.toLowerCase().includes(q) ||
        (p.subcategory?.toLowerCase().includes(q) ?? false) ||
        p.categories?.some((c) => c.toLowerCase().includes(q))
      )
    })
  }, [activeTab, products, productsNew, productsBest, search, subcategory])

  const selectTab = (id: StoreTabId) => {
    setActiveTab(id)
    onTabChange?.(id)
  }

  const totalReviews = Object.values(ratingBreakdown).reduce((a, b) => a + b, 0)

  return (
    <div className="px-4 sm:px-6 pb-10">
      <div className="sticky top-16 z-30 -mx-4 sm:-mx-6 px-4 sm:px-6 py-2 bg-background/95 backdrop-blur border-b mb-4">
        <div className="flex gap-1 overflow-x-auto scrollbar-hide">
          {TABS.map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => selectTab(tab.id)}
              className={`shrink-0 px-4 py-2 text-sm font-medium rounded-full transition-colors ${
                activeTab === tab.id
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-muted"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {(activeTab === "products" || activeTab === "new" || activeTab === "best") && (
        <div className="space-y-4">
          {activeTab === "products" && (
            <div className="flex flex-col sm:flex-row gap-3">
              <div className="relative flex-1">
                <Icon
                  name="search"
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                  size="sm"
                />
                <Input
                  placeholder="Search in this boutique…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="pl-9"
                />
              </div>
            </div>
          )}

          {activeTab === "products" && subcategories.length > 0 && (
            <div className="flex gap-2 overflow-x-auto pb-1">
              <button
                type="button"
                onClick={() => setSubcategory(null)}
                className={`shrink-0 px-3 py-1 text-xs rounded-full border ${
                  !subcategory ? "bg-primary text-primary-foreground border-primary" : "hover:bg-muted"
                }`}
              >
                All
              </button>
              {subcategories.map((sub) => (
                <button
                  key={sub}
                  type="button"
                  onClick={() => setSubcategory(sub)}
                  className={`shrink-0 px-3 py-1 text-xs rounded-full border ${
                    subcategory === sub
                      ? "bg-primary text-primary-foreground border-primary"
                      : "hover:bg-muted"
                  }`}
                >
                  {sub}
                </button>
              ))}
            </div>
          )}

          {activeProducts.length === 0 ? (
            <div className="text-center py-16 text-muted-foreground">
              <Icon name="box" size="xl" className="mx-auto mb-3 opacity-50" />
              <p>No products found</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 sm:gap-4">
              {activeProducts.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === "reviews" && (
        <div className="space-y-6 max-w-2xl">
          {totalReviews > 0 && (
            <div className="space-y-2">
              {[5, 4, 3, 2, 1].map((star) => {
                const count = ratingBreakdown[String(star)] ?? 0
                const pct = totalReviews ? Math.round((count / totalReviews) * 100) : 0
                return (
                  <div key={star} className="flex items-center gap-2 text-sm">
                    <span className="w-8">{star}★</span>
                    <div className="flex-1 h-2 rounded-full bg-muted overflow-hidden">
                      <div className="h-full bg-amber-500 rounded-full" style={{ width: `${pct}%` }} />
                    </div>
                    <span className="w-8 text-muted-foreground text-right">{count}</span>
                  </div>
                )
              })}
            </div>
          )}

          {reviews.length === 0 ? (
            <p className="text-muted-foreground text-center py-12">No reviews yet</p>
          ) : (
            <ul className="space-y-4">
              {reviews.map((review) => (
                <li key={review.id} className="border rounded-2xl p-4 bg-card">
                  <div className="flex items-center gap-1 mb-2">
                    {Array.from({ length: 5 }).map((_, i) => (
                      <Icon
                        key={i}
                        name="star"
                        size="sm"
                        className={i < review.rating ? "text-amber-500" : "text-muted-foreground/30"}
                      />
                    ))}
                    {review.verifiedPurchase && (
                      <span className="ml-2 text-[10px] text-primary">Verified purchase</span>
                    )}
                  </div>
                  {review.comment && <p className="text-sm mb-3">{review.comment}</p>}
                  {review.productId && review.productName && (
                    <Link
                      href={`/product/${review.productSlug ?? review.productId}`}
                      className="flex items-center gap-2 text-sm text-primary hover:underline"
                    >
                      {review.productImage && (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={review.productImage}
                          alt=""
                          className="w-10 h-10 rounded-lg object-cover border"
                        />
                      )}
                      {review.productName}
                    </Link>
                  )}
                  <p className="text-xs text-muted-foreground mt-2">
                    {review.buyerName}
                    {review.createdAt &&
                      ` · ${new Date(review.createdAt).toLocaleDateString("en-PH", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      })}`}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {activeTab === "about" && (
        <div className="space-y-6 max-w-2xl">
          {store.description && (
            <section>
              <h3 className="font-semibold mb-2">About</h3>
              <p className="text-sm text-muted-foreground whitespace-pre-wrap">{store.description}</p>
            </section>
          )}

          {store.categories.length > 0 && (
            <section>
              <h3 className="font-semibold mb-2">Categories</h3>
              <div className="flex flex-wrap gap-2">
                {store.categories.map((cat) => {
                  const categoryId = CATEGORY_NAME_TO_ID[cat]
                  if (!categoryId) {
                    return (
                      <span key={cat} className="text-xs px-3 py-1 rounded-full bg-muted">
                        {cat}
                      </span>
                    )
                  }
                  return (
                    <Link
                      key={cat}
                      href={`/search?category=${encodeURIComponent(categoryId)}`}
                      className="text-xs px-3 py-1 rounded-full bg-muted hover:bg-primary/10 hover:text-primary transition-colors"
                    >
                      {cat}
                    </Link>
                  )
                })}
              </div>
            </section>
          )}

          <section className="grid sm:grid-cols-2 gap-4 text-sm">
            <div className="border rounded-xl p-4">
              <p className="text-muted-foreground text-xs mb-1">Business hours</p>
              <p className="font-medium">{store.businessHours || "—"}</p>
            </div>
            <div className="border rounded-xl p-4">
              <p className="text-muted-foreground text-xs mb-1">Shipping</p>
              <p className="font-medium">{store.shippingSummary}</p>
            </div>
            <div className="border rounded-xl p-4">
              <p className="text-muted-foreground text-xs mb-1">Response</p>
              <p className="font-medium">{store.responseTime}</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {store.responseRate}% response rate
              </p>
            </div>
            <div className="border rounded-xl p-4">
              <p className="text-muted-foreground text-xs mb-1">Orders completed</p>
              <p className="font-medium">{store.completedOrders.toLocaleString()}</p>
            </div>
          </section>

          {store.trustBadges.length > 0 && (
            <section>
              <h3 className="font-semibold mb-2">Trust badges</h3>
              <div className="flex flex-wrap gap-2">
                {store.trustBadges.map((badge) => (
                  <span
                    key={badge.id}
                    className="text-xs px-3 py-1.5 rounded-full border bg-primary/5 border-primary/20"
                    title={badge.description}
                  >
                    {badge.label}
                  </span>
                ))}
              </div>
            </section>
          )}

          <section>
            <h3 className="font-semibold mb-2">Policies</h3>
            <ul className="text-sm text-muted-foreground space-y-1">
              <li>
                Cancellation:{" "}
                {store.policies.allowCancellation
                  ? `within ${store.policies.maxCancellationHours}h`
                  : "not allowed"}
              </li>
              <li>
                Returns:{" "}
                {store.policies.allowReturns
                  ? `${store.policies.returnPeriodDays} days`
                  : "not accepted"}
              </li>
            </ul>
          </section>

          {coupons.length > 0 && (
            <section>
              <h3 className="font-semibold mb-2">Available vouchers</h3>
              <div className="space-y-2">
                {coupons.map((c) => (
                  <div
                    key={c.id}
                    className="flex items-center justify-between border rounded-xl px-4 py-3 bg-primary/5"
                  >
                    <div>
                      <p className="font-medium text-sm">{c.title || c.code}</p>
                      {c.description && (
                        <p className="text-xs text-muted-foreground">{c.description}</p>
                      )}
                    </div>
                    <code className="text-sm font-mono bg-background px-2 py-1 rounded border">
                      {c.code}
                    </code>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  )
}
