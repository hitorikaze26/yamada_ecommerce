/** Seller routes blocked until store registration is ACCEPTED. */
export const SELLER_RESTRICTED_PATHS = [
  "/seller/products",
  "/seller/orders",
  "/seller/analytics",
  "/seller/shop",
  "/seller/wallet",
  "/seller/refunds",
  "/seller/coupons",
  "/seller/insights",
  "/seller/feedback",
] as const

export function isSellerRestrictedPath(pathname: string): boolean {
  return SELLER_RESTRICTED_PATHS.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  )
}

export const SELLER_PENDING_SWAL_TEXT =
  "Your store is still pending admin approval. Use the dashboard and Account settings while you wait."
