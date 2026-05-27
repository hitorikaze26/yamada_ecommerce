import { resolveImageUrl } from "@/lib/api"
import type { Cart, CartItem, Product, ProductVariation } from "@/lib/types"
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

function _read(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

export function normalizeCartItem(raw: Record<string, unknown>): CartItem {
  const productRaw = (raw.product ?? raw.productData ?? {}) as Record<string, unknown>
  const variationRaw = (raw.variation ?? raw.selectedVariation ?? {}) as Record<string, unknown>
  const product = normalizeProduct(productRaw)
  const variation: ProductVariation = {
    id: str(variationRaw, "id"),
    size: str(variationRaw, "size"),
    color: str(variationRaw, "color"),
    colorHex: str(variationRaw, "colorHex", "color_hex") || undefined,
    sku: str(variationRaw, "sku"),
    inventory: num(variationRaw, "inventory"),
    price: typeof variationRaw.price === "number" ? variationRaw.price : undefined,
  }
  return {
    id: str(raw, "id", "itemId", "cartItemId"),
    product,
    quantity: num(raw, "quantity"),
    selectedVariation: variation,
  }
}

export function normalizeCart(raw: Record<string, unknown>): Cart {
  const itemsRaw = Array.isArray(raw.items || raw.cart_items) ? ((raw.items || raw.cart_items) as Record<string, unknown>[]) : []
  const items = itemsRaw.map(normalizeCartItem)
  const subtotal = items.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const shipping = num(raw, "shipping", "shippingFee", "shipping_fee")
  return {
    items,
    subtotal,
    shipping,
    total: subtotal + shipping,
  }
}
