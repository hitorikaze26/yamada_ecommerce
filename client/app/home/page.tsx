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
import { productsApi, type ProductQueryParams } from "@/lib/api"
import { normalizeProductList } from "@/lib/normalizers"
import { SellerShoppingBanner } from "@/components/seller/seller-shopping-banner"

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

        const newestProducts = normalizeProductList(newestApi)
        const popularProducts = normalizeProductList(popularApi)

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
