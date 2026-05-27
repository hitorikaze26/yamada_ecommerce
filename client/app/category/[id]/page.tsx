"use client"

import { useEffect, useState, use } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { ProductCard } from "@/components/product/product-card"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { productsApi } from "@/lib/api"
import { normalizeProductList } from "@/lib/normalizers"
import type { Product } from "@/lib/types"
import { CATEGORIES, type CategoryId } from "@/lib/types"

interface CategoryPageProps {
  params: Promise<{ id: CategoryId }>
}

export default function CategoryPage(props: CategoryPageProps) {
  const params = use(props.params)
  const router = useRouter()
  const categoryId = params.id

  const [products, setProducts] = useState<Product[]>([])
  const [isLoading, setIsLoading] = useState(true)

  const categoryMeta = CATEGORIES.find((c) => c.id === categoryId)
  const categoryName = categoryMeta?.name ?? "Category"

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        setIsLoading(true)
        const response = await productsApi.getAll({ category: categoryId })
        const apiProducts: any[] = response.data.products || []

        const normalized: Product[] = normalizeProductList(apiProducts)

        setProducts(normalized)
      } catch (error) {
        console.error("Failed to load category products", error)
      } finally {
        setIsLoading(false)
      }
    }

    fetchProducts()
  }, [categoryId])

  const handleBackToAll = () => {
    router.push("/search")
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-6">
          {/* Header & breadcrumb */}
          <div className="flex items-center justify-between gap-4 mb-6">
            <div>
              <nav className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
                <Link href="/" className="hover:text-foreground">
                  Home
                </Link>
                <Icon name="angle-right" size="sm" />
                <Link href="/search" className="hover:text-foreground">
                  Products
                </Link>
                <Icon name="angle-right" size="sm" />
                <span className="text-foreground">{categoryName}</span>
              </nav>
              <h1 className="text-3xl font-bold">{categoryName}</h1>
              <p className="text-muted-foreground text-sm mt-1">
                Browse products in this category.
              </p>
            </div>

            <Button variant="outline" className="bg-transparent" onClick={handleBackToAll}>
              <Icon name="grid" className="mr-2" />
              View all products
            </Button>
          </div>

          {/* Products */}
          {isLoading ? (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
              {Array.from({ length: 8 }).map((_, i) => (
                <div key={i} className="animate-pulse">
                  <div className="aspect-[3/4] bg-muted rounded-2xl mb-4" />
                  <div className="h-4 bg-muted rounded w-3/4 mb-2" />
                  <div className="h-3 bg-muted rounded w-1/2 mb-2" />
                  <div className="h-4 bg-muted rounded w-1/3" />
                </div>
              ))}
            </div>
          ) : products.length === 0 ? (
            <div className="text-center py-16">
              <div className="w-24 h-24 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
                <Icon name="search" size="xl" className="text-muted-foreground" />
              </div>
              <h3 className="text-xl font-semibold mb-2">No products found</h3>
              <p className="text-muted-foreground mb-6">There are no products in this category yet.</p>
              <Button onClick={handleBackToAll}>Browse all products</Button>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
              {products.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  )
}
