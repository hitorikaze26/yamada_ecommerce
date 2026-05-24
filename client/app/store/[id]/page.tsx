"use client"

import { use, useCallback, useEffect, useState } from "react"
import Link from "next/link"
import { useSearchParams } from "next/navigation"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { StoreProfileHeader } from "@/components/store/store-profile-header"
import { StoreProfileActions } from "@/components/store/store-profile-actions"
import { StoreProfileTabs } from "@/components/store/store-profile-tabs"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { useAuth } from "@/context/auth-context"
import { useToast } from "@/hooks/use-toast"
import { buyerApi, productsApi, storesApi } from "@/lib/api"
import {
  normalizeStoreProduct,
  normalizeStoreProfile,
  normalizeStoreReview,
} from "@/lib/stores/normalize"
import type { StoreProfile, StoreReview } from "@/lib/stores/types"
import type { Product } from "@/lib/types"

interface StoreCoupon {
  id: number
  code: string
  title: string
  description?: string
}

export default function StoreProfilePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const storeId = Number(id)
  const { user, isAuthenticated, getRole } = useAuth()
  const searchParams = useSearchParams()
  const isOwnerView =
    searchParams.get("owner") === "1" &&
    user?.role === "seller" &&
    user.storeId != null &&
    Number(user.storeId) === storeId
  const { toast } = useToast()

  const [store, setStore] = useState<StoreProfile | null>(null)
  const [products, setProducts] = useState<Product[]>([])
  const [productsNew, setProductsNew] = useState<Product[]>([])
  const [productsBest, setProductsBest] = useState<Product[]>([])
  const [reviews, setReviews] = useState<StoreReview[]>([])
  const [ratingBreakdown, setRatingBreakdown] = useState<Record<string, number>>({})
  const [coupons, setCoupons] = useState<StoreCoupon[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isFollowing, setIsFollowing] = useState(false)
  const [followLoading, setFollowLoading] = useState(false)

  const loadStore = useCallback(async () => {
    if (!Number.isFinite(storeId) || storeId <= 0) {
      setError("Invalid store")
      setLoading(false)
      return
    }

    setLoading(true)
    setError(null)

    try {
      const [profileRes, productsRes, newRes, bestRes, reviewsRes] = await Promise.all([
        storesApi.getProfile(storeId),
        storesApi.getProducts(storeId, { limit: 100 }),
        storesApi.getProducts(storeId, { limit: 100, sort: "newest" }),
        storesApi.getProducts(storeId, { limit: 100, sort: "popular" }),
        storesApi.getReviews(storeId, { limit: 30 }),
      ])

      const rawStore = profileRes.data.store ?? profileRes.data
      const profile = normalizeStoreProfile(rawStore as Record<string, unknown>)
      setStore(profile)

      const mapProducts = (list: Record<string, unknown>[]) =>
        list.map((p) => normalizeStoreProduct(p, profile.name))

      let mapped = mapProducts(productsRes.data.products ?? [])
      if (mapped.length === 0 && profile.productCount > 0) {
        try {
          const fallback = await productsApi.getAll({ seller: String(storeId), limit: 100 })
          const rawList = (fallback.data?.products || fallback.data || []) as Record<string, unknown>[]
          mapped = rawList.map((p) => normalizeStoreProduct(p, profile.name))
        } catch {
          // keep empty
        }
      }

      setProducts(mapped)
      setProductsNew(mapProducts(newRes.data.products ?? []))
      setProductsBest(mapProducts(bestRes.data.products ?? []))

      const reviewList = (reviewsRes.data.reviews ?? []).map((r) =>
        normalizeStoreReview(r as Record<string, unknown>),
      )
      setReviews(reviewList)
      setRatingBreakdown(reviewsRes.data.breakdown ?? {})

      if (isAuthenticated && getRole() === "buyer") {
        const [followRes, couponsRes] = await Promise.all([
          buyerApi.getFollowingStatus(storeId).catch(() => ({ data: { following: false } })),
          buyerApi.getCoupons({ storeId }).catch(() => ({ data: { coupons: [] } })),
        ])
        setIsFollowing(Boolean(followRes.data?.following))
        const couponList = (couponsRes.data.coupons as Record<string, unknown>[]) ?? []
        setCoupons(
          couponList.map((c) => ({
            id: Number(c.id ?? 0),
            code: String(c.code ?? ""),
            title: String(c.title ?? c.code ?? ""),
            description: (c.description as string) ?? undefined,
          })),
        )
      } else {
        setCoupons([])
        setIsFollowing(false)
      }
    } catch (err) {
      console.error(err)
      setError("Store not found or could not be loaded.")
      setStore(null)
    } finally {
      setLoading(false)
    }
  }, [storeId, isAuthenticated])

  useEffect(() => {
    void loadStore()
  }, [loadStore])

  const handleToggleFollow = async () => {
    if (!store) return
    setFollowLoading(true)
    try {
      if (isFollowing) {
        await buyerApi.unfollowStore(store.storeId)
        setIsFollowing(false)
        toast({ title: "Unfollowed store" })
      } else {
        await buyerApi.followStore(store.storeId)
        setIsFollowing(true)
        toast({ title: "Following store" })
      }
    } catch {
      toast({ title: "Could not update follow status", variant: "destructive" })
    } finally {
      setFollowLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />
      <main className="flex-1">
        {loading && (
          <div className="flex items-center justify-center gap-2 py-32 text-muted-foreground">
            <Icon name="spinner" className="animate-spin" />
            Loading boutique…
          </div>
        )}

        {!loading && error && (
          <div className="max-w-lg mx-auto text-center py-32 px-4">
            <Icon name="store" size="xl" className="mx-auto text-muted-foreground mb-4" />
            <h1 className="text-xl font-semibold mb-2">Store unavailable</h1>
            <p className="text-muted-foreground text-sm mb-6">{error}</p>
            <div className="flex gap-3 justify-center">
              <Button variant="outline" onClick={() => void loadStore()}>
                Try again
              </Button>
              <Button asChild>
                <Link href="/search">Browse boutiques</Link>
              </Button>
            </div>
          </div>
        )}

        {!loading && store && (
          <>
            {isOwnerView && (
              <div className="container mx-auto px-4 pt-4">
                <div className="mb-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 rounded-xl border border-primary/30 bg-primary/5 px-4 py-3 text-sm">
                  <p>You&apos;re viewing your storefront as customers see it.</p>
                  <div className="flex flex-wrap gap-2">
                    <Button variant="outline" size="sm" asChild>
                      <Link href="/seller/branding">Edit profile</Link>
                    </Button>
                    <Button size="sm" asChild>
                      <Link href="/seller">Seller Center</Link>
                    </Button>
                  </div>
                </div>
              </div>
            )}
            <StoreProfileHeader store={store} />
            <StoreProfileActions
              storeId={store.storeId}
              storeName={store.name}
              isFollowing={isFollowing}
              followLoading={followLoading}
              onToggleFollow={() => void handleToggleFollow()}
            />
            <StoreProfileTabs
              store={store}
              products={products}
              productsNew={productsNew}
              productsBest={productsBest}
              reviews={reviews}
              ratingBreakdown={ratingBreakdown}
              coupons={coupons}
            />
          </>
        )}
      </main>
      <Footer />
    </div>
  )
}
