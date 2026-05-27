import type { User, BuyerProfile, SellerProfile, RiderProfile, UserRole } from "@/lib/types"
import { resolveImageUrl } from "@/lib/api"

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
  return 0
}

function bool(raw: Record<string, unknown>, ...keys: string[]): boolean {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return Boolean(v)
  }
  return false
}

export function normalizeUser(raw: Record<string, unknown>): User {
  return {
    id: str(raw, "id", "user_id", "userId"),
    email: str(raw, "email", "User email"),
    givenName: str(raw, "givenName", "given_name"),
    surname: str(raw, "surname"),
    role: (str(raw, "role", "user_role", "userRole") as UserRole) || "buyer",
    contactNumber: str(raw, "contactNumber", "contact_number"),
    avatar: resolveImageUrl(str(raw, "avatar", "avatarUrl", "avatar_url", "avatarUrl") || null) ?? undefined,
    isVerified: bool(raw, "isVerified", "is_verified"),
    storeId: raw.storeId != null ? Number(raw.storeId) : raw.store_id != null ? Number(raw.store_id) : null,
    storeStatus: str(raw, "storeStatus", "store_status") || null,
    shopName: str(raw, "shopName", "shop_name"),
    createdAt: str(raw, "createdAt", "created_at", new Date().toISOString()),
    updatedAt: str(raw, "updatedAt", "updated_at", new Date().toISOString()),
  }
}

export function normalizeBuyerProfile(raw: Record<string, unknown>): BuyerProfile {
  const user = normalizeUser(raw)
  const addressesRaw = Array.isArray(raw.addresses) ? raw.addresses : []
  return {
    ...user,
    role: "buyer",
    addresses: addressesRaw.map((a: Record<string, unknown>) => ({
      id: str(a, "id"),
      label: str(a, "label") || undefined,
      regionCode: str(a, "regionCode", "region_code"),
      regionName: str(a, "regionName", "region_name"),
      provinceCode: str(a, "provinceCode", "province_code"),
      provinceName: str(a, "provinceName", "province_name"),
      municipalityCode: str(a, "municipalityCode", "municipality_code"),
      municipalityName: str(a, "municipalityName", "municipality_name"),
      barangayCode: str(a, "barangayCode", "barangay_code"),
      barangayName: str(a, "barangayName", "barangay_name"),
      streetAddress: str(a, "streetAddress", "street_address") || undefined,
      postalCode: str(a, "postalCode", "postal_code") || undefined,
      isDefault: bool(a, "isDefault", "is_default"),
    })),
    documents: {
      validId: str(raw, "validId", "valid_id", "validIdPath") || undefined,
    },
  }
}

export function normalizeSellerProfile(raw: Record<string, unknown>): SellerProfile {
  const user = normalizeUser(raw)
  return {
    ...user,
    role: "seller",
    shopName: str(raw, "shopName", "shop_name", "name"),
    shopLogo: resolveImageUrl(str(raw, "shopLogo", "shop_logo", "logoUrl", "logo_url") || null) ?? undefined,
    tagline: str(raw, "tagline") || undefined,
    description: str(raw, "description") || undefined,
    categories: Array.isArray(raw.categories) ? (raw.categories as string[]) : [],
    rating: num(raw, "rating"),
    totalSales: num(raw, "totalSales", "total_sales"),
    verified: bool(raw, "verified", "isVerified", "is_verified"),
    address: {
      id: str(raw, "address_id", "addressId") || "seller-addr",
      regionCode: str(raw, "regionCode", "region_code"),
      regionName: str(raw, "regionName", "region_name"),
      provinceCode: str(raw, "provinceCode", "province_code"),
      provinceName: str(raw, "provinceName", "province_name"),
      municipalityCode: str(raw, "municipalityCode", "municipality_code"),
      municipalityName: str(raw, "municipalityName", "municipality_name"),
      barangayCode: str(raw, "barangayCode", "barangay_code"),
      barangayName: str(raw, "barangayName", "barangay_name"),
      streetAddress: str(raw, "streetAddress", "street_address") || undefined,
      postalCode: str(raw, "postalCode", "postal_code") || undefined,
      isDefault: true,
    },
    documents: {
      dti: str(raw, "dti") || undefined,
      birTin: str(raw, "birTin", "bir_tin") || undefined,
      businessPermit: str(raw, "businessPermit", "business_permit") || undefined,
      validId: str(raw, "validId", "valid_id") || undefined,
    },
  }
}

