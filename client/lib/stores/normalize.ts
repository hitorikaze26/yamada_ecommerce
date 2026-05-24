import { resolveImageUrl } from "@/lib/api"
import type { Product } from "@/lib/types"
import type { StoreProfile, StoreReview } from "./types"

const slugify = (value: string): string =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")

export function normalizeStoreProduct(raw: Record<string, unknown>, storeName?: string): Product {
  const numericId = String(raw.id ?? "")
  const name = String(raw.name ?? "")
  const slugRaw = String(raw.slug ?? numericId)
  const slug =
    slugRaw.includes("-") && slugRaw !== numericId
      ? slugRaw
      : `${numericId}-${slugify(name || numericId)}`

  const apiCategories: string[] = Array.isArray(raw.categories)
    ? (raw.categories as string[])
    : []

  let imageUrl = (raw.image_url as string) ?? (raw.imageUrl as string) ?? undefined
  if (imageUrl) {
    imageUrl = resolveImageUrl(imageUrl) ?? imageUrl
  }

  const imagesRaw = Array.isArray(raw.images) ? (raw.images as string[]) : []
  const images = Array.from(
    new Set(
      [imageUrl, ...imagesRaw.map((u) => resolveImageUrl(u) ?? u)].filter(Boolean) as string[],
    ),
  )

  return {
    id: numericId,
    slug,
    name,
    category: apiCategories[0] ?? String(raw.category ?? ""),
    subcategory: (raw.subcategory as string) ?? undefined,
    categories: apiCategories,
    description: String(raw.description ?? ""),
    images,
    variations: Array.isArray(raw.variations)
      ? (raw.variations as Record<string, unknown>[]).map((v) => ({
          id: String(v.id),
          size: String(v.size ?? ""),
          color: String(v.color ?? ""),
          sku: String(v.sku ?? ""),
          inventory: typeof v.inventory === "number" ? v.inventory : 0,
          price: typeof v.price === "number" ? v.price : undefined,
        }))
      : [],
    price: typeof raw.price === "number" ? raw.price : Number(raw.price ?? 0),
    salePrice:
      typeof raw.sale_price === "number"
        ? raw.sale_price
        : typeof raw.salePrice === "number"
          ? raw.salePrice
          : undefined,
    rating: typeof raw.rating === "number" ? raw.rating : 0,
    reviewCount:
      typeof raw.review_count === "number"
        ? raw.review_count
        : typeof raw.reviewCount === "number"
          ? raw.reviewCount
          : 0,
    sellerId: String(raw.store_id ?? raw.sellerId ?? ""),
    sellerName: String(raw.seller_name ?? raw.sellerName ?? storeName ?? ""),
    sellerLogo: undefined,
    visibility: true,
    createdAt: String(raw.created_at ?? raw.createdAt ?? new Date().toISOString()),
    updatedAt: String(raw.updated_at ?? raw.updatedAt ?? new Date().toISOString()),
  }
}

export function normalizeStoreProfile(raw: Record<string, unknown>): StoreProfile {
  const id = Number(raw.id ?? raw.store_id ?? 0)
  return {
    id,
    storeId: id,
    name: String(raw.name ?? raw.store_name ?? "Store"),
    tagline: String(raw.tagline ?? ""),
    description: String(raw.description ?? ""),
    email: (raw.email as string) ?? null,
    phone: (raw.phone as string) ?? null,
    address: (raw.address as string) ?? null,
    country: (raw.country as string) ?? null,
    logoUrl: resolveImageUrl((raw.logo_url as string) ?? (raw.logoUrl as string) ?? null),
    bannerUrl: resolveImageUrl((raw.banner_url as string) ?? (raw.bannerUrl as string) ?? null),
    rating: typeof raw.rating === "number" ? raw.rating : 0,
    reviewCount: Number(raw.review_count ?? raw.reviewCount ?? 0),
    followersCount: Number(raw.followers_count ?? raw.followersCount ?? 0),
    responseRate: Number(raw.response_rate ?? raw.responseRate ?? 0),
    responseTime: String(raw.response_time ?? raw.responseTime ?? ""),
    joinedAt: (raw.joined_at as string) ?? (raw.joinedAt as string) ?? null,
    isVerified: Boolean(raw.is_verified ?? raw.isVerified),
    isOpen: Boolean(raw.is_open ?? raw.isOpen),
    businessHours: String(raw.business_hours ?? raw.businessHours ?? ""),
    lastActive: String(raw.last_active ?? raw.lastActive ?? ""),
    isOnline: Boolean(raw.is_online ?? raw.isOnline),
    productCount: Number(raw.product_count ?? raw.productCount ?? 0),
    completedOrders: Number(raw.completed_orders ?? raw.completedOrders ?? 0),
    cancellationRate: Number(raw.cancellation_rate ?? raw.cancellationRate ?? 0),
    shippingRegionsCount: Number(raw.shipping_regions_count ?? raw.shippingRegionsCount ?? 0),
    shippingSummary: String(raw.shipping_summary ?? raw.shippingSummary ?? ""),
    categories: Array.isArray(raw.categories) ? (raw.categories as string[]) : [],
    announcement: (raw.announcement as string) ?? null,
    trustBadges: Array.isArray(raw.trust_badges ?? raw.trustBadges)
      ? ((raw.trust_badges ?? raw.trustBadges) as Record<string, unknown>[]).map((b) => ({
          id: String(b.id ?? b.label ?? ""),
          label: String(b.label ?? ""),
          description: (b.description as string) ?? undefined,
        }))
      : [],
    policies: {
      allowCancellation: Boolean(
        (raw.policies as Record<string, unknown>)?.allow_cancellation ??
          (raw.policies as Record<string, unknown>)?.allowCancellation ??
          true,
      ),
      maxCancellationHours: Number(
        (raw.policies as Record<string, unknown>)?.max_cancellation_hours ??
          (raw.policies as Record<string, unknown>)?.maxCancellationHours ??
          24,
      ),
      allowReturns: Boolean(
        (raw.policies as Record<string, unknown>)?.allow_returns ??
          (raw.policies as Record<string, unknown>)?.allowReturns ??
          true,
      ),
      returnPeriodDays: Number(
        (raw.policies as Record<string, unknown>)?.return_period_days ??
          (raw.policies as Record<string, unknown>)?.returnPeriodDays ??
          7,
      ),
    },
  }
}

export function normalizeStoreReview(raw: Record<string, unknown>): StoreReview {
  const productId = raw.productId != null ? Number(raw.productId) : null
  const productName = (raw.productName as string) ?? null
  const productSlug =
    productId && productName
      ? `${productId}-${slugify(productName)}`
      : productId
        ? String(productId)
        : null

  return {
    id: Number(raw.id ?? 0),
    rating: Number(raw.rating ?? 0),
    comment: (raw.comment as string) ?? null,
    createdAt: (raw.createdAt as string) ?? null,
    productId,
    productName,
    productImage: resolveImageUrl((raw.productImage as string) ?? null),
    productSlug,
    buyerName: (raw.buyerName as string) ?? null,
    verifiedPurchase: Boolean(raw.verifiedPurchase),
  }
}
