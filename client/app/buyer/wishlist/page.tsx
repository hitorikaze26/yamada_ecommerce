"use client"
import { useState } from "react"
import Link from "next/link"
import Image from "next/image"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { resolveImageUrl } from "@/lib/api"
import { GlassAlert } from "@/components/ui/glass-alert"
import { useCart } from "@/context/cart-context"
import { useWishlist } from "@/context/wishlist-context"
import type { Product } from "@/lib/types"
import { formatPrice } from "@/lib/format"

export default function WishlistPage() {
  const { items: wishlistItems, isLoading, error, removeFromWishlist, fetchWishlist } = useWishlist()
  const { addToCart } = useCart()
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const handleRemove = async (productId: string | number) => {
    try {
      await removeFromWishlist(productId)
      showAlert("Removed from wishlist.", "success")
    } catch (err) {
      console.error("Failed to remove from wishlist", err)
      showAlert("Failed to remove item from wishlist. Please try again.", "error")
    }
  }

  const handleAddToCart = (product: Product) => {
    const variation = {
      id: "default",
      size: "",
      color: "",
      sku: "",
      inventory: 0,
    }

    addToCart(product, 1, variation)
    showAlert("Added to cart.", "success")
  }

  return (
    <div className="space-y-6">
      <GlassAlert
        open={alertOpen && !!alertMessage}
        title={
          alertVariant === "success"
            ? "Success"
            : alertVariant === "error"
              ? "Error"
              : alertVariant === "warning"
                ? "Warning"
                : "Notice"
        }
        description={alertMessage ?? undefined}
        variant={alertVariant}
        onClose={() => setAlertOpen(false)}
      />
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">My Wishlist</h1>
          <p className="text-muted-foreground">{wishlistItems.length} items saved</p>
        </div>
        {error && (
          <button
            type="button"
            onClick={() => void fetchWishlist()}
            className="text-sm text-primary hover:underline shrink-0"
          >
            Refresh
          </button>
        )}
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading wishlist...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && wishlistItems.length === 0 ? (
        <div className="bg-card border rounded-2xl p-12 text-center">
          <Icon name="heart" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h3 className="text-lg font-semibold mb-2">Your wishlist is empty</h3>
          <p className="text-muted-foreground mb-4">Save items you love to buy them later.</p>
          <Link
            href="/search"
            className="inline-flex items-center gap-2 px-6 py-3 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
          >
            Discover Products
          </Link>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <AnimatePresence>
            {wishlistItems.map((product) => (
              <motion.div
                key={product.id}
                layout
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                className="bg-card border rounded-2xl overflow-hidden group"
              >
                <div className="relative aspect-square">
                  <Image
                    src={resolveImageUrl(product.image_url || product.images?.[0]) || "/placeholder.svg"}
                    alt={product.name}
                    fill
                    className="object-cover"
                  />
                  <button
                    type="button"
                    onClick={() => void handleRemove(product.id)}
                    className="absolute top-3 right-3 w-10 h-10 rounded-full bg-white/90 dark:bg-black/50 flex items-center justify-center text-red-500 hover:bg-red-500 hover:text-white transition-colors"
                  >
                    <Icon name="heart-solid" />
                  </button>
                  {product.salePrice && (
                    <span className="absolute top-3 left-3 px-2 py-1 bg-red-500 text-white text-xs font-medium rounded-lg">
                      -{Math.round(((product.price - product.salePrice) / product.price) * 100)}%
                    </span>
                  )}
                </div>

                <div className="p-4">
                  <Link href={`/product/${product.slug || product.id}`}>
                    <h3 className="font-semibold line-clamp-1 hover:text-primary transition-colors">{product.name}</h3>
                  </Link>
                  {product.sellerId ? (
                    <Link
                      href={`/store/${product.sellerId}`}
                      className="text-sm text-muted-foreground mb-3 block hover:text-primary"
                    >
                      {product.sellerName || "View boutique"}
                    </Link>
                  ) : (
                    <p className="text-sm text-muted-foreground mb-3">{product.sellerName || "Yamada Shop"}</p>
                  )}

                  <div className="flex items-center justify-between">
                    <div>
                      <span className="font-bold text-primary">
                        {formatPrice(product.salePrice ?? product.price)}
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleAddToCart(product)}
                      className="w-10 h-10 rounded-full bg-primary text-primary-foreground flex items-center justify-center hover:bg-primary/90 transition-colors"
                    >
                      <Icon name="shopping-cart" />
                    </button>
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  )
}
