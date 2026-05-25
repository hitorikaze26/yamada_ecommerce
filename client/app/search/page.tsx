"use client"

import { useState, useEffect, useMemo, Suspense } from "react"
import { useSearchParams, useRouter } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { ProductCard } from "@/components/product/product-card"
import { ProductFilters } from "@/components/product/product-filters"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet"
import { productsApi, resolveImageUrl } from "@/lib/api"
import { CATEGORIES, type Product } from "@/lib/types"
import { SellerShoppingBanner } from "@/components/seller/seller-shopping-banner"

const sortOptions = [
  { value: "newest", label: "Newest" },
  { value: "popular", label: "Most Popular" },
  { value: "price_asc", label: "Price: Low to High" },
  { value: "price_desc", label: "Price: High to Low" },
]

const slugify = (value: string): string => {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

function SearchContent() {
  const searchParams = useSearchParams()
  const router = useRouter()

  const query = searchParams.get("q") || ""
  const categoryParam = searchParams.get("category") || ""
  const sortParam = searchParams.get("sort") || "newest"
  const sellerParam = searchParams.get("seller") || ""

  const [filters, setFilters] = useState({
    category: categoryParam,
    sizes: [] as string[],
    colors: [] as string[],
    priceRange: [0, 5000] as [number, number],
    sellers: [] as string[],
  })

  const [sort, setSort] = useState(sortParam)
  const [isFiltersOpen, setIsFiltersOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [products, setProducts] = useState<Product[]>([])
  const [error, setError] = useState<string | null>(null)

  // Load products from backend when category or search query in URL changes
  useEffect(() => {
    const fetchProducts = async () => {
      try {
        setIsLoading(true)
        setError(null)

        const params: any = {}
        if (categoryParam) {
          params.category = categoryParam
        }
        if (query) {
          params.search = query
        }
        if (sortParam === "newest" || sortParam === "popular") {
          params.sort = sortParam
        }
        if (sellerParam) {
          params.seller = sellerParam
        }
        // Fetch a reasonable number of products; backend enforces defaults/limits
        params.limit = 40

        const res = await productsApi.getAll(params)
        const apiProducts = (res.data?.products || res.data || []) as any[]

        const detailedResponses = await Promise.all(
          apiProducts.map((p) => productsApi.getById(String(p.id))),
        )

        const mapped: Product[] = detailedResponses
          .map((detail) => (detail.data as any)?.product)
          .filter((apiProduct: any) => !!apiProduct)
          .map((apiProduct: any) => {
            const numericId = String(apiProduct.id)
            const nameForSlug = apiProduct.name ?? numericId
            const slug = `${numericId}-${slugify(nameForSlug)}`

            const apiCategories: string[] = Array.isArray(apiProduct.categories)
              ? apiProduct.categories
              : []

            let imageUrl: string | undefined = apiProduct.image_url || apiProduct.imageUrl

            // Normalize backend static paths (e.g. /static/...) to absolute URLs like the homepage does.
            if (imageUrl && !imageUrl.startsWith("http")) {
              // Ensure forward slashes and strip leading backslashes
              const normalized = String(imageUrl).replace(/\\/g, "/")
              const trimmed = normalized.replace(/^\/+/g, "")

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
              // Keep using categoryParam (category id from URL) for current filter behavior
              category: categoryParam || "",
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
              salePrice: typeof apiProduct.sale_price === "number" ? apiProduct.sale_price : undefined,
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

        setProducts(mapped)
        // Initialize price range filter based on actual product prices on first load.
        if (mapped.length > 0) {
          const prices = mapped
            .map((p) => (typeof p.salePrice === "number" ? p.salePrice : p.price))
            .filter((v) => typeof v === "number") as number[]

          if (prices.length > 0) {
            const minPrice = Math.min(...prices)
            const maxPrice = Math.max(...prices)

            setFilters((prev) => {
              const [prevMin, prevMax] = prev.priceRange
              const isDefaultRange = prevMin === 0 && prevMax === 5000

              // Avoid overwriting the range if the user already changed it.
              if (!isDefaultRange) return prev

              return {
                ...prev,
                priceRange: [minPrice, maxPrice],
              }
            })
          }
        }
      } catch (err) {
        console.error("Failed to load products", err)
        setError("Failed to load products. Please try again.")
        setProducts([])
      } finally {
        setIsLoading(false)
      }
    }

    void fetchProducts()
    // We intentionally refetch when category, search query, or sort in the URL changes;
    // size/color/price filters remain client-side.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categoryParam, query, sortParam, sellerParam])

  // Update URL when sort changes
  const handleSortChange = (value: string) => {
    setSort(value)
    const params = new URLSearchParams(searchParams.toString())
    params.set("sort", value)
    router.push(`/search?${params.toString()}`, { scroll: false })
  }

  // Filter products based on all criteria (server already narrowed by category/search)
  const filteredProducts = useMemo(() => {
    let result = [...products]

    // Search query
    if (query) {
      const lowerQuery = query.toLowerCase()
      result = result.filter((p) => {
        const name = p.name.toLowerCase()
        const description = p.description.toLowerCase()
        const category = p.category.toLowerCase()
        const subcategory = (p.subcategory || "").toLowerCase()

        return (
          name.includes(lowerQuery) ||
          description.includes(lowerQuery) ||
          category.includes(lowerQuery) ||
          subcategory.includes(lowerQuery)
        )
      })
    }

    // Category filter
    if (filters.category) {
      result = result.filter((p) => p.category === filters.category)
    }

    // Size filter
    if (filters.sizes.length > 0) {
      result = result.filter((p) => p.variations.some((v) => filters.sizes.includes(v.size)))
    }

    // Color filter
    if (filters.colors.length > 0) {
      result = result.filter((p) => p.variations.some((v) => filters.colors.includes(v.color)))
    }

    // Price range filter
    result = result.filter((p) => {
      const price = p.salePrice || p.price
      return price >= filters.priceRange[0] && price <= filters.priceRange[1]
    })

    // Sort: for newest/popular we rely on backend ordering; for price we sort client-side.
    switch (sort) {
      case "price_asc":
        result.sort((a, b) => (a.salePrice || a.price) - (b.salePrice || b.price))
        break
      case "price_desc":
        result.sort((a, b) => (b.salePrice || b.price) - (a.salePrice || a.price))
        break
    }

    return result
  }, [products, query, filters, sort])

  const categoryName = CATEGORIES.find((c) => c.id === filters.category)?.name

  const activeFiltersCount =
    (filters.category ? 1 : 0) +
    filters.sizes.length +
    filters.colors.length +
    (filters.priceRange[0] > 0 || filters.priceRange[1] < 5000 ? 1 : 0)

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-6">
          <SellerShoppingBanner />
          {/* Header */}
          <div className="mb-6">
            <h1 className="text-3xl font-bold mb-2">
              {query ? `Search results for "${query}"` : categoryName || "All Products"}
            </h1>
            <p className="text-muted-foreground">
              {filteredProducts.length} {filteredProducts.length === 1 ? "product" : "products"} found
            </p>
          </div>

          <div className="flex gap-6">
            {/* Desktop Filters Sidebar */}
            <aside className="hidden lg:block w-64 flex-shrink-0">
              <div className="sticky top-24">
                <ProductFilters filters={filters} onChange={setFilters} />
              </div>
            </aside>

            {/* Products Grid */}
            <div className="flex-1">
              {error && !isLoading && (
                <div className="mb-4 bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
                  {error}
                </div>
              )}
              {/* Toolbar */}
              <div className="flex items-center justify-between gap-4 mb-6 pb-4 border-b">
                {/* Mobile Filter Button */}
                <Sheet open={isFiltersOpen} onOpenChange={setIsFiltersOpen}>
                  <SheetTrigger asChild>
                    <Button variant="outline" className="lg:hidden relative bg-transparent">
                      <Icon name="filter" className="mr-2" />
                      Filters
                      {activeFiltersCount > 0 && (
                        <span className="absolute -top-2 -right-2 w-5 h-5 bg-primary text-primary-foreground text-xs rounded-full flex items-center justify-center">
                          {activeFiltersCount}
                        </span>
                      )}
                    </Button>
                  </SheetTrigger>
                  <SheetContent side="left" className="w-80 overflow-y-auto">
                    <SheetHeader>
                      <SheetTitle>Filters</SheetTitle>
                    </SheetHeader>
                    <div className="mt-6">
                      <ProductFilters filters={filters} onChange={setFilters} />
                    </div>
                  </SheetContent>
                </Sheet>

                {/* Active Filters Tags */}
                <div className="hidden sm:flex items-center gap-2 flex-wrap flex-1">
                  {filters.category && (
                    <span className="inline-flex items-center gap-1 px-3 py-1 bg-primary/10 text-primary text-sm rounded-full">
                      {categoryName}
                      <button
                        onClick={() => setFilters({ ...filters, category: "" })}
                        className="hover:text-primary/70"
                      >
                        <Icon name="cross" size="sm" />
                      </button>
                    </span>
                  )}
                  {filters.sizes.length > 0 && (
                    <span className="inline-flex items-center gap-1 px-3 py-1 bg-muted text-sm rounded-full">
                      {filters.sizes.length} sizes
                      <button onClick={() => setFilters({ ...filters, sizes: [] })} className="hover:text-primary">
                        <Icon name="cross" size="sm" />
                      </button>
                    </span>
                  )}
                  {filters.colors.length > 0 && (
                    <span className="inline-flex items-center gap-1 px-3 py-1 bg-muted text-sm rounded-full">
                      {filters.colors.length} colors
                      <button onClick={() => setFilters({ ...filters, colors: [] })} className="hover:text-primary">
                        <Icon name="cross" size="sm" />
                      </button>
                    </span>
                  )}
                </div>

                {/* Sort */}
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground hidden sm:inline">Sort by:</span>
                  <Select value={sort} onValueChange={handleSortChange}>
                    <SelectTrigger className="w-44">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {sortOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Products */}
              {isLoading ? (
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6">
                  {Array.from({ length: 8 }).map((_, i) => (
                    <div key={i} className="animate-pulse">
                      <div className="aspect-[3/4] bg-muted rounded-2xl mb-4" />
                      <div className="h-4 bg-muted rounded w-3/4 mb-2" />
                      <div className="h-3 bg-muted rounded w-1/2 mb-2" />
                      <div className="h-4 bg-muted rounded w-1/3" />
                    </div>
                  ))}
                </div>
              ) : filteredProducts.length === 0 ? (
                <div className="text-center py-16">
                  <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
                    <Icon name="search" size="xl" className="text-muted-foreground" />
                  </div>
                  <h3 className="text-xl font-semibold mb-2">No products found</h3>
                  <p className="text-muted-foreground mb-6">Try adjusting your filters or search for something else</p>
                  <Button
                    onClick={() =>
                      setFilters({
                        category: "",
                        sizes: [],
                        colors: [],
                        priceRange: [0, 5000],
                        sellers: [],
                      })
                    }
                  >
                    Clear all filters
                  </Button>
                </div>
              ) : (
                <AnimatePresence mode="popLayout">
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
                    {filteredProducts.map((product, index) => (
                      <motion.div
                        key={product.id}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        transition={{ delay: index * 0.05 }}
                      >
                        <ProductCard product={product} />
                      </motion.div>
                    ))}
                  </div>
                </AnimatePresence>
              )}
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}

export default function SearchPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center">
          <Icon name="spinner" className="animate-spin text-primary" size="xl" />
        </div>
      }
    >
      <SearchContent />
    </Suspense>
  )
}