export function normalizeRiderProfile(raw: Record<string, unknown>): RiderProfile {
  const user = normalizeUser(raw)
  return {
    ...user,
    role: "rider",
    vehicleType: str(raw, "vehicleType", "vehicle_type"),
    licenseNumber: str(raw, "licenseNumber", "license_number"),
    rating: num(raw, "rating"),
    totalDeliveries: num(raw, "totalDeliveries", "total_deliveries"),
    verified: bool(raw, "verified", "isVerified", "is_verified"),
    address: {
      id: str(raw, "address_id", "addressId") || "rider-addr",
      regionCode: str(raw, "regionCode", "region_code"),
      regionName: str(raw, "regionName", "region_name"),
      provinceCode: str(raw, "provinceCode", "province_code"),
      provinceName: str(raw, "provinceName", "province_name"),
      municipalityCode: str(raw, "municipalityCode", "municipality_code"),
      municipalityName: str(raw, "municipalityName", "municipality_name"),
      barangayCode: str(raw, "barangayCode", "barangay_code"),
      barangayName: str(raw, "barangayName", "barangay_name"),
      streetAddress: str(raw, "streetAddress", "street_address") || undefined,
      postalCode: str(raw, "postalCode", "postal_code") || undefined,
      isDefault: true,
    },
    documents: {
      license: str(raw, "license") || undefined,
      orCr: str(raw, "orCr", "or_cr") || undefined,
    },
  }
}

// Admin-specific normalization (preserves legacy keys for backward compat)
export interface NormalizedAdminUser {
  id: number
  email: string
  username: string
  givenName: string | null
  surname: string | null
  contactNumber: string | null
  active: boolean
  emailVerified: boolean
  isArchived: boolean
  lastActiveAt: string | null
  updatedAt: string | null
  roles: string[]
  primaryRole: string
  createdAt: string | null
  buyerProfile: Record<string, unknown> | null
  "User email": string
  "User active": boolean
  "User verified": boolean
  Username: string
  given_name: string | null
  contact_number: string | null
  created_at: string | null
  user_role: string[]
  buyer_profile: Record<string, unknown> | null
}

export function userNeedsApproval(user: NormalizedAdminUser): boolean {
  const role = user.primaryRole || user.roles[0] || ""
  return role === "buyer" && user.active && !user.emailVerified && !user.isArchived
}

export function userCanArchive(user: NormalizedAdminUser, isAdmin = false): boolean {
  if (isAdmin || user.isArchived || userNeedsApproval(user)) return false
  return !user["User active"]
}

export function adminUserDisplayName(user: NormalizedAdminUser | Record<string, unknown>): string {
  const u = "User email" in user ? (user as NormalizedAdminUser) : normalizeAdminUser(user as Record<string, unknown>)
  const given = u.given_name?.trim()
  const surname = u.surname?.trim()
  if (given || surname) return `${given ?? ""} ${surname ?? ""}`.trim()
  if (u.Username && u.Username !== u["User email"]) return u.Username
  const email = u["User email"]
  if (email) {
    const local = email.split("@")[0]
    return local || email
  }
  return "(no name)"
}

export function normalizeAdminUser(raw: Record<string, unknown>): NormalizedAdminUser {
  const roles = Array.isArray(raw.user_role)
    ? (raw.user_role as string[])
    : Array.isArray(raw.userRole)
      ? (raw.userRole as string[])
      : raw.role
        ? [String(raw.role)]
        : []

  const email = str(raw, "User email", "email")
  const username = str(raw, "Username", "username")
  const givenName = (raw.given_name ?? raw.givenName ?? null) as string | null
  const surname = (raw.surname ?? null) as string | null
  const contactNumber = (raw.contact_number ?? raw.contactNumber ?? null) as string | null
  const active = bool(raw, "User active", "active")
  const emailVerified = bool(raw, "User verified", "emailVerified")
  const createdAt = (raw.created_at ?? raw.createdAt ?? null) as string | null
  const updatedAt = (raw.updated_at ?? raw.updatedAt ?? null) as string | null
  const lastActiveAt = (raw.last_active_at ?? raw.lastActiveAt ?? updatedAt ?? createdAt) as string | null
  const isArchived = bool(raw, "is_archived", "isArchived")
  const buyerProfile = (raw.buyer_profile ?? raw.buyerProfile ?? null) as Record<string, unknown> | null

  return {
    id: Number(raw.id),
    email,
    username,
    givenName,
    surname,
    contactNumber,
    active,
    emailVerified,
    isArchived,
    lastActiveAt,
    updatedAt,
    roles,
    primaryRole: roles[0] ?? str(raw, "role", "unknown"),
    createdAt,
    buyerProfile,
    "User email": email,
    "User active": active,
    "User verified": emailVerified,
    Username: username,
    given_name: givenName,
    contact_number: contactNumber,
    created_at: createdAt,
    user_role: roles,
    buyer_profile: buyerProfile,
  }
}
