"use client"
import { useState, useEffect } from "react"
import type React from "react"

import { useRouter } from "next/navigation"
import Image from "next/image"
import { Icon } from "@/components/ui/icon"
import { sellerApi } from "@/lib/api"
import { toast } from "@/hooks/use-toast"
import { ProductVariantBuilder } from "@/components/seller/variant/variant-builder"
import type { VariantEntry } from "@/components/seller/variant/types"
import {
  CATEGORIES,
  CATEGORY_NAME_TO_ID,
  SUBCATEGORIES,
  SHOES_SUBCATEGORIES,
  ACCESSORY_SUBCATEGORIES,
  type SizeChartCategoryKey,
  type SizeChartMeasurementId,
} from "@/lib/types"
import { useEditor, EditorContent } from "@tiptap/react"
import StarterKit from "@tiptap/starter-kit"
import { PendingStoreGate } from "@/components/seller/pending-store-gate"

interface ClothingSizeRow {
  label: string
  international: string
  numeric: string
  cm: Record<SizeChartMeasurementId, string | "" | null>
  inch: Record<SizeChartMeasurementId, string | "" | null>
}

interface ClothingSizeChartMatrix {
  categoryKey: Exclude<SizeChartCategoryKey, "shoes">
  measurements: SizeChartMeasurementId[]
  sizes: ClothingSizeRow[]
}

interface ShoeSizeRow {
  us: number
  eu: number
  cm: { foot_length: string | "" | null }
  inch: { foot_length: string | "" | null }
}

interface ShoeSizeChartMatrix {
  categoryKey: "shoes"
  measurements: ["foot_length"]
  sizes: ShoeSizeRow[]
}

type SizeChartMatrix = ClothingSizeChartMatrix | ShoeSizeChartMatrix

const SIZE_CATEGORY_FROM_PRODUCT_CATEGORY: Record<string, SizeChartCategoryKey | null> = {
  "tops-blouses": "tops",
  "dress-skirts": "dresses_and_skirts",
  "activewear": "activewear_and_yoga_pants",
  "lingerie-sleepwear": "lingerie_and_sleepwear",
  "jackets-coats": "jackets",
  "accessories-shoes": null,
}

const CATEGORY_ALIAS_TO_ID: Record<string, string> = {
  ...CATEGORY_NAME_TO_ID,
  "dresses and skirts": "dress-skirts",
  "dressess and skirts": "dress-skirts",
  "dress & skirts": "dress-skirts",
  "tops & blouses": "tops-blouses",
  "activewear & yoga pants": "activewear",
  "lingerie & sleepwear": "lingerie-sleepwear",
  "jackets & coats": "jackets-coats",
  "accessories & shoes": "accessories-shoes",
  "accessories and shoes": "accessories-shoes",
}

for (const category of CATEGORIES) {
  CATEGORY_ALIAS_TO_ID[category.id.toLowerCase()] = category.id
  CATEGORY_ALIAS_TO_ID[category.name.toLowerCase()] = category.id
}

function normalizeCategoryId(value: unknown): string | null {
  if (typeof value !== "string") return null
  const token = value.trim().toLowerCase()
  if (!token) return null
  return CATEGORY_ALIAS_TO_ID[token] || null
}

function createEmptyMeasurementMap(measurements: SizeChartMeasurementId[]): Record<SizeChartMeasurementId, string | "" | null> {
  const base: Partial<Record<SizeChartMeasurementId, string | "" | null>> = {}
  measurements.forEach((m) => {
    base[m] = ""
  })
  return base as Record<SizeChartMeasurementId, string | "" | null>
}

function createInitialClothingMatrix(
  categoryKey: Exclude<SizeChartCategoryKey, "shoes">,
  measurements: SizeChartMeasurementId[],
): ClothingSizeChartMatrix {
  const baseSizes = ["XS", "S", "M", "L", "XL"]

  return {
    categoryKey,
    measurements,
    sizes: baseSizes.map((label) => ({
      label,
      international: label,
      numeric: "",
      cm: createEmptyMeasurementMap(measurements),
      inch: createEmptyMeasurementMap(measurements),
    })),
  }
}

