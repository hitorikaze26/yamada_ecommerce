import type { Product, ProductVariation } from "@/lib/types"

const BUY_NOW_STORAGE_KEY = "yamada_buy_now_checkout"

export type BuyNowCheckoutPayload = {
  product: Product
  quantity: number
  selectedVariation: ProductVariation
}

export function setBuyNowCheckout(payload: BuyNowCheckoutPayload): void {
  if (typeof window === "undefined") return
  sessionStorage.setItem(BUY_NOW_STORAGE_KEY, JSON.stringify(payload))
}

export function getBuyNowCheckout(): BuyNowCheckoutPayload | null {
  if (typeof window === "undefined") return null
  const raw = sessionStorage.getItem(BUY_NOW_STORAGE_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as BuyNowCheckoutPayload
  } catch {
    return null
  }
}

export function clearBuyNowCheckout(): void {
  if (typeof window === "undefined") return
  sessionStorage.removeItem(BUY_NOW_STORAGE_KEY)
}

/** Build a cart-line shape for checkout UI from a buy-now payload. */
export function buyNowPayloadToCartItem(payload: BuyNowCheckoutPayload) {
  const { product, quantity, selectedVariation } = payload
  return {
    id: `buy-now-${product.id}-${selectedVariation.id}`,
    product,
    quantity,
    selectedVariation,
  }
}
