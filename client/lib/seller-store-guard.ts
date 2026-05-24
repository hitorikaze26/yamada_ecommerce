import { sellerAccountApi } from "@/lib/api"

export interface SellerStoreGate {
  storeId: number | null
  isApproved: boolean
  canManageStore: boolean
}

/** Whether seller can add products / use commerce features. */
export async function fetchSellerStoreGate(): Promise<SellerStoreGate> {
  const res = await sellerAccountApi.getProfile()
  const profile = res.data.profile as {
    storeId?: number | null
    storeStatus?: string | null
    isVerified?: boolean
  }
  const storeId =
    profile?.storeId != null && profile.storeId !== 0
      ? Number(profile.storeId)
      : null
  const isApproved =
    profile?.isVerified === true || profile?.storeStatus === "ACCEPTED"
  return {
    storeId,
    isApproved,
    canManageStore: isApproved && storeId != null,
  }
}

/** Block adding own-store products to cart when seller is browsing as customer. */
export async function assertNotOwnStoreProduct(productSellerId: string): Promise<void> {
  if (!productSellerId?.trim()) return
  const gate = await fetchSellerStoreGate()
  if (gate.storeId == null) return
  const sid = String(gate.storeId)
  if (productSellerId === sid || productSellerId === String(gate.storeId)) {
    throw new Error("You cannot purchase products from your own store.")
  }
}
