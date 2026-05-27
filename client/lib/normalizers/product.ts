import { resolveImageUrl } from "@/lib/api"
import type { Product, ProductVariation } from "@/lib/types"

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")

function readKey(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

function str(raw: Record<string, unknown>, ...keys: string[]): string {
  return String(readKey(raw, keys) ?? "")
}

function num(raw: Record<string, unknown>, ...keys: string[]): number {
  const v = readKey(raw, keys)
  return typeof v === "number" ? v : Number(v ?? 0)
}

function bool(raw: Record<string, unknown>, ...keys: string[]): boolean {
  return Boolean(readKey(raw, keys) ?? false)
}

function normalizeImagePath(raw: string | null | undefined): string | null {
  if (!raw) return null
  return resolveImageUrl(raw) ?? raw
}

export function normalizeProduct(raw: Record<string, unknown>, storeName?: string): Product {
  const numericId = str(raw, "id")
  const name = str(raw, "name")
  const slugRaw = str(raw, "slug", numericId)
  const slug =
    slugRaw.includes("-") && slugRaw !== numericId
      ? slugRaw
      : `${numericId}-${slugify(name || numericId)}`

  const apiCategories: string[] = Array.isArray(raw.categories)
    ? (raw.categories as string[])
    : []

  const imageUrl = normalizeImagePath(str(raw, "image_url", "imageUrl", "image") || null)
  const imagesRaw: string[] = Array.isArray(raw.images) ? (raw.images as string[]) : []
  const allImagePaths = [
    ...(imageUrl ? [imageUrl] : []),
    ...imagesRaw.map(u => normalizeImagePath(u)).filter((x): x is string => x != null),
  ]
  const images = Array.from(new Set(allImagePaths))

  const variations: ProductVariation[] = Array.isArray(raw.variations)
    ? (raw.variations as Record<string, unknown>[]).map(v => ({
        id: str(v, "id"),
        size: str(v, "size"),
        color: str(v, "color"),
        colorHex: str(v, "colorHex", "color_hex") || undefined,
        sku: str(v, "sku"),
        inventory: num(v, "inventory"),
        price: typeof v.price === "number" ? v.price : undefined,
      }))
    : []

  const price = num(raw, "price")
  const salePriceRaw = readKey(raw, ["sale_price", "salePrice"])
  const salePrice = typeof salePriceRaw === "number" ? salePriceRaw : undefined

  return {
    id: numericId,
    slug,
    name,
    category: apiCategories[0] ?? str(raw, "category"),
    subcategory: str(raw, "subcategory") || undefined,
    categories: apiCategories,
    description: str(raw, "description"),
    images,
    image_url: imageUrl ?? undefined,
    imageUrl: imageUrl ?? undefined,
    variations,
    price,
    salePrice,
    brand: str(raw, "brand") || undefined,
    productCondition: str(raw, "product_condition", "productCondition") || undefined,
    weightKg: num(raw, "weight_kg", "weightKg") || undefined,
    material: str(raw, "material") || undefined,
    careInstructions: str(raw, "care_instructions", "careInstructions") || undefined,
    tags: Array.isArray(raw.tags)
      ? (raw.tags as string[])
      : typeof raw.tags_json === "string"
        ? JSON.parse(raw.tags_json)
        : undefined,
    rating: num(raw, "rating"),
    reviewCount: num(raw, "review_count", "reviewCount"),
    sellerId: str(raw, "store_id", "sellerId"),
    sellerName: str(raw, "seller_name", "sellerName", storeName ?? ""),
    sellerLogo: normalizeImagePath(str(raw, "seller_logo", "sellerLogo") as string | null | undefined) ?? undefined,
    visibility: bool(raw, "visibility"),
    createdAt: str(raw, "created_at", "createdAt", new Date().toISOString()),
    updatedAt: str(raw, "updated_at", "updatedAt", new Date().toISOString()),
  }
}

export function normalizeProductList(rawList: unknown[], storeName?: string): Product[] {
  return rawList.map(item => normalizeProduct(item as Record<string, unknown>, storeName))
}

export function normalizeMediaPath(path: string | null | undefined): string {
  if (!path) return ""
  const resolved = resolveImageUrl(path)
  return resolved ?? path
}
