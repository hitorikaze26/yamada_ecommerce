export type ReviewFormat = "default" | "accessories_shoes"

export const DIMENSION_LABELS_DEFAULT: Record<string, string> = {
  quality: "Quality",
  fabricFeel: "Fabric Feel",
  comfort: "Comfort",
  fit: "Fit",
  appearance: "Appearance",
  productAccuracy: "Product Accuracy",
  packaging: "Packaging",
  deliveryExperience: "Delivery Experience",
}

export const DIMENSION_LABELS_ACCESSORIES: Record<string, string> = {
  quality: "Quality",
  comfort: "Comfort",
  fit: "Fit",
  sizingAccuracy: "Sizing Accuracy",
  materialQuality: "Material Quality",
  appearance: "Appearance",
  durability: "Durability",
  packaging: "Packaging",
  deliveryExperience: "Delivery Experience",
}

export const DIMENSION_KEYS_DEFAULT = Object.keys(DIMENSION_LABELS_DEFAULT)
export const DIMENSION_KEYS_ACCESSORIES = Object.keys(DIMENSION_LABELS_ACCESSORIES)

export function dimensionKeysForFormat(format: ReviewFormat): string[] {
  return format === "accessories_shoes" ? DIMENSION_KEYS_ACCESSORIES : DIMENSION_KEYS_DEFAULT
}

export function dimensionLabelsForFormat(format: ReviewFormat): Record<string, string> {
  return format === "accessories_shoes" ? DIMENSION_LABELS_ACCESSORIES : DIMENSION_LABELS_DEFAULT
}

export interface ReviewableItem {
  orderItemId: number
  productId: number
  productName?: string | null
  variant?: { color?: string; size?: string } | null
  unitPrice?: number
  quantity?: number
  reviewFormat: ReviewFormat
}

export interface ProductReviewPayload {
  orderItemId: number
  reviewFormat: ReviewFormat
  overallRating?: number
  ratings: Record<string, number>
  customerReview?: string
  deliverySatisfaction: number
  deliveryPills: string[]
}

export interface SerializedReview {
  id: number
  rating: number
  reviewFormat?: ReviewFormat
  ratings?: Record<string, number>
  comment?: string | null
  deliverySatisfaction?: number | null
  deliveryPills?: string[]
  createdAt?: string | null
  productId?: number | null
  productName?: string | null
  buyerName?: string | null
  sellerReply?: string | null
  sellerReplyAt?: string | null
  variant?: string | null
  unitPrice?: number | null
  quantity?: number | null
  orderItemId?: number | null
  orderId?: number | null
  productImage?: string | null
}
