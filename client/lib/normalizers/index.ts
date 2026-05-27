export {
  normalizeProduct,
  normalizeProductList,
  normalizeMediaPath,
} from "./product"

export {
  normalizeUser,
  normalizeBuyerProfile,
  normalizeSellerProfile,
  normalizeRiderProfile,
  normalizeAdminUser,
} from "./user"
export type { NormalizedAdminUser } from "./user"

export {
  normalizeOrder,
  normalizeOrderList,
  normalizeOrderItem,
  normalizeOrderStatus,
  getEffectiveOrderStatus,
  canBuyerConfirmReceipt,
  canBuyerLeaveReview,
  getOrderTimelineIndex,
  formatOrderStatusLabel,
  shouldPollOrderStatus,
  ORDER_TRACKING_STEPS,
} from "./order"

export {
  normalizeCart,
  normalizeCartItem,
} from "./cart"

export {
  normalizeStoreProfile,
  normalizeStoreProduct,
  normalizeStoreReview,
} from "./store"

export {
  normalizeReview,
  normalizeReviewList,
} from "./review"

export {
  normalizeNotification,
  normalizeNotificationList,
} from "./notification"

export {
  normalizeDashboardOverview,
  normalizeSalesData,
  normalizeCategoryPerformance,
} from "./analytics"

// Re-export store types for convenience
export type { StoreProfile, StoreReview, StoreTrustBadge, StorePolicies } from "@/lib/stores/types"
