"use client"

import { useEffect, useState } from "react"

import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { HeroCarousel } from "@/components/home/hero-carousel"
import { CategorySection } from "@/components/home/category-section"
import { ProductSection } from "@/components/home/product-section"
import { FeaturedShops } from "@/components/home/featured-shops"
import { SectionSkeleton } from "@/components/home/product-skeleton"
import { NewsletterSection } from "@/components/home/newsletter-section"
import { PromoBanner } from "@/components/home/promo-banner"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { mockCarouselSlides, mockFeaturedShops } from "@/lib/mock-data"
import type { Product } from "@/lib/types"
import { productsApi, type ProductQueryParams, resolveImageUrl } from "@/lib/api"
import { SellerShoppingBanner } from "@/components/seller/seller-shopping-banner"

const slugify = (value: string): string => {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

export default function HomePage() {
  const [newArrivals, setNewArrivals] = useState<Product[]>([])
  const [bestSellers, setBestSellers] = useState<Product[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProducts = async () => {
      setIsLoading(true)

      try {
        const newestParams: ProductQueryParams = {
          limit: 8,
          sort: "newest",
        }

        const popularParams: ProductQueryParams = {
          limit: 8,
          sort: "popular",
        }

        const [newestRes, popularRes] = await Promise.all([
          productsApi.getAll(newestParams),
          productsApi.getAll(popularParams),
        ])

        const newestApi: any[] = (newestRes.data as any)?.products ?? []
        const popularApi: any[] = (popularRes.data as any)?.products ?? []

        const [newestDetailed, popularDetailed] = await Promise.all([
          Promise.all(newestApi.map((p: any) => productsApi.getById(String(p.id)))),
          Promise.all(popularApi.map((p: any) => productsApi.getById(String(p.id)))),
        ])

        const mapToProduct = (responses: any[]): Product[] => {
          return responses
            .map((res) => (res.data as any)?.product)
            .filter((apiProduct: any) => !!apiProduct)
            .map((apiProduct: any) => {
              const apiCategories: string[] = Array.isArray(apiProduct.categories) ? apiProduct.categories : []

              const numericId = String(apiProduct.id)
              const nameForSlug = apiProduct.name ?? numericId
              const slug = `${numericId}-${slugify(nameForSlug)}`

              let imageUrl: string | undefined = apiProduct.image_url || apiProduct.imageUrl

              if (!imageUrl && Array.isArray(apiProduct.media)) {
                const firstImage = apiProduct.media.find((m: any) => m && m.media_type === "image" && m.path) ??
                  apiProduct.media[0]
                if (firstImage?.path) {
                  imageUrl = firstImage.path
                }
              }

              if (imageUrl && !imageUrl.startsWith("http")) {
                const normalized = imageUrl.replace(/\\/g, "/")
                const trimmed = normalized.replace(/^\/+/, "")

                if (trimmed.startsWith("static/")) {
                  imageUrl = resolveImageUrl(`/${trimmed}`) ?? undefined
                } else {
                  imageUrl = resolveImageUrl(`/static/${trimmed}`) ?? undefined
                }
              }

              return {
                id: numericId,
                slug,
                name: apiProduct.name ?? "",
                category: apiCategories[0] ?? "",
                subcategory: apiProduct.subcategory ?? undefined,
                categories: apiCategories,
                description: apiProduct.description ?? "",
                images: imageUrl ? [imageUrl] : [],
                variations:
                  Array.isArray(apiProduct.variations)
                    ? apiProduct.variations.map((v: any) => ({
                        id: String(v.id),
                        size: v.size ?? "",
                        color: v.color ?? "",
                  colorHex: v.colorHex ?? undefined,
                        sku: v.sku ?? "",
                        inventory: typeof v.inventory === "number" ? v.inventory : 0,
                        price: typeof v.price === "number" ? v.price : undefined,
                      }))
                    : [],
                price: typeof apiProduct.price === "number" ? apiProduct.price : 0,
                salePrice: undefined,
                rating: typeof apiProduct.rating === "number" ? apiProduct.rating : 0,
                reviewCount: typeof apiProduct.review_count === "number" ? apiProduct.review_count : 0,
                sellerId: apiProduct.store_id ? String(apiProduct.store_id) : "",
                sellerName: apiProduct.seller_name ?? "",
                sellerLogo: apiProduct.seller_logo ?? undefined,
                visibility: true,
                createdAt: apiProduct.created_at ?? new Date().toISOString(),
                updatedAt: apiProduct.updated_at ?? apiProduct.created_at ?? new Date().toISOString(),
              }
            })
        }

        const newestProducts = mapToProduct(newestDetailed)
        const popularProducts = mapToProduct(popularDetailed)

        setNewArrivals(newestProducts)
        setBestSellers(popularProducts)
        setError(null)
      } catch (error) {
        console.error("Failed to load products for homepage", error)
        setNewArrivals([])
        setBestSellers([])
        setError("Failed to load products. Please try again later.")
      } finally {
        setIsLoading(false)
      }
    }

    void fetchProducts()
  }, [])

  const hasProducts = newArrivals.length > 0 || bestSellers.length > 0

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />
      <main className="flex-1">
        <div className="container mx-auto px-4 pt-4">
          <SellerShoppingBanner />
        </div>
        <HeroCarousel slides={mockCarouselSlides} />
        <CategorySection />
        <PromoBanner />

        {/* Products Section */}
        {isLoading ? (
          <>
            <SectionSkeleton />
            <SectionSkeleton />
          </>
        ) : error ? (
          <section className="py-16">
            <div className="container mx-auto px-4">
              <div className="max-w-md mx-auto text-center">
                <div className="w-16 h-16 rounded-full bg-destructive/10 flex items-center justify-center mx-auto mb-4">
                  <Icon name="exclamation-circle" className="text-destructive" size="xl" />
                </div>
                <h3 className="text-lg font-semibold mb-2">Unable to load products</h3>
                <p className="text-muted-foreground text-sm mb-4">{error}</p>
                <Button onClick={() => window.location.reload()} variant="outline">
                  Try Again
                </Button>
              </div>
            </div>
          </section>
        ) : !hasProducts ? (
          <section className="py-16">
            <div className="container mx-auto px-4">
              <div className="max-w-md mx-auto text-center">
                <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
                  <Icon name="package" className="text-muted-foreground" size="xl" />
                </div>
                <h3 className="text-lg font-semibold mb-2">No products available</h3>
                <p className="text-muted-foreground text-sm">
                  We&apos;re preparing our collection. Please check back soon for amazing finds!
                </p>
              </div>
            </div>
          </section>
        ) : (
          <>
            <ProductSection
              title="New Arrivals"
              subtitle="Fresh styles just for you"
              products={newArrivals}
              viewAllHref="/search?sort=newest"
            />
            <ProductSection
              title="Best Sellers"
              subtitle="Our most loved pieces"
              products={bestSellers}
              viewAllHref="/search?sort=popular"
            />
          </>
        )}

        <FeaturedShops shops={mockFeaturedShops} />
        <NewsletterSection />
      </main>
      <Footer />
    </div>
  )
}