function createInitialShoeMatrix(): ShoeSizeChartMatrix {
  const sizes: ShoeSizeRow[] = [
    { us: 5, eu: 35, cm: { foot_length: "" }, inch: { foot_length: "" } },
    { us: 6, eu: 36, cm: { foot_length: "" }, inch: { foot_length: "" } },
    { us: 7, eu: 37, cm: { foot_length: "" }, inch: { foot_length: "" } },
    { us: 8, eu: 38, cm: { foot_length: "" }, inch: { foot_length: "" } },
    { us: 9, eu: 39, cm: { foot_length: "" }, inch: { foot_length: "" } },
  ]

  return {
    categoryKey: "shoes",
    measurements: ["foot_length"],
    sizes,
  }
}

function getSizeChartCategoryKey(categoryId: string, subcategory: string): SizeChartCategoryKey | null {
  if (!categoryId) return null
  if (categoryId === "accessories-shoes") {
    if (SHOES_SUBCATEGORIES.includes(subcategory)) return "shoes"
    return null
  }
  return SIZE_CATEGORY_FROM_PRODUCT_CATEGORY[categoryId] ?? null
}

function createInitialSizeChartMatrix(categoryId: string, subcategory: string): SizeChartMatrix | null {
  const key = getSizeChartCategoryKey(categoryId, subcategory)
  if (!key) return null

  switch (key) {
    case "tops":
      return createInitialClothingMatrix("tops", ["bust", "waist", "length", "shoulder", "sleeve_length"])
    case "dresses_and_skirts":
      return createInitialClothingMatrix("dresses_and_skirts", ["bust", "waist", "hips", "length"])
    case "bottoms":
      return createInitialClothingMatrix("bottoms", ["waist", "hips", "inseam", "length", "thigh"])
    case "activewear_and_yoga_pants":
      {
        const subLower = (subcategory || "").toLowerCase()
        // Sports bras / bra tops within activewear: treat like bra sizing
        if (subLower.includes("bra")) {
          return createInitialClothingMatrix("activewear_and_yoga_pants", ["bust", "underbust", "waist", "hips"])
        }
        // Leggings, yoga pants, shorts, etc.
        return createInitialClothingMatrix("activewear_and_yoga_pants", ["waist", "hips", "inseam", "length", "stretch_fit_range"])
      }
    case "lingerie_and_sleepwear":
      {
        const subLower = (subcategory || "").toLowerCase()
        // If this is a bra-focused subcategory, emphasize bust/underbust measurements.
        if (subLower.includes("bra")) {
          return createInitialClothingMatrix("lingerie_and_sleepwear", ["bust", "underbust", "waist", "hips"])
        }
        // For panties/sleepwear/robes etc. use more general body measurements.
        return createInitialClothingMatrix("lingerie_and_sleepwear", ["bust", "waist", "hips", "length"])
      }
    case "jackets":
      return createInitialClothingMatrix("jackets", ["bust", "shoulder", "sleeve_length", "waist", "length"])
    case "shoes":
      return createInitialShoeMatrix()
    default:
      return null
  }
}



