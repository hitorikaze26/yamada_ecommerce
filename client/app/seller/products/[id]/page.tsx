"use client"

import { useEffect, useState } from "react"
import { useRouter, useParams } from "next/navigation"
import { productsApi, sellerApi, type ProductVariation as ApiProductVariation } from "@/lib/api"
import { Icon } from "@/components/ui/icon"
import { ProductVariantBuilder } from "@/components/seller/variant/variant-builder"
import type { VariantEntry } from "@/components/seller/variant/types"

export default function EditProductPage() {
  const router = useRouter()
  const params = useParams<{ id: string }>()
  const productId = params.id

  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  // Basic fields
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [price, setPrice] = useState("")
  const [salePrice, setSalePrice] = useState("")
  const [costPrice, setCostPrice] = useState("")
  const [quantity, setQuantity] = useState("")
  const [brand, setBrand] = useState("")
  const [condition, setCondition] = useState("new")
  const [weightKg, setWeightKg] = useState("")
  const [material, setMaterial] = useState("")
  const [careInstructions, setCareInstructions] = useState("")
  const [lowStockThreshold, setLowStockThreshold] = useState("")
  const [tags, setTags] = useState("")
  const [category, setCategory] = useState("")
  const [subcategory, setSubcategory] = useState("")

  // Variations
  const [variants, setVariants] = useState<VariantEntry[]>([])

  // Load existing product
  useEffect(() => {
    const load = async () => {
      try {
        setIsLoading(true)
        setError(null)
        const res = await productsApi.getById(String(productId))
        const data = (res.data as any)?.product as any
        if (!data) { setError("Product not found"); return }

        setName(data.name || "")
        setDescription(data.description || "")
        setPrice(String(data.price ?? ""))
        setSalePrice(data.sale_price != null ? String(data.sale_price) : "")
        setCostPrice(data.cost_price != null ? String(data.cost_price) : "")
        setQuantity(String(data.quantity ?? ""))
        setBrand(data.brand || "")
        setCondition(data.product_condition || "new")
        setCategory(data.subcategory ? "" : "")
        setSubcategory(data.subcategory || "")
        setWeightKg(data.weight_kg != null ? String(data.weight_kg) : "")
        setMaterial(data.material || "")
        setCareInstructions(data.care_instructions || "")
        setLowStockThreshold(data.low_stock_threshold != null ? String(data.low_stock_threshold) : "")

        // Parse tags from JSON string
        try {
          const parsed = data.tags_json ? JSON.parse(data.tags_json) : []
          setTags(Array.isArray(parsed) ? parsed.join(", ") : "")
        } catch {
          setTags("")
        }

        const apiVariations: ApiProductVariation[] = Array.isArray(data.variations) ? data.variations : []
        const rows: VariantEntry[] = apiVariations.map((v, index) => ({
          id: `var-${index}`,
          color: {
            name: (v.color || "Black") as string,
            hex: (v.colorHex || "#000000") as string,
          },
          size: String(v.size || ""),
          stock: Number(v.inventory || 0),
          sku: String(v.sku || ""),
          price: v.price != null ? Number(v.price) : null,
        }))

        setVariants(rows)
      } catch (e: any) {
        setError(e?.response?.data?.msg || "Failed to load product.")
      } finally {
        setIsLoading(false)
      }
    }

    if (productId) void load()
  }, [productId])

  const handleSave = async () => {
    try {
      setIsSaving(true)
      setError(null)
      setSuccess(null)

      const payload: Record<string, any> = {
        name,
        description,
        price: price !== "" ? Number(price) : undefined,
        quantity: quantity !== "" ? Number(quantity) : undefined,
        variations: variants.map((v) => ({
          size: v.size,
          colors: [v.color.name],
          colorHex: v.color.hex,
          stock: v.stock,
          sku: v.sku.trim() || undefined,
        })),
      }

      if (salePrice !== "") payload.sale_price = Number(salePrice)
      if (costPrice !== "") payload.cost_price = Number(costPrice)
      if (brand !== "") payload.brand = brand
      if (condition !== "") payload.product_condition = condition
      if (weightKg !== "") payload.weight_kg = Number(weightKg)
      if (material !== "") payload.material = material
      if (careInstructions !== "") payload.care_instructions = careInstructions
      if (lowStockThreshold !== "") payload.low_stock_threshold = Number(lowStockThreshold)
      if (subcategory !== "") payload.subcategory = subcategory

      await sellerApi.updateProduct(String(productId), payload as any)
      setSuccess("Product updated successfully.")
      window.scrollTo({ top: 0, behavior: "smooth" })
    } catch (e: any) {
      setError(e?.response?.data?.msg || "Failed to update product.")
    } finally {
      setIsSaving(false)
    }
  }

  const determineSizeOptions = (subcat: string): "clothing" | "shoes" | "accessory" => {
    if (["shoes", "sneakers", "boots", "sandals", "heels"].includes(subcat.toLowerCase())) return "shoes"
    if (["accessories", "bags", "jewelry", "watches", "belts", "hats"].includes(subcat.toLowerCase())) return "accessory"
    return "clothing"
  }

  const inputCls = "w-full px-4 py-2.5 rounded-xl border bg-background text-sm focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
  const labelCls = "block text-sm font-medium mb-1.5"

  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading product...</div>

  return (
    <div className="max-w-4xl mx-auto space-y-6 p-4 pb-12">
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          type="button"
          onClick={() => router.back()}
          className="w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
        >
          <Icon name="arrow-left" />
        </button>
        <div>
          <h1 className="text-2xl font-bold">Edit Product</h1>
          <p className="text-sm text-muted-foreground">Update product details and variants.</p>
        </div>
      </div>

      {success && (
        <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-2xl px-4 py-3 text-sm flex items-center justify-between">
          <span>{success}</span>
          <button type="button" onClick={() => setSuccess(null)} className="text-emerald-700 hover:text-emerald-900">
            <Icon name="times" size="sm" />
          </button>
        </div>
      )}

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 rounded-2xl px-4 py-3 text-sm">{error}</div>
      )}

      {/* Basic Info */}
      <div className="bg-card border rounded-2xl p-6 space-y-4">
        <h2 className="text-base font-semibold">Basic Information</h2>

        <div>
          <label className={labelCls}>Product Name *</label>
          <input type="text" value={name} onChange={(e) => setName(e.target.value)} className={inputCls} />
        </div>

        <div>
          <label className={labelCls}>Description</label>
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4} className={inputCls} />
        </div>

        <div>
          <label className={labelCls}>Brand</label>
          <input type="text" value={brand} onChange={(e) => setBrand(e.target.value)} placeholder="e.g., Nike" className={inputCls} />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>Condition</label>
            <select value={condition} onChange={(e) => setCondition(e.target.value)} className={inputCls}>
              <option value="new">New</option>
              <option value="used">Pre-loved / Used</option>
            </select>
          </div>
          <div>
            <label className={labelCls}>Weight (kg)</label>
            <input type="number" value={weightKg} onChange={(e) => setWeightKg(e.target.value)} placeholder="e.g., 0.5" min="0" step="0.01" className={inputCls} />
          </div>
        </div>

        <div>
          <label className={labelCls}>Material</label>
          <input type="text" value={material} onChange={(e) => setMaterial(e.target.value)} placeholder="e.g., 100% Cotton" className={inputCls} />
        </div>

        <div>
          <label className={labelCls}>Care Instructions</label>
          <textarea value={careInstructions} onChange={(e) => setCareInstructions(e.target.value)} rows={2} placeholder="e.g., Machine wash cold" className={inputCls} />
        </div>

        <div>
          <label className={labelCls}>Tags (comma-separated)</label>
          <input type="text" value={tags} onChange={(e) => setTags(e.target.value)} placeholder="e.g., summer, casual, floral" className={inputCls} />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>Category</label>
            <input type="text" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g., dress-skirts" className={inputCls} />
            <p className="text-xs text-muted-foreground mt-1">Category slug (contact support to change)</p>
          </div>
          <div>
            <label className={labelCls}>Subcategory</label>
            <input type="text" value={subcategory} onChange={(e) => setSubcategory(e.target.value)} placeholder="e.g., Midi Dresses" className={inputCls} />
          </div>
        </div>
      </div>

      {/* Pricing */}
      <div className="bg-card border rounded-2xl p-6 space-y-4">
        <h2 className="text-base font-semibold">Pricing</h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>Regular Price (PHP) *</label>
            <input type="number" value={price} onChange={(e) => setPrice(e.target.value)} min="0" step="0.01" className={inputCls} />
          </div>
          <div>
            <label className={labelCls}>Sale Price (optional)</label>
            <input type="number" value={salePrice} onChange={(e) => setSalePrice(e.target.value)} placeholder="0.00" min="0" step="0.01" className={inputCls} />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelCls}>Cost Price / COGS (optional)</label>
            <input type="number" value={costPrice} onChange={(e) => setCostPrice(e.target.value)} placeholder="Your cost per unit" min="0" step="0.01" className={inputCls} />
            <p className="text-xs text-muted-foreground mt-1">Used for gross profit in sales reports. Not visible to buyers.</p>
          </div>
          <div>
            <label className={labelCls}>Low Stock Threshold</label>
            <input type="number" value={lowStockThreshold} onChange={(e) => setLowStockThreshold(e.target.value)} placeholder="e.g., 5" min="0" className={inputCls} />
            <p className="text-xs text-muted-foreground mt-1">Get notified when stock falls to this level.</p>
          </div>
        </div>

        <div>
          <label className={labelCls}>Total Quantity</label>
          <input type="number" value={quantity} onChange={(e) => setQuantity(e.target.value)} min="0" className={inputCls} />
          <p className="text-xs text-muted-foreground mt-1">Auto-synced from variation stocks when variations are saved.</p>
        </div>
      </div>

      <ProductVariantBuilder
        value={variants}
        onChange={setVariants}
        sizeOptions={determineSizeOptions(subcategory)}
      />

      {/* Actions */}
      <div className="flex gap-4">
        <button
          type="button"
          onClick={() => router.back()}
          className="flex-1 py-3 px-4 border rounded-xl text-sm font-medium hover:bg-muted"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={isSaving}
          className="flex-1 py-3 px-4 bg-primary text-primary-foreground rounded-xl text-sm font-medium hover:bg-primary/90 disabled:opacity-60 flex items-center justify-center gap-2"
        >
          {isSaving && <Icon name="arrow-path" className="animate-spin" size="sm" />}
          {isSaving ? "Saving..." : "Save Changes"}
        </button>
      </div>
    </div>
  )
}
