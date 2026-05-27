"use client"
import { Suspense, useEffect, useState } from "react"
import Swal from "sweetalert2"
import Link from "next/link"
import Image from "next/image"
import { useRouter, useSearchParams } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { sellerApi, notificationsApi, type NotificationDto } from "@/lib/api"
import { normalizeProduct } from "@/lib/normalizers"
import type { Product } from "@/lib/types"
import { fetchSellerStoreGate } from "@/lib/seller-store-guard"
import { formatPrice } from "@/lib/format"

const tabs = ["all", "active", "draft", "out of stock"]

function SellerProductsContent() {
  const [activeTab, setActiveTab] = useState("all")
  const [searchQuery, setSearchQuery] = useState("")
  const [selectedProducts, setSelectedProducts] = useState<string[]>([])

  const [products, setProducts] = useState<
    (Product & { status: "active" | "draft" | "out of stock"; stock: number; sold: number })[]
  >([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const [lowStockNotifications, setLowStockNotifications] = useState<NotificationDto[]>([])
  const [viewProduct, setViewProduct] = useState<
    (Product & { status: "active" | "draft" | "out of stock"; stock: number; sold: number }) | null
  >(null)
  const [canManageStore, setCanManageStore] = useState(true)

  const router = useRouter()
  const searchParams = useSearchParams()

  useEffect(() => {
    void fetchSellerStoreGate().then((g) => setCanManageStore(g.canManageStore))
  }, [])

  useEffect(() => {
    // Check for creation flag in query to show success glass alert
    const created = searchParams?.get("created")
    if (created === "1") {
      setSuccessMessage("Product has been added successfully.")
      // Clean the URL so the alert does not reappear on refresh
      router.replace("/seller/products")
    }
  }, [router, searchParams])

  useEffect(() => {
    const fetchLowStockNotifications = async () => {
      try {
        const res = await notificationsApi.getAll({ role: "seller", page: "/seller/products" })
        const all = (res.data as any)?.notifications as NotificationDto[] | undefined
        if (!all) {
          setLowStockNotifications([])
          return
        }

        const filtered = all.filter((n) => {
          if (n.read) return false
          const title = (n.title || "").toLowerCase()
          return title.includes("low stock") || title.includes("stock depleted")
        })

        setLowStockNotifications(filtered)
      } catch {
        // Non-fatal; keep page usable even if notifications fail
        setLowStockNotifications([])
      }
    }

    void fetchLowStockNotifications()
  }, [])

  const handleBulkDeactivate = async () => {
    if (selectedProducts.length === 0) return

    const result = await Swal.fire({
      title: "Deactivate products",
      text: `Deactivate ${selectedProducts.length} selected product${selectedProducts.length > 1 ? "s" : ""}?`,
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Yes, deactivate",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#f97316",
    })

    if (!result.isConfirmed) return

    try {
      setError(null)
      await Promise.all(selectedProducts.map((id) => sellerApi.deactivateProduct(String(id))))
      setSuccessMessage("Selected products deactivated successfully.")
      await fetchProducts()
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to deactivate selected products.")
    }
  }

  const handleDeactivateOne = async (id: string | number) => {
    const key = String(id)

    const result = await Swal.fire({
      title: "Deactivate product",
      text: "Are you sure you want to hide this product from buyers?",
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Yes, deactivate",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#f97316",
    })

    if (!result.isConfirmed) return

    try {
      setError(null)
      await sellerApi.deactivateProduct(key)
      setSuccessMessage("Product deactivated successfully.")
      await fetchProducts()
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to deactivate product.")
    }
  }

  const handleDeleteOne = async (id: string | number) => {
    const key = String(id)
    const result = await Swal.fire({
      title: "Delete product",
      text: "Are you sure you want to permanently delete this product?",
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Yes, delete",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#ef4444",
    })

    if (!result.isConfirmed) return

    try {
      setError(null)
      await sellerApi.deleteProduct(key)
      setSuccessMessage("Product deleted successfully.")
      await fetchProducts()
      setSelectedProducts((prev) => prev.filter((pid) => pid !== key))
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to delete product.")
    }
  }

  const handleBulkDelete = async () => {
    if (selectedProducts.length === 0) return

    const result = await Swal.fire({
      title: "Delete selected products",
      text: `Delete ${selectedProducts.length} selected product${selectedProducts.length > 1 ? "s" : ""}?`,
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Yes, delete",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#ef4444",
    })

    if (!result.isConfirmed) return

    try {
      setError(null)
      await Promise.all(selectedProducts.map((id) => sellerApi.deleteProduct(String(id))))
      setSuccessMessage("Selected products deleted successfully.")
      setSelectedProducts([])
      await fetchProducts()
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to delete selected products.")
    }
  }

  const fetchProducts = async () => {
    try {
      setIsLoading(true)
      setError(null)

      // Use /seller/products (auth-inferred) — this endpoint includes the
      // real `sold` count computed from delivered/completed orders, matching
      // the mobile app's data source.
      const res = await sellerApi.getMyProducts()
      const apiProducts = (res.data?.products || res.data || []) as Product[]

      const enhanced = apiProducts.map((p) => {
        const normalized = normalizeProduct(p as unknown as Record<string, unknown>)
        const totalInventory = (p.variations || []).reduce((sum, v) => sum + (v.inventory || 0), 0)
        const stock = (p.variations || []).length > 0 ? totalInventory : ((p as any).quantity ?? totalInventory)

        let status: "active" | "draft" | "out of stock" | "under review" | "hidden" | "removed" | "restricted" = "active"
        const modStatus = ((p as any).moderationStatus as string | undefined)?.toLowerCase()
        if (modStatus === "under_review") status = "under review"
        else if (modStatus === "hidden") status = "hidden"
        else if (modStatus === "removed") status = "removed"
        else if (modStatus === "restricted") status = "restricted"
        else if (!p.visibility && !(p as any).isPublic) {
          status = "draft"
        }
        if (stock === 0) {
          status = "out of stock"
        }

        return {
          ...normalized,
          status,
          stock,
          sold: (p as any).sold ?? 0,
        }
      })

      setProducts(enhanced)
    } catch (err) {
      console.error("Failed to load seller products", err)
      setError("Failed to load products. Please try again later.")
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void fetchProducts()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const filteredProducts = products.filter((p) => {
    const matchesTab = activeTab === "all" || p.status === activeTab
    const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase())
    return matchesTab && matchesSearch
  })

  const toggleSelectAll = () => {
    if (selectedProducts.length === filteredProducts.length) {
      setSelectedProducts([])
    } else {
      setSelectedProducts(filteredProducts.map((p) => p.id))
    }
  }

  const statusColors: Record<string, string> = {
    active: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
    draft: "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400",
    "out of stock": "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
    "under review": "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300",
    hidden: "bg-gray-200 text-gray-800 dark:bg-gray-800 dark:text-gray-300",
    removed: "bg-red-200 text-red-900 dark:bg-red-900/30 dark:text-red-300",
    restricted: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-300",
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">Products</h1>
          <p className="text-muted-foreground">
            {products.length} total products
            {products.length > 0 && (
              <span className="ml-3 text-amber-600 dark:text-amber-400 font-medium">
                · {products.reduce((sum, p) => sum + p.sold, 0)} sold
              </span>
            )}
          </p>
          {lowStockNotifications.length > 0 && (
            <div className="bg-amber-50 border border-amber-200 rounded-2xl p-3 text-xs text-amber-900 space-y-1">
              <div className="flex items-center justify-between">
                <span className="font-medium flex items-center gap-1">
                  <Icon name="bell" className="h-3 w-3" /> Low stock notifications
                </span>
                <button
                  type="button"
                  className="text-[11px] text-amber-800 hover:text-amber-900 underline-offset-2 hover:underline"
                  onClick={async () => {
                    try {
                      await notificationsApi.markAllAsRead({ role: "seller", page: "/seller/products" })
                      setLowStockNotifications([])
                    } catch {
                      // ignore errors; keep existing list
                    }
                  }}
                >
                  Mark all as read
                </button>
              </div>
              <ul className="list-disc list-inside space-y-0.5">
                {lowStockNotifications.slice(0, 3).map((n) => (
                  <li key={n.id}>{n.title}</li>
                ))}
                {lowStockNotifications.length > 3 && (
                  <li className="italic">And {lowStockNotifications.length - 3} more…</li>
                )}
              </ul>
            </div>
          )}
        </div>
        {canManageStore ? (
          <Link
            href="/seller/products/new"
            className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
          >
            <Icon name="plus" />
            Add Product
          </Link>
        ) : (
          <Link
            href="/seller/branding"
            className="flex items-center gap-2 px-4 py-2 border rounded-xl text-sm font-medium text-muted-foreground"
          >
            Store pending approval
          </Link>
        )}
      </div>

      {/* Filters */}
      <div className="bg-card border rounded-2xl p-4">
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex-1 min-w-[200px]">
            <div className="relative">
              <Icon name="search" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search products..."
                className="w-full pl-10 pr-4 py-2 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
              />
            </div>
          </div>
          <div className="flex gap-2">
            {tabs.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-colors ${
                  activeTab === tab ? "bg-primary text-primary-foreground" : "bg-muted hover:bg-muted/80"
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4 text-sm text-muted-foreground">Loading products...</div>
      )}

      {!isLoading && successMessage && !error && (
        <div className="rounded-2xl border border-white/60 bg-white/70/80 bg-opacity-70 backdrop-blur-md px-4 py-3 text-sm text-emerald-800 shadow-sm flex items-center justify-between">
          <span>{successMessage}</span>
          <button
            type="button"
            className="text-xs text-emerald-900/80 hover:text-emerald-900"
            onClick={() => setSuccessMessage(null)}
          >
            Dismiss
          </button>
        </div>
      )}

      {!isLoading && error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-2xl p-4 text-sm">{error}</div>
      )}

      {!isLoading && !error && filteredProducts.length === 0 && (
        <div className="bg-card border rounded-2xl p-4 text-sm text-muted-foreground">
          No products found.
        </div>
      )}

      {/* Bulk Actions */}
      <AnimatePresence>
        {selectedProducts.length > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="bg-primary/10 border border-primary/20 rounded-2xl p-4 flex items-center justify-between"
          >
            <span className="text-sm font-medium">{selectedProducts.length} products selected</span>
            <div className="flex gap-2">
              <button
                type="button"
                onClick={handleBulkDeactivate}
                className="px-3 py-1.5 text-sm bg-background border rounded-lg hover:bg-muted"
              >
                Deactivate
              </button>
              <button
                className="px-3 py-1.5 text-sm bg-red-500 text-white rounded-lg hover:bg-red-600"
                type="button"
                onClick={handleBulkDelete}
              >
                Delete
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Products Table */}
      <div className="bg-card border rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b bg-muted/30">
                <th className="text-left py-4 px-4 w-10">
                  <input
                    type="checkbox"
                    checked={selectedProducts.length === filteredProducts.length && filteredProducts.length > 0}
                    onChange={toggleSelectAll}
                    className="w-4 h-4 rounded border-gray-300"
                  />
                </th>
                <th className="text-left py-4 px-4 font-medium text-muted-foreground">Product</th>
                <th className="text-left py-4 px-4 font-medium text-muted-foreground">Price</th>
                <th className="text-left py-4 px-4 font-medium text-muted-foreground">Stock</th>
                <th className="text-left py-4 px-4 font-medium text-muted-foreground">Sold</th>
                <th className="text-left py-4 px-4 font-medium text-muted-foreground">Status</th>
                <th className="text-right py-4 px-4 font-medium text-muted-foreground">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredProducts.map((product) => (
                <tr key={product.id} className="border-b last:border-0 hover:bg-muted/20">
                  <td className="py-4 px-4">
                    <input
                      type="checkbox"
                      checked={selectedProducts.includes(product.id)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedProducts([...selectedProducts, product.id])
                        } else {
                          setSelectedProducts(selectedProducts.filter((id) => id !== product.id))
                        }
                      }}
                      className="w-4 h-4 rounded border-gray-300"
                    />
                  </td>
                  <td className="py-4 px-4">
                    <div className="flex items-center gap-3">
                      <div className="relative w-12 h-12 rounded-lg overflow-hidden bg-muted flex-shrink-0">
                        <Image
                          src={product.images[0] || "/placeholder.svg"}
                          alt={product.name}
                          fill
                          className="object-cover"
                        />
                      </div>
                      <div>
                        <p className="font-medium line-clamp-1">{product.name}</p>
                        <p className="text-xs text-muted-foreground line-clamp-1">
                          {product.subcategory || product.category}
                        </p>
                      </div>
                    </div>
                  </td>
                  <td className="py-4 px-4">
                    {product.salePrice ? (
                      <div>
                        <p className="font-medium text-primary">{formatPrice(product.salePrice)}</p>
                        <p className="text-xs text-muted-foreground line-through">{formatPrice(product.price)}</p>
                      </div>
                    ) : (
                      <p className="font-medium">{formatPrice(product.price)}</p>
                    )}
                  </td>
                  <td className="py-4 px-4">
                    <span className={product.stock === 0 ? "text-red-500" : ""}>{product.stock}</span>
                  </td>
                  <td className="py-4 px-4">{product.sold}</td>
                  <td className="py-4 px-4">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${statusColors[product.status]}`}
                    >
                      {product.status}
                    </span>
                  </td>
                  <td className="py-4 px-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        type="button"
                        onClick={() => setViewProduct(product)}
                        className="w-8 h-8 rounded-lg hover:bg-muted flex items-center justify-center transition-colors text-primary"
                        aria-label="View product details"
                      >
                        <Icon name="eye" size="sm" />
                      </button>
                      <Link
                        href={`/seller/products/${product.id}`}
                        className={`w-8 h-8 rounded-lg hover:bg-muted flex items-center justify-center transition-colors ${
                          (product as any).canEdit === false ? "pointer-events-none opacity-40" : ""
                        }`}
                        aria-label="Edit product"
                        title={(product as any).canEdit === false ? "Editing disabled by admin" : "Edit product"}
                      >
                        <Icon name="edit" size="sm" />
                      </Link>
                      <button
                        type="button"
                        onClick={() => handleDeactivateOne(product.id)}
                        className="w-8 h-8 rounded-lg hover:bg-muted flex items-center justify-center transition-colors text-amber-500"
                      >
                        <Icon name="eye-crossed" size="sm" />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteOne(product.id)}
                        className="w-8 h-8 rounded-lg hover:bg-muted flex items-center justify-center transition-colors text-red-500"
                      >
                        <Icon name="trash" size="sm" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <AnimatePresence>
        {viewProduct && (
          <motion.div
            className="fixed inset-0 z-40 flex items-center justify-center bg-black/40"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setViewProduct(null)}
          >
            <motion.div
              className="relative max-w-2xl w-full mx-4 bg-card rounded-2xl border shadow-lg p-4 sm:p-6"
              initial={{ scale: 0.95, opacity: 0, y: 10 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.95, opacity: 0, y: 10 }}
              onClick={(e) => e.stopPropagation()}
            >
              <button
                type="button"
                className="absolute top-3 right-3 w-8 h-8 rounded-full hover:bg-muted flex items-center justify-center"
                onClick={() => setViewProduct(null)}
                aria-label="Close"
              >
                <Icon name="times" size="sm" />
              </button>

              <div className="flex gap-4 mb-4">
                <div className="relative w-24 h-24 rounded-xl overflow-hidden bg-muted flex-shrink-0">
                  <Image
                    src={viewProduct.images[0] || "/placeholder.svg"}
                    alt={viewProduct.name}
                    fill
                    className="object-cover"
                  />
                </div>
                <div className="space-y-1">
                  <h2 className="text-lg font-semibold leading-snug">{viewProduct.name}</h2>
                  <p className="text-xs text-muted-foreground">
                    {viewProduct.subcategory || viewProduct.category}
                  </p>
                  <p className="text-sm font-medium">
                    {viewProduct.salePrice
                      ? `${formatPrice(viewProduct.salePrice)} `
                      : formatPrice(viewProduct.price)}
                  </p>
                </div>
              </div>

              {viewProduct.description && (
                <div className="mb-4 max-h-40 overflow-y-auto text-sm text-muted-foreground space-y-1">
                  <p dangerouslySetInnerHTML={{ __html: viewProduct.description }} />
                </div>
              )}

              {viewProduct.variations && viewProduct.variations.length > 0 && (
                <div className="border-t pt-3 mt-2">
                  <p className="text-xs font-medium text-muted-foreground mb-2">Variations</p>
                  <div className="max-h-40 overflow-y-auto text-xs space-y-1">
                    {viewProduct.variations.map((v) => (
                      <div
                        key={v.id}
                        className="flex items-center justify-between rounded-lg bg-muted/40 px-2 py-1"
                      >
                        <span>
                          Size {v.size} · Color {v.color}
                          {v.sku && <span className="text-muted-foreground"> · SKU {v.sku}</span>}
                        </span>
                        <span className={v.inventory === 0 ? "text-red-500" : ""}>Stock: {v.inventory}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export default function SellerProductsPage() {
  return (
    <Suspense fallback={<div className="p-8 text-muted-foreground">Loading products…</div>}>
      <SellerProductsContent />
    </Suspense>
  )
}
