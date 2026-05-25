import { resolveImageUrl } from "./api"

export function productCoverImage(
  product?: {
    images?: string[]
    image_url?: string | null
    imageUrl?: string | null
  } | null,
): string {
  if (!product) return "/placeholder.svg"

  if (product.images?.length) {
    const resolved = resolveImageUrl(product.images[0])
    if (resolved) return resolved
  }

  if (product.image_url) {
    const resolved = resolveImageUrl(product.image_url)
    if (resolved) return resolved
  }

  if (product.imageUrl) {
    const resolved = resolveImageUrl(product.imageUrl)
    if (resolved) return resolved
  }

  return "/placeholder.svg"
}

export function productImageAtIndex(
  product?: {
    images?: string[]
    image_url?: string | null
    imageUrl?: string | null
  } | null,
  index: number = 0,
): string {
  const cover = productCoverImage(product)
  if (index === 0) return cover

  if (product?.images && index < product.images.length) {
    const resolved = resolveImageUrl(product.images[index])
    if (resolved) return resolved
  }

  return "/placeholder.svg"
}
