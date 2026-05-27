import { resolveImageUrl } from "@/lib/api"
import type { Product } from "@/lib/types"
import type { StoreProfile, StoreReview } from "@/lib/stores/types"
import { normalizeProduct } from "./product"

function str(raw: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return String(v)
  }
  return ""
}

function num(raw: Record<string, unknown>, ...keys: string[]): number {
  for (const k of keys) {
    const v = raw[k]
    if (typeof v === "number") return v
  }
  return Number(_read(raw, keys) ?? 0)
}

function bool(raw: Record<string, unknown>, ...keys: string[]): boolean {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return Boolean(v)
  }
  return false
}

function _read(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

const slugify = (value: string): string =>
  value.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")

export function normalizeStoreProfile(raw: Record<string, unknown>): StoreProfile {
  const id = Number(raw.id ?? raw.store_id ?? 0)
  return {
    id,
    storeId: id,
    name: str(raw, "name", "store_name"),
    tagline: str(raw, "tagline"),
    description: str(raw, "description"),
    email: (raw.email as string) ?? null,
    phone: (raw.phone as string) ?? null,
    address: (raw.address as string) ?? null,
    country: (raw.country as string) ?? null,
    logoUrl: resolveImageUrl((raw.logo_url as string) ?? (raw.logoUrl as string) ?? null),
    bannerUrl: resolveImageUrl((raw.banner_url as string) ?? (raw.bannerUrl as string) ?? null),
    rating: num(raw, "rating"),
    reviewCount: num(raw, "review_count", "reviewCount"),
    followersCount: num(raw, "followers_count", "followersCount"),
    responseRate: num(raw, "response_rate", "responseRate"),
    responseTime: str(raw, "response_time", "responseTime"),
    joinedAt: (raw.joined_at as string) ?? (raw.joinedAt as string) ?? null,
    isVerified: bool(raw, "is_verified", "isVerified"),
    isOpen: bool(raw, "is_open", "isOpen"),
    businessHours: str(raw, "business_hours", "businessHours"),
    lastActive: str(raw, "last_active", "lastActive"),
    isOnline: bool(raw, "is_online", "isOnline"),
    productCount: num(raw, "product_count", "productCount"),
    completedOrders: num(raw, "completed_orders", "completedOrders"),
    cancellationRate: num(raw, "cancellation_rate", "cancellationRate"),
    shippingRegionsCount: num(raw, "shipping_regions_count", "shippingRegionsCount"),
    shippingSummary: str(raw, "shipping_summary", "shippingSummary"),
    categories: Array.isArray(raw.categories) ? (raw.categories as string[]) : [],
    announcement: (raw.announcement as string) ?? null,
    trustBadges: Array.isArray(raw.trust_badges ?? raw.trustBadges)
      ? ((raw.trust_badges ?? raw.trustBadges) as Record<string, unknown>[]).map(b => ({
          id: String(b.id ?? b.label ?? ""),
          label: String(b.label ?? ""),
          description: (b.description as string) ?? undefined,
        }))
      : [],
    policies: {
      allowCancellation: bool(_read(raw, ["policies"]) as Record<string, unknown> ?? {}, "allow_cancellation", "allowCancellation") ?? true,
      maxCancellationHours: num(_read(raw, ["policies"]) as Record<string, unknown> ?? {}, "max_cancellation_hours", "maxCancellationHours") || 24,
      allowReturns: bool(_read(raw, ["policies"]) as Record<string, unknown> ?? {}, "allow_returns", "allowReturns") ?? true,
      returnPeriodDays: num(_read(raw, ["policies"]) as Record<string, unknown> ?? {}, "return_period_days", "returnPeriodDays") || 7,
    },
  }
}

export function normalizeStoreProduct(raw: Record<string, unknown>, storeName?: string): Product {
  return normalizeProduct(raw, storeName)
}

export function normalizeStoreReview(raw: Record<string, unknown>): StoreReview {
  const productId = raw.productId != null ? Number(raw.productId) : null
  const productName = (raw.productName as string) ?? null
  const productSlug = productId && productName
    ? `${productId}-${slugify(productName)}`
    : productId ? String(productId) : null
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