function NewProductPageContent() {
  const router = useRouter()
  const [images, setImages] = useState<string[]>([])
  const [imageFiles, setImageFiles] = useState<File[]>([])
  const [videos, setVideos] = useState<string[]>([])
  const [videoFiles, setVideoFiles] = useState<File[]>([])
  const [variants, setVariants] = useState<VariantEntry[]>([])
  const [step, setStep] = useState<1 | 2 | 3>(1)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [formData, setFormData] = useState({
    name: "",
    brand: "",
    description: "",
    category: "",
    subcategory: "",
    price: "",
    salePrice: "",
    costPrice: "",
    tags: "",
    condition: "new",
    weightKg: "",
    lowStockThreshold: "",
    material: "",
    careInstructions: "",
    sizeChartBust: "",
    sizeChartWaist: "",
    sizeChartHips: "",
    sizeChartLength: "",
    sizeChartOther: "",
    termsAgreed: false as boolean,
  })

  const [sizeChartMatrix, setSizeChartMatrix] = useState<SizeChartMatrix | null>(null)

  const isAccessoriesShoes = formData.category === "accessories-shoes"
  const isShoeSubcategory = isAccessoriesShoes && SHOES_SUBCATEGORIES.includes(formData.subcategory)
  const isAccessorySubcategory = isAccessoriesShoes && ACCESSORY_SUBCATEGORIES.includes(formData.subcategory)

  const editor = useEditor({
    extensions: [StarterKit],
    content: formData.description,
    onUpdate: ({ editor }) => {
      setFormData((prev) => ({
        ...prev,
        description: editor.getHTML(),
      }))
    },
    immediatelyRender: false,
  })

  useEffect(() => {
    const next = createInitialSizeChartMatrix(formData.category, formData.subcategory)
    setSizeChartMatrix(next)
  }, [formData.category, formData.subcategory])

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (files) {
      const fileArray = Array.from(files)
      const newImages = fileArray.map((file) => URL.createObjectURL(file))
      const nextImages = [...images, ...newImages].slice(0, 6)
      const nextFiles = [...imageFiles, ...fileArray].slice(0, 6)
      setImages(nextImages)
      setImageFiles(nextFiles)
    }
  }

  const handleVideoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (files) {
      const fileArray = Array.from(files)
      const newVideos = fileArray.map((file) => URL.createObjectURL(file))
      setVideos((prev) => [...prev, ...newVideos])
      setVideoFiles((prev) => [...prev, ...fileArray])
    }
  }

  const removeVideo = (index: number) => {
    setVideos((prev) => prev.filter((_, i) => i !== index))
    setVideoFiles((prev) => prev.filter((_, i) => i !== index))
  }

  const removeImage = (index: number) => {
    setImages(images.filter((_, i) => i !== index))
    setImageFiles(imageFiles.filter((_, i) => i !== index))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (isSubmitting) return
    setIsSubmitting(true)

    if (!formData.termsAgreed) {
      setIsSubmitting(false)
      return
    }

    const form = new FormData()

    form.append("name", formData.name)
    if (formData.brand) {
      form.append("brand", formData.brand)
    }
    form.append("price", formData.price)
    if (formData.salePrice) {
      form.append("sale_price", formData.salePrice)
    }
    if (formData.costPrice) {
      form.append("cost_price", formData.costPrice)
    }

    const totalStock = variants.reduce((sum, v) => sum + (v.stock || 0), 0)
    form.append("quantity", String(totalStock))
    form.append("description", formData.description)
    if (formData.category) {
      form.append("category", formData.category)
    }
    if (formData.subcategory) {
      form.append("subcategory", formData.subcategory)
    }

    if (formData.tags) {
      form.append("tags", formData.tags)
    }

    if (formData.condition) {
      form.append("product_condition", formData.condition)
    }

    if (formData.weightKg) {
      form.append("weight_kg", formData.weightKg)
    }

    if (formData.lowStockThreshold) {
      form.append("low_stock_threshold", formData.lowStockThreshold)
    }

    if (formData.material) {
      form.append("material", formData.material)
    }

    if (formData.careInstructions) {
      form.append("care_instructions", formData.careInstructions)
    }

    if (sizeChartMatrix) {
      let hasValue = false

      if (sizeChartMatrix.categoryKey === "shoes") {
        hasValue = sizeChartMatrix.sizes.some((row) => {
          return Boolean(
            (row.cm.foot_length && String(row.cm.foot_length).trim()) ||
              (row.inch.foot_length && String(row.inch.foot_length).trim()),
          )
        })
      } else {
        hasValue = sizeChartMatrix.sizes.some((row) => {
          return (
            row.numeric.trim() !== "" ||
            sizeChartMatrix.measurements.some((m) => {
              const cmVal = row.cm[m]
              const inchVal = row.inch[m]
              return Boolean((cmVal && String(cmVal).trim()) || (inchVal && String(inchVal).trim()))
            })
          )
        })
      }

      if (hasValue) {
        form.append("size_chart", JSON.stringify(sizeChartMatrix))
      }
    }

    const colorSet = Array.from(new Set(variants.map((v) => v.color.name)))
    if (colorSet.length > 0) {
      form.append("colors", colorSet.join(", "))
    }

    if (variants.length > 0) {
      const variationPayload = variants.map((v) => ({
        // Never send UI placeholders/non-numeric strings to the API.
        // Empty per-variant price means "use base product price" on display.
        price:
          typeof v.price === "number" && Number.isFinite(v.price) && v.price >= 0
            ? v.price
            : undefined,
        size: v.size,
        colors: [v.color.name],
        colorHex: v.color.hex,
        stock: v.stock,
        sku: v.sku.trim() || undefined,
      }))
      form.append("variations", JSON.stringify(variationPayload))
    }

    imageFiles.forEach((file, index) => {
      if (index === 0) {
        form.append("main_image", file)
      } else {
        form.append("additional_images", file)
      }
    })

    videoFiles.forEach((file) => {
      form.append("videos", file)
    })

    try {
      await sellerApi.addProduct(form)
      toast({
        title: "Success",
        description: "Product created successfully!",
        variant: "success",
      })
      router.push("/seller/products?created=1")
    } catch (error) {
      console.error("Failed to create product", error)
      const msg =
        (error as any)?.response?.data?.msg ||
        "Failed to create product. Please try again."
      toast({
        title: "Error",
        description: msg,
        variant: "destructive",
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center gap-4 mb-6">
        <button
          onClick={() => router.back()}
          className="w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
        >
          <Icon name="arrow-left" />
        </button>
        <div>
          <h1 className="text-3xl font-bold">Add New Product</h1>
          <p className="text-muted-foreground">Fill in the details to create a new product listing.</p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Step indicator */}
        <div className="flex items-center justify-between gap-4 mb-2">
          <div className="flex items-center gap-2 text-sm">
            <button
              type="button"
              onClick={() => setStep(1)}
              className={`px-3 py-1 rounded-full border text-xs font-medium ${
                step === 1
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-muted text-muted-foreground border-border"
              }`}
            >
              1. Basic Product Information
            </button>
            <button
              type="button"
              onClick={() => setStep(2)}
              className={`px-3 py-1 rounded-full border text-xs font-medium ${
                step === 2
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-muted text-muted-foreground border-border"
              }`}
            >
              2. Images & Product Details
            </button>
            <button
              type="button"
              onClick={() => setStep(3)}
              className={`px-3 py-1 rounded-full border text-xs font-medium ${
                step === 3
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-muted text-muted-foreground border-border"
              }`}
            >
              3. Inventory, Pricing & Logistics
            </button>
          </div>
        </div>

        {/* Step 1: Basic Product Information */}
        {step === 1 && (
          <div className="space-y-6">
            {/* Basic Info */}
            <div className="bg-card border rounded-2xl p-6">
              <h2 className="text-lg font-semibold mb-4">Basic Information</h2>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Product Name *</label>
                  <textarea
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="e.g., Floral Maxi Dress"
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none resize-y"
                    rows={2}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2">Brand *</label>
                  <textarea
                    value={formData.brand}
                    onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
                    placeholder="e.g., Yamada Studio"
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none resize-y"
                    rows={2}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2">Description *</label>
                  <div
                    className="w-full rounded-xl border bg-background cursor-text focus-within:ring-0 focus-within:border-border"
                    onClick={() => {
                      if (!editor) return
                      editor.chain().focus().run()
                    }}
                  >
                    <div className="flex items-center gap-1 border-b px-2 py-1 text-xs text-muted-foreground flex-wrap">
                      <button
                        type="button"
                        className="px-2 py-1 rounded-md hover:bg-muted font-semibold"
                        aria-label="Bold"
                        onClick={() => {
                          if (!editor) return
                          editor.chain().focus().toggleBold().run()
                        }}
                      >
                        B
                      </button>
                      <button
                        type="button"
                        className="px-2 py-1 rounded-md hover:bg-muted italic"
                        aria-label="Italic"
                        onClick={() => {
                          if (!editor) return
                          editor.chain().focus().toggleItalic().run()
                        }}
                      >
                        I
                      </button>
                    </div>
                    <div className="px-4 py-3">
                      <EditorContent
                        editor={editor}
                        className="min-h-[200px] text-sm focus:outline-none focus:ring-0 focus:border-transparent [&_.ProseMirror]:w-full [&_.ProseMirror]:max-w-none [&_.ProseMirror]:px-0 [&_.ProseMirror]:mx-0 [&_.ProseMirror]:focus:outline-none [&_.ProseMirror]:focus:ring-0 [&_.ProseMirror]:focus:border-transparent"
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2">Category *</label>
                  <select
                    value={formData.category}
                    onChange={(e) =>
                      setFormData({ ...formData, category: e.target.value, subcategory: "" })
                    }
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                    required
                  >
                    <option value="">Select a category</option>
                    {CATEGORIES.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name}
                      </option>
                    ))}
                  </select>
                </div>

                {formData.category && (
                  <div>
                    <label className="block text-sm font-medium mb-2">Subcategory</label>
                    <div className="flex flex-wrap gap-2">
                      {(SUBCATEGORIES[formData.category as keyof typeof SUBCATEGORIES] || []).map(
                        (sub) => {
                          const isSelected = formData.subcategory === sub
                          return (
                            <button
                              key={sub}
                              type="button"
                              onClick={() =>
                                setFormData((prev) => ({
                                  ...prev,
                                  subcategory: prev.subcategory === sub ? "" : sub,
                                }))
                              }
                              className={`px-3 py-1 rounded-full text-xs font-medium border transition-colors ${
                                isSelected
                                  ? "bg-primary text-primary-foreground border-primary"
                                  : "bg-muted text-muted-foreground border-border hover:bg-muted/80"
                              }`}
                            >
                              {sub}
                            </button>
                          )
                        },
                      )}
                    </div>
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium mb-2">Tags (comma separated)</label>
                  <textarea
                    value={formData.tags}
                    onChange={(e) => setFormData({ ...formData, tags: e.target.value })}
                    placeholder="e.g., summer, casual, floral"
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none resize-y"
                    rows={2}
                  />
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Step 2: Images and Product Details */}
        {step === 2 && (
          <div className="space-y-6">
            {/* Images */}
            <div className="bg-card border rounded-2xl p-6">
              <h2 className="text-lg font-semibold mb-4">Product Images</h2>
              <p className="text-sm text-muted-foreground mb-4">Upload up to 6 images. First image will be the cover.</p>

              <div className="grid grid-cols-3 sm:grid-cols-6 gap-4">
                {images.map((image, index) => (
                  <div key={index} className="relative aspect-square rounded-xl overflow-hidden bg-muted">
                    <Image src={image || "/placeholder.svg"} alt={`Product ${index + 1}`} fill className="object-cover" />
                    <button
                      type="button"
                      onClick={() => removeImage(index)}
                      className="absolute top-2 right-2 w-6 h-6 rounded-full bg-red-500 text-white flex items-center justify-center"
                    >
                      <Icon name="times" size="sm" />
                    </button>
                    {index === 0 && (
                      <span className="absolute bottom-2 left-2 px-2 py-0.5 bg-primary text-primary-foreground text-xs rounded-md">
                        Cover
                      </span>
                    )}
                  </div>
                ))}
                {images.length < 6 && (
                  <label className="aspect-square rounded-xl border-2 border-dashed border-muted-foreground/30 flex flex-col items-center justify-center cursor-pointer hover:border-primary transition-colors">
                    <Icon name="plus" className="text-muted-foreground mb-1" />
                    <span className="text-xs text-muted-foreground">Add Image</span>
                    <input type="file" accept="image/*" onChange={handleImageUpload} className="hidden" multiple />
                  </label>
                )}
              </div>
            </div>

            {/* Optional Video */}
            <div className="bg-card border rounded-2xl p-6">
              <h2 className="text-lg font-semibold mb-4">Product Video (Optional)</h2>
              <p className="text-sm text-muted-foreground mb-4">Add an optional short video to better showcase your product.</p>

              <div className="space-y-4">
                <label className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-muted-foreground/30 rounded-xl cursor-pointer hover:border-primary transition-colors w-full sm:w-auto justify-center">
                  <Icon name="video" className="text-muted-foreground" />
                  <span className="text-sm text-muted-foreground">Upload Videos</span>
                  <input
                    type="file"
                    accept="video/*"
                    multiple
                    onChange={handleVideoUpload}
                    className="hidden"
                  />
                </label>

                {videos.length > 0 && (
                  <div className="mt-2 space-y-2">
                    <p className="text-xs text-muted-foreground">Video previews</p>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      {videos.map((videoUrl, index) => (
                        <div key={index} className="relative">
                          <video
                            src={videoUrl}
                            controls
                            className="w-full max-h-64 rounded-xl border bg-black object-contain"
                          />
                          <button
                            type="button"
                            onClick={() => removeVideo(index)}
                            className="absolute top-2 right-2 w-8 h-8 rounded-full bg-red-500 text-white flex items-center justify-center text-xs"
                          >
                            <Icon name="times" size="sm" />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Product Details */}
            <div className="bg-card border rounded-2xl p-6">
              <h2 className="text-lg font-semibold mb-4">Product Details</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Material *</label>
                  <textarea
                    value={formData.material}
                    onChange={(e) => setFormData({ ...formData, material: e.target.value })}
                    placeholder="e.g., Cotton, Linen"
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none resize-y"
                    rows={2}
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium mb-2">Care Instructions</label>
                  <textarea
                    value={formData.careInstructions}
                    onChange={(e) => setFormData({ ...formData, careInstructions: e.target.value })}
                    placeholder="e.g., Machine wash cold, do not bleach"
                    rows={3}
                    className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none resize-none"
                  />
                </div>

                {!isAccessoriesShoes && (
                  <div>
                    <label className="block text-sm font-medium mb-2">Size Chart (optional)</label>
                    {!sizeChartMatrix && (
                      <p className="text-xs text-muted-foreground">
                        Select a category and subcategory to configure a detailed size chart.
                      </p>
                    )}
                    {sizeChartMatrix && sizeChartMatrix.categoryKey !== "shoes" && (
                      <div className="mt-2 space-y-2">
                        <div className="overflow-x-auto rounded-xl border bg-muted/30">
                          <table className="min-w-full text-xs">
                            <thead className="bg-muted/60">
                              <tr>
                                <th className="px-3 py-2 text-left font-medium">Size</th>
                                <th className="px-3 py-2 text-left font-medium">International</th>
                                <th className="px-3 py-2 text-left font-medium">Numeric</th>
                                {sizeChartMatrix.measurements.map((m) => (
                                  <th key={`${m}-cm`} className="px-3 py-2 text-left font-medium">
                                    {m.replace("_", " ")} (cm)
                                  </th>
                                ))}
                                {sizeChartMatrix.measurements.map((m) => (
                                  <th key={`${m}-inch`} className="px-3 py-2 text-left font-medium">
                                    {m.replace("_", " ")} (inch)
                                  </th>
                                ))}
                              </tr>
                            </thead>
                            <tbody>
                              {sizeChartMatrix.sizes.map((row, rowIndex) => (
                                <tr key={row.label} className="border-t">
                                  <td className="px-3 py-2">
                                    <input
                                      value={row.label}
                                      onChange={(e) => {
                                        const value = e.target.value
                                        setSizeChartMatrix((prev) => {
                                          if (!prev || prev.categoryKey === "shoes") return prev
                                          const nextSizes = [...prev.sizes]
                                          nextSizes[rowIndex] = { ...nextSizes[rowIndex], label: value }
                                          return { ...prev, sizes: nextSizes }
                                        })
                                      }}
                                      className="w-20 px-2 py-1 rounded border bg-background"
                                    />
                                  </td>
                                  <td className="px-3 py-2">
                                    <input
                                      value={row.international}
                                      onChange={(e) => {
                                        const value = e.target.value
                                        setSizeChartMatrix((prev) => {
                                          if (!prev || prev.categoryKey === "shoes") return prev
                                          const nextSizes = [...prev.sizes]
                                          nextSizes[rowIndex] = { ...nextSizes[rowIndex], international: value }
                                          return { ...prev, sizes: nextSizes }
                                        })
                                      }}
                                      className="w-24 px-2 py-1 rounded border bg-background"
                                    />
                                  </td>
                                  <td className="px-3 py-2">
                                    <input
                                      value={row.numeric}
                                      onChange={(e) => {
                                        const value = e.target.value
                                        setSizeChartMatrix((prev) => {
                                          if (!prev || prev.categoryKey === "shoes") return prev
                                          const nextSizes = [...prev.sizes]
                                          nextSizes[rowIndex] = { ...nextSizes[rowIndex], numeric: value }
                                          return { ...prev, sizes: nextSizes }
                                        })
                                      }}
                                      className="w-24 px-2 py-1 rounded border bg-background"
                                    />
                                  </td>
                                  {sizeChartMatrix.measurements.map((m) => (
                                    <td key={`${row.label}-${m}-cm`} className="px-3 py-2">
                                      <input
                                        value={row.cm[m] ?? ""}
                                        onChange={(e) => {
                                          const value = e.target.value
                                          setSizeChartMatrix((prev) => {
                                            if (!prev || prev.categoryKey === "shoes") return prev
                                            const nextSizes = [...prev.sizes]
                                            const nextRow = { ...nextSizes[rowIndex], cm: { ...nextSizes[rowIndex].cm, [m]: value } }
                                            nextSizes[rowIndex] = nextRow
                                            return { ...prev, sizes: nextSizes }
                                          })
                                        }}
                                        className="w-24 px-2 py-1 rounded border bg-background"
                                      />
                                    </td>
                                  ))}
                                  {sizeChartMatrix.measurements.map((m) => (
                                    <td key={`${row.label}-${m}-inch`} className="px-3 py-2">
                                      <input
                                        value={row.inch[m] ?? ""}
                                        onChange={(e) => {
                                          const value = e.target.value
                                          setSizeChartMatrix((prev) => {
                                            if (!prev || prev.categoryKey === "shoes") return prev
                                            const nextSizes = [...prev.sizes]
                                            const nextRow = { ...nextSizes[rowIndex], inch: { ...nextSizes[rowIndex].inch, [m]: value } }
                                            nextSizes[rowIndex] = nextRow
                                            return { ...prev, sizes: nextSizes }
                                          })
                                        }}
                                        className="w-24 px-2 py-1 rounded border bg-background"
                                      />
                                    </td>
                                  ))}
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>

                        <p className="text-xs text-muted-foreground">
                          {sizeChartMatrix.categoryKey === "tops" &&
                            "For tops, measure around the fullest part of the bust and the narrowest part of the waist. Length is measured from the highest shoulder point down."}
                          {sizeChartMatrix.categoryKey === "dresses_and_skirts" &&
                            "For dresses and skirts, measure bust, waist and hips around the fullest parts, and length from shoulder or waist down to the hem."}
                          {sizeChartMatrix.categoryKey === "bottoms" &&
                            "For bottoms, measure waist at the narrowest point, hips at the fullest point, inseam from crotch to ankle, and length from waist to hem."}
                          {sizeChartMatrix.categoryKey === "jackets" &&
                            "For jackets, measure bust around the fullest part of the chest, shoulder from edge to edge, sleeve from shoulder seam to wrist, and length from shoulder down."}
                          {sizeChartMatrix.categoryKey === "lingerie_and_sleepwear" &&
                            (sizeChartMatrix.measurements.includes("underbust" as any)
                              ? "For bras, measure bust around the fullest part of the chest and underbust directly under the bust. Use waist and hips for matching bottoms."
                              : "For lingerie and sleepwear, use bust, waist and hips around the fullest parts, and length from shoulder down if applicable.")}
                          {sizeChartMatrix.categoryKey === "activewear_and_yoga_pants" &&
                            (sizeChartMatrix.measurements.includes("underbust" as any)
                              ? "For sports bras, measure bust around the fullest part of the chest and underbust directly under the bust."
                              : "For leggings and yoga pants, measure waist, hips and inseam. Stretch fit range indicates how much the fabric comfortably stretches.")}
                        </p>
                      </div>
                    )}

                    {sizeChartMatrix && sizeChartMatrix.categoryKey === "shoes" && (
                      <div className="mt-2 space-y-2">
                        <div className="overflow-x-auto rounded-xl border bg-muted/30">
                          <table className="min-w-full text-xs">
                            <thead className="bg-muted/60">
                              <tr>
                                <th className="px-3 py-2 text-left font-medium">US</th>
                                <th className="px-3 py-2 text-left font-medium">EU</th>
                                <th className="px-3 py-2 text-left font-medium">Foot length (cm)</th>
                                <th className="px-3 py-2 text-left font-medium">Foot length (inch)</th>
                              </tr>
                            </thead>
                            <tbody>
                              {sizeChartMatrix.sizes.map((row, rowIndex) => (
                                <tr key={`${row.us}-${row.eu}`} className="border-t">
                                  <td className="px-3 py-2">{row.us}</td>
                                  <td className="px-3 py-2">{row.eu}</td>
                                  <td className="px-3 py-2">
                                    <input
                                      value={row.cm.foot_length ?? ""}
                                      onChange={(e) => {
                                        const value = e.target.value
                                        setSizeChartMatrix((prev) => {
                                          if (!prev || prev.categoryKey !== "shoes") return prev
                                          const nextSizes = [...prev.sizes]
                                          const nextRow = {
                                            ...nextSizes[rowIndex],
                                            cm: { ...nextSizes[rowIndex].cm, foot_length: value },
                                          }
                                          nextSizes[rowIndex] = nextRow
                                          return { ...prev, sizes: nextSizes }
                                        })
                                      }}
                                      className="w-28 px-2 py-1 rounded border bg-background"
                                    />
                                  </td>
                                  <td className="px-3 py-2">
                                    <input
                                      value={row.inch.foot_length ?? ""}
                                      onChange={(e) => {
                                        const value = e.target.value
                                        setSizeChartMatrix((prev) => {
                                          if (!prev || prev.categoryKey !== "shoes") return prev
                                          const nextSizes = [...prev.sizes]
                                          const nextRow = {
                                            ...nextSizes[rowIndex],
                                            inch: { ...nextSizes[rowIndex].inch, foot_length: value },
                                          }
                                          nextSizes[rowIndex] = nextRow
                                          return { ...prev, sizes: nextSizes }
                                        })
                                      }}
                                      className="w-28 px-2 py-1 rounded border bg-background"
                                    />
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>

                        <p className="text-xs text-muted-foreground">
                          Measure your foot from heel to longest toe while standing. Match the foot length to the US/EU size that best fits your brand's sizing.
                        </p>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Step 3: Inventory, Pricing and Logistics */}
        {step === 3 && (
          <div className="space-y-6">
            {/* Pricing & Logistics */}
            <div className="bg-card border rounded-2xl p-6">
              <h2 className="text-lg font-semibold mb-4">Pricing & Logistics</h2>
              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Price (PHP) *</label>
                    <input
                      type="number"
                      value={formData.price}
                      onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                      placeholder="0.00"
                      min="0"
                      step="0.01"
                      className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-2">Sale Price (optional)</label>
                    <input
                      type="number"
                      value={formData.salePrice}
                      onChange={(e) => setFormData({ ...formData, salePrice: e.target.value })}
                      placeholder="0.00"
                      min="0"
                      step="0.01"
                      className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Cost Price / COGS (optional)</label>
                    <input
                      type="number"
                      value={formData.costPrice}
                      onChange={(e) => setFormData({ ...formData, costPrice: e.target.value })}
                      placeholder="Your cost per unit"
                      min="0"
                      step="0.01"
                      className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                    />
                    <p className="text-xs text-muted-foreground mt-1">Used to calculate gross profit in your sales report. Not visible to buyers.</p>
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-2">Weight (kg) *</label>
                    <input
                      type="number"
                      value={formData.weightKg}
                      onChange={(e) => setFormData({ ...formData, weightKg: e.target.value })}
                      placeholder="e.g., 0.5"
                      min="0"
                      step="0.01"
                      className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-2">Condition *</label>
                    <select
                      value={formData.condition}
                      onChange={(e) => setFormData({ ...formData, condition: e.target.value })}
                      className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
                      required
                    >
                      <option value="new">New</option>
                      <option value="used">Pre-loved / Used</option>
                    </select>
                  </div>
                </div>

                <div className="flex items-start gap-2 rounded-xl bg-muted/40 p-3 border border-dashed border-muted-foreground/30">
                  <input
                    id="terms-agreed"
                    type="checkbox"
                    checked={formData.termsAgreed}
                    onChange={(e) => setFormData({ ...formData, termsAgreed: e.target.checked })}
                    className="mt-1 h-4 w-4 rounded border border-border accent-primary"
                  />
                  <label htmlFor="terms-agreed" className="text-xs text-muted-foreground">
                    I confirm that this product complies with marketplace policies and that all information provided is
                    accurate.
                  </label>
                </div>
              </div>
            </div>

            <ProductVariantBuilder
              value={variants}
              onChange={setVariants}
              sizeOptions={isAccessorySubcategory ? "accessory" : isShoeSubcategory ? "shoes" : "clothing"}
            />
        </div>
        )}

        {/* Actions */}
        <div className="flex gap-4">
          <button
            type="button"
            onClick={() => (step > 1 ? setStep((s) => (s - 1) as 1 | 2 | 3) : router.back())}
            className="flex-1 py-3 px-4 border rounded-xl font-medium hover:bg-muted transition-colors"
          >
            {step > 1 ? "Previous" : "Cancel"}
          </button>
          {step < 3 ? (
            <button
              type="button"
              onClick={() => setStep((s) => (s + 1) as 1 | 2 | 3)}
              className="flex-1 py-3 px-4 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
            >
              Next
            </button>
          ) : (
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 py-3 px-4 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isSubmitting && <Icon name="arrow-path" className="animate-spin" size="sm" />}
              {isSubmitting ? "Creating..." : "Create Product"}
            </button>
          )}
        </div>
      </form>
    </div>
  )
}

export default function NewProductPage() {
  return (
    <PendingStoreGate>
      <NewProductPageContent />
    </PendingStoreGate>
  )
}
