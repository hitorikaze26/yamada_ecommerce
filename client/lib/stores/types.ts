export interface StoreTrustBadge {
  id: string
  label: string
  description?: string
}

export interface StorePolicies {
  allowCancellation?: boolean
  maxCancellationHours?: number
  allowReturns?: boolean
  returnPeriodDays?: number
}

export interface StoreProfile {
  id: number
  storeId: number
  name: string
  tagline: string
  description: string
  email?: string | null
  phone?: string | null
  address?: string | null
  country?: string | null
  logoUrl?: string | null
  bannerUrl?: string | null
  rating: number
  reviewCount: number
  followersCount: number
  responseRate: number
  responseTime: string
  joinedAt?: string | null
  isVerified: boolean
  isOpen: boolean
  businessHours: string
  lastActive: string
  isOnline: boolean
  productCount: number
  completedOrders: number
  cancellationRate: number
  shippingRegionsCount: number
  shippingSummary: string
  categories: string[]
  announcement?: string | null
  trustBadges: StoreTrustBadge[]
  policies: StorePolicies
}

export interface StoreReview {
  id: number
  rating: number
  comment?: string | null
  createdAt?: string | null
  productId?: number | null
  productName?: string | null
  productImage?: string | null
  productSlug?: string | null
  buyerName?: string | null
  verifiedPurchase?: boolean
}
