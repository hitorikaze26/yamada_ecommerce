"use client"

import { useEffect, useState } from "react"
import { adminApi, productsApi, API_BASE_ORIGIN, resolveImageUrl } from "@/lib/api"
import { Icon } from "@/components/ui/icon"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { toast } from "sonner"
import type { SizeChartMatrix } from "@/lib/types"

interface AdminProduct {
  id?: number | string
  name?: string
  price?: number
  isLive?: boolean
  moderationStatus?: string
  moderationReason?: string
  status?: string
  storeName?: string
  [key: string]: any
}

type ModerationFilter = "all" | "active" | "under_review" | "hidden" | "removed" | "restricted"

const moderationBadge: Record<string, string> = {
  active: "bg-green-100 text-green-800",
  under_review: "bg-amber-100 text-amber-800",
  hidden: "bg-gray-100 text-gray-800",
  removed: "bg-red-100 text-red-800",
  restricted: "bg-orange-100 text-orange-800",
}

export default function AdminProductsPage() {
  const [products, setProducts] = useState<AdminProduct[]>([])
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState<ModerationFilter>("all")
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState("")
  const [selectedProduct, setSelectedProduct] = useState<any | null>(null)
  const [isDetailLoading, setIsDetailLoading] = useState(false)
  const [isDetailOpen, setIsDetailOpen] = useState(false)
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [isBulkLoading, setIsBulkLoading] = useState(false)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Helper views for extended fields on the selected product
  let parsedTags: string[] | undefined
  if (selectedProduct?.tags_json) {
    try {
      const raw =
        typeof selectedProduct.tags_json === "string"
          ? JSON.parse(selectedProduct.tags_json)
          : selectedProduct.tags_json
      if (Array.isArray(raw)) {
        parsedTags = raw.map((t: any) => String(t)).filter(Boolean)
      } else if (typeof raw === "string") {
        parsedTags = raw
          .split(",")
          .map((t) => t.trim())
          .filter(Boolean)
      }
    } catch {
      parsedTags = undefined
    }
  }

  let parsedLegacySizeChart:
    | {
        bust?: string
        waist?: string
        hips?: string
        length?: string
        otherNotes?: string
      }
    | undefined
  let parsedMatrixSizeChart: SizeChartMatrix | undefined

  if (selectedProduct?.size_chart_json) {
    try {
      const raw =
        typeof selectedProduct.size_chart_json === "string"
          ? JSON.parse(selectedProduct.size_chart_json)
          : selectedProduct.size_chart_json

      if (raw && typeof raw === "object" && "categoryKey" in raw && Array.isArray((raw as any).sizes)) {
        parsedMatrixSizeChart = raw as SizeChartMatrix
      } else {
        parsedLegacySizeChart = {
          bust: raw.bust ?? undefined,
          waist: raw.waist ?? undefined,
          hips: raw.hips ?? undefined,
          length: raw.length ?? undefined,
          otherNotes: raw.other_notes ?? undefined,
        }
      }
    } catch {
      parsedLegacySizeChart = undefined
      parsedMatrixSizeChart = undefined
    }
  }

  const fetchProducts = async () => {
    setIsLoading(true)
    setError("")

    try {
      const params: any = {}
      if (search.trim()) {
        params.search = search.trim()
      }
      if (status !== "all") {
        params.status = status
      }

      const response = await adminApi.getProducts(params)
      const data = (response.data as any) || []
      const list: AdminProduct[] = Array.isArray(data.products)
        ? data.products
        : Array.isArray(data)
        ? data
        : []

      setProducts(list)
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to load products.")
      setProducts([])
    } finally {
      setIsLoading(false)
    }
  }

  const handleViewDetails = async (id: number | string) => {
    setIsDetailLoading(true)
    setSelectedProduct(null)
    setIsDetailOpen(true)
    try {
      const response = await productsApi.getById(String(id))
      const data = (response.data as any)?.product
      setSelectedProduct(data || null)
    } catch (err) {
      setSelectedProduct(null)
    } finally {
      setIsDetailLoading(false)
    }
  }

  const handleModeration = async (id: number | string, modStatus: string, reason?: string) => {
    try {
      await adminApi.updateProductModeration(Number(id), { status: modStatus, reason })
      toast.success(`Product marked as ${modStatus.replace("_", " ")}`)
      await fetchProducts()
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Moderation action failed")
    }
  }

  const handleReject = async (id: number | string) => {
    try {
      const res = await adminApi.rejectProduct(Number(id))
      if (res.data?.already_rejected) {
        toast.info(res.data?.msg || "Product is already rejected")
      } else {
        toast.success(res.data?.msg || "Product rejected successfully")
      }
      await fetchProducts()
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to reject product")
    }
  }

  const toggleSelectAll = () => {
    if (selectedIds.length === products.length) {
      setSelectedIds([])
    } else {
      setSelectedIds(products.map((p) => String(p.id)))
    }
  }

  const toggleSelectOne = (id: number | string) => {
    const key = String(id)
    setSelectedIds((prev) =>
      prev.includes(key) ? prev.filter((x) => x !== key) : [...prev, key],
    )
  }

  const handleBulkApprove = async () => {
    if (selectedIds.length === 0) return
    setIsBulkLoading(true)
    let successCount = 0
    let alreadyApprovedCount = 0
    
    try {
      const results = await Promise.all(
        selectedIds.map((id) => adminApi.approveProduct(Number(id)).catch((err: any) => err))
      )
      
      results.forEach((res: any) => {
        if (res?.data?.already_approved) {
          alreadyApprovedCount++
        } else if (res?.data?.msg?.includes("approved")) {
          successCount++
        }
      })
      
      if (successCount > 0) {
        toast.success(`${successCount} product${successCount > 1 ? "s" : ""} approved`)
      }
      if (alreadyApprovedCount > 0) {
        toast.info(`${alreadyApprovedCount} already approved`)
      }
      
      setSelectedIds([])
      await fetchProducts()
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Bulk approve failed")
    } finally {
      setIsBulkLoading(false)
    }
  }

  const handleBulkReject = async () => {
    if (selectedIds.length === 0) return
    setIsBulkLoading(true)
    let successCount = 0
    let alreadyRejectedCount = 0
    
    try {
      const results = await Promise.all(
        selectedIds.map((id) => adminApi.rejectProduct(Number(id)).catch((err: any) => err))
      )
      
      results.forEach((res: any) => {
        if (res?.data?.already_rejected) {
          alreadyRejectedCount++
        } else if (res?.data?.msg?.includes("rejected")) {
          successCount++
        }
      })
      
      if (successCount > 0) {
        toast.success(`${successCount} product${successCount > 1 ? "s" : ""} rejected`)
      }
      if (alreadyRejectedCount > 0) {
        toast.info(`${alreadyRejectedCount} already rejected`)
      }
      
      setSelectedIds([])
      await fetchProducts()
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Bulk reject failed")
    } finally {
      setIsBulkLoading(false)
    }
  }

  useEffect(() => {
    void fetchProducts()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Products</h1>
          <p className="text-sm text-muted-foreground">Post-publish moderation — products go live immediately; use actions to hide, remove, or request edits.</p>
        </div>
      </div>

      <div className="flex flex-wrap gap-3 items-end">
        <div className="flex flex-col gap-1 min-w-[200px]">
          <label className="text-xs font-medium text-muted-foreground">Search</label>
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search products"
          />
        </div>

        <div className="flex flex-col gap-1 min-w-[160px]">
          <label className="text-xs font-medium text-muted-foreground">Status</label>
          <select
            className="border rounded-md px-3 py-2 text-sm bg-background"
            value={status}
            onChange={(e) => setStatus(e.target.value as any)}
          >
            <option value="all">All</option>
            <option value="active">Active</option>
            <option value="under_review">Under review</option>
            <option value="hidden">Hidden</option>
            <option value="removed">Removed</option>
            <option value="restricted">Restricted</option>
          </select>
        </div>

        <Button onClick={fetchProducts} disabled={isLoading}>
          {isLoading ? (
            <>
              <Icon name="spinner" className="mr-2 animate-spin" /> Loading
            </>
          ) : (
            "Load products"
          )}
        </Button>
      </div>

      {successMessage && (
        <div className="rounded-xl border border-white/60 bg-white/70 bg-opacity-70 backdrop-blur-md px-4 py-3 text-sm text-emerald-800 shadow flex items-center justify-between">
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

      {error && (
        <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
          <Icon name="exclamation-circle" />
          {error}
        </div>
      )}

      {/* Bulk actions */}
      {selectedIds.length > 0 && (
        <div className="flex items-center justify-between rounded-xl border bg-muted/40 px-4 py-2 text-xs mb-2">
          <span className="text-muted-foreground">
            {selectedIds.length} product{selectedIds.length > 1 ? "s" : ""} selected
          </span>
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={handleBulkApprove}
              disabled={isBulkLoading}
            >
              Approve selected
            </Button>
            <Button
              variant="destructive"
              size="sm"
              onClick={handleBulkReject}
              disabled={isBulkLoading}
            >
              Reject selected
            </Button>
          </div>
        </div>
      )}

      <div className="border rounded-xl overflow-hidden">
        <table className="min-w-full text-sm">
          <thead className="bg-muted/50">
            <tr>
              <th className="px-4 py-3 text-left">
                <input
                  type="checkbox"
                  className="w-4 h-4 rounded border-gray-300"
                  checked={products.length > 0 && selectedIds.length === products.length}
                  onChange={toggleSelectAll}
                />
              </th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">ID</th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">Product</th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">Shop</th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">Price</th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">Status</th>
              <th className="text-left px-4 py-3 font-medium text-muted-foreground">Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <tr key={i} className="border-t">
                  <td className="px-4 py-3"><Skeleton className="h-4 w-4" /></td>
                  <td className="px-4 py-3"><Skeleton className="h-4 w-8" /></td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <Skeleton className="h-10 w-10 rounded-lg" />
                      <Skeleton className="h-4 w-32" />
                    </div>
                  </td>
                  <td className="px-4 py-3"><Skeleton className="h-4 w-24" /></td>
                  <td className="px-4 py-3"><Skeleton className="h-4 w-16" /></td>
                  <td className="px-4 py-3"><Skeleton className="h-5 w-14" /></td>
                  <td className="px-4 py-3"><Skeleton className="h-8 w-24" /></td>
                </tr>
              ))
            ) : products.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-12 text-center text-muted-foreground">
                  <div className="flex flex-col items-center gap-3">
                    <Icon name="box-open" className="text-4xl text-muted-foreground/50" />
                    <p>No products to display.</p>
                  </div>
                </td>
              </tr>
            ) : (
              products.map((product) => {
                const modStatus = (product.moderationStatus || product.status || "active").toLowerCase()
                const badgeClass = moderationBadge[modStatus] ?? "bg-muted text-muted-foreground"
                const thumbnailUrl = product.thumbnail_url || 
                  (product.media && product.media[0] ? `${API_BASE_ORIGIN}/static/${product.media[0].path}` : null)
                
                return (
                  <tr key={String(product.id ?? Math.random())} className="border-t hover:bg-muted/30 transition-colors">
                    <td className="px-4 py-3">
                      <input
                        type="checkbox"
                        className="w-4 h-4 rounded border-gray-300"
                        checked={selectedIds.includes(String(product.id))}
                        onChange={() => product.id && toggleSelectOne(product.id)}
                      />
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">#{product.id}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        {thumbnailUrl ? (
                          <img 
                            src={thumbnailUrl} 
                            alt={product.name}
                            className="h-10 w-10 rounded-lg object-cover border"
                          />
                        ) : (
                          <div className="h-10 w-10 rounded-lg bg-muted flex items-center justify-center border">
                            <Icon name="image" className="text-muted-foreground" size="sm" />
                          </div>
                        )}
                        <span className="font-medium truncate max-w-[200px]">{product.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {product.storeName || product.seller_name || product.store?.name || "-"}
                    </td>
                    <td className="px-4 py-3 font-medium">
                      {typeof product.price === "number" ? `₱${product.price.toFixed(2)}` : "-"}
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={badgeClass}>
                        {modStatus.replace(/_/g, " ")}
                      </Badge>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 flex-wrap">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleViewDetails(product.id!)}
                          className="h-8 w-8 p-0"
                          title="View details"
                        >
                          <Icon name="eye" size="sm" />
                        </Button>
                        {modStatus !== "active" && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleModeration(product.id!, "active", "Restored by admin")}
                            className="h-8 px-2 text-xs"
                          >
                            Restore
                          </Button>
                        )}
                        {modStatus === "active" && (
                          <>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleModeration(product.id!, "hidden", "Hidden by admin")}
                              className="h-8 px-2 text-xs"
                            >
                              Hide
                            </Button>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleModeration(product.id!, "under_review")}
                              className="h-8 px-2 text-xs"
                            >
                              Review
                            </Button>
                          </>
                        )}
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleModeration(product.id!, "removed", "Removed by admin")}
                          className="h-8 px-2 text-xs text-red-600"
                        >
                          Remove
                        </Button>
                      </div>
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {isDetailOpen && (
        <div
          className="fixed inset-0 z-40 flex items-center justify-center bg-black/40"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setIsDetailOpen(false)
              setSelectedProduct(null)
            }
          }}
        >
          <div className="relative max-h-[90vh] w-full max-w-3xl overflow-y-auto rounded-xl bg-background p-6 shadow-xl">
            <button
              type="button"
              className="absolute right-4 top-4 text-muted-foreground hover:text-foreground"
              onClick={() => {
                setIsDetailOpen(false)
                setSelectedProduct(null)
              }}
            >
              <Icon name="times" />
            </button>

            {isDetailLoading && (
              <div className="mt-4 text-sm text-muted-foreground flex items-center gap-2">
                <Icon name="spinner" className="animate-spin" /> Loading product details...
              </div>
            )}

            {selectedProduct && !isDetailLoading && (
              <div className="space-y-4 pt-2">
                <div className="space-y-3">
                  <h2 className="text-lg font-semibold">Product Details</h2>

                  {/* Highlighted shop & categories at the top */}
                  {(selectedProduct.seller_name ||
                    (Array.isArray(selectedProduct.categories) && selectedProduct.categories.length > 0)) && (
                    <div className="rounded-lg border bg-muted/40 px-3 py-2 text-xs flex flex-wrap gap-2 items-center">
                      {selectedProduct.seller_name && (
                        <span className="font-medium text-foreground">
                          Shop: <span className="text-primary">{selectedProduct.seller_name}</span>
                        </span>
                      )}
                      {Array.isArray(selectedProduct.categories) && selectedProduct.categories.length > 0 && (
                        <span className="text-muted-foreground">
                          Categories: {selectedProduct.categories.join(", ")}
                        </span>
                      )}
                    </div>
                  )}

                  <div className="text-sm text-muted-foreground space-y-2">
                    <div>
                      <span className="font-medium text-foreground">Name:</span> {selectedProduct.name}
                    </div>
                    <div>
                      <span className="font-medium text-foreground">Price:</span> ₱{selectedProduct.price}
                    </div>
                    <div>
                      <span className="font-medium text-foreground">Quantity:</span> {selectedProduct.quantity}
                    </div>
                    {selectedProduct.brand && (
                      <div>
                        <span className="font-medium text-foreground">Brand:</span> {selectedProduct.brand}
                      </div>
                    )}
                    {selectedProduct.product_condition && (
                      <div>
                        <span className="font-medium text-foreground">Condition:</span> {selectedProduct.product_condition}
                      </div>
                    )}
                    {typeof selectedProduct.weight_kg === "number" && (
                      <div>
                        <span className="font-medium text-foreground">Weight:</span> {selectedProduct.weight_kg} kg
                      </div>
                    )}
                    {selectedProduct.material && (
                      <div>
                        <span className="font-medium text-foreground">Material:</span> {selectedProduct.material}
                      </div>
                    )}
                    {selectedProduct.care_instructions && (
                      <div>
                        <span className="font-medium text-foreground">Care instructions:</span> {selectedProduct.care_instructions}
                      </div>
                    )}
                    {parsedTags && parsedTags.length > 0 && (
                      <div>
                        <span className="font-medium text-foreground">Tags:</span> {parsedTags.join(", ")}
                      </div>
                    )}
                    {parsedMatrixSizeChart && (
                      <div className="space-y-1">
                        <span className="font-medium text-foreground">Size chart:</span>
                        <div className="mt-1 overflow-x-auto rounded-md border bg-muted/30">
                          <table className="min-w-full text-xs">
                            <thead className="bg-muted/60">
                              <tr>
                                {parsedMatrixSizeChart.categoryKey === "shoes" ? (
                                  <>
                                    <th className="px-2 py-1 text-left font-medium">Size</th>
                                    <th className="px-2 py-1 text-left font-medium">Foot length (cm)</th>
                                    <th className="px-2 py-1 text-left font-medium">Foot length (inch)</th>
                                  </>
                                ) : (
                                  <>
                                    <th className="px-2 py-1 text-left font-medium">Size</th>
                                    <th className="px-2 py-1 text-left font-medium">Intl</th>
                                    <th className="px-2 py-1 text-left font-medium">Numeric</th>
                                    {parsedMatrixSizeChart.measurements.map((m) => (
                                      <th key={`${m}-cm`} className="px-2 py-1 text-left font-medium">
                                        {String(m).replace("_", " ")} (cm)
                                      </th>
                                    ))}
                                    {parsedMatrixSizeChart.measurements.map((m) => (
                                      <th key={`${m}-inch`} className="px-2 py-1 text-left font-medium">
                                        {String(m).replace("_", " ")} (inch)
                                      </th>
                                    ))}
                                  </>
                                )}
                              </tr>
                            </thead>
                            <tbody>
                              {parsedMatrixSizeChart.categoryKey === "shoes"
                                ? parsedMatrixSizeChart.sizes.map((row, idx) => {
                                    const parts: string[] = []
                                    if (row.us != null) parts.push(`US ${row.us}`)
                                    if (row.eu != null) parts.push(`EU ${row.eu}`)
                                    const combined = parts.join(" / ") || "-"

                                    return (
                                      <tr key={`${row.us}-${row.eu}-${idx}`} className="border-t">
                                        <td className="px-2 py-1">{combined}</td>
                                        <td className="px-2 py-1">{row.cm.foot_length}</td>
                                        <td className="px-2 py-1">{row.inch.foot_length}</td>
                                      </tr>
                                    )
                                  })
                                : parsedMatrixSizeChart.sizes.map((row, idx) => (
                                    <tr key={`${row.label}-${idx}`} className="border-t">
                                      <td className="px-2 py-1">{row.label}</td>
                                      <td className="px-2 py-1">{row.international}</td>
                                      <td className="px-2 py-1">{row.numeric}</td>
                                      {parsedMatrixSizeChart.measurements.map((m) => (
                                        <td key={`${row.label}-${m}-cm`} className="px-2 py-1">
                                          {row.cm[m]}
                                        </td>
                                      ))}
                                      {parsedMatrixSizeChart.measurements.map((m) => (
                                        <td key={`${row.label}-${m}-inch`} className="px-2 py-1">
                                          {row.inch[m]}
                                        </td>
                                      ))}
                                    </tr>
                                  ))}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    )}
                    {!parsedMatrixSizeChart && parsedLegacySizeChart && (
                      <div className="space-y-1">
                        <span className="font-medium text-foreground">Size chart:</span>
                        <ul className="list-disc list-inside text-xs">
                          {parsedLegacySizeChart.bust && <li>Bust: {parsedLegacySizeChart.bust}</li>}
                          {parsedLegacySizeChart.waist && <li>Waist: {parsedLegacySizeChart.waist}</li>}
                          {parsedLegacySizeChart.hips && <li>Hips: {parsedLegacySizeChart.hips}</li>}
                          {parsedLegacySizeChart.length && <li>Length: {parsedLegacySizeChart.length}</li>}
                          {parsedLegacySizeChart.otherNotes && <li>Other: {parsedLegacySizeChart.otherNotes}</li>}
                        </ul>
                      </div>
                    )}
                    <div className="space-y-1">
                      <span className="font-medium text-foreground">Description:</span>
                      <div
                        className="text-muted-foreground prose prose-sm max-w-none"
                        dangerouslySetInnerHTML={{ __html: selectedProduct.description || "" }}
                      />
                    </div>
                  </div>
                </div>

                {selectedProduct.media && selectedProduct.media.length > 0 && (
                  <div className="space-y-2">
                    <h3 className="text-sm font-medium">Media</h3>
                    <div className="flex flex-wrap gap-3">
                      {selectedProduct.media.map((m: any) => {
                        const url = resolveImageUrl(m.path) ?? ""
                        if (m.media_type === "video") {
                          return (
                            <video
                              key={m.id}
                              src={url}
                              className="w-40 h-40 object-cover rounded-md"
                              controls
                            />
                          )
                        }
                        return (
                          <img
                            key={m.id}
                            src={url}
                            alt={selectedProduct.name}
                            className="w-40 h-40 object-cover rounded-md"
                          />
                        )
                      })}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
