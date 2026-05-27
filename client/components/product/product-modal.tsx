"use client"

import { useState } from "react"
import Image from "next/image"
import Link from "next/link"
import { motion, AnimatePresence } from "framer-motion"
import type { Product, ProductVariation } from "@/lib/types"
import { useCart } from "@/context/cart-context"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { formatPrice } from "@/lib/format"
import { VariantPicker } from "@/components/product/variant-picker"
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog"
import { useToast } from "@/hooks/use-toast"

interface ProductModalProps {
  product: Product
  open: boolean
  onClose: () => void
}

export function ProductModal({ product, open, onClose }: ProductModalProps) {
  const [selectedVariation, setSelectedVariation] = useState<ProductVariation | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [currentImageIndex, setCurrentImageIndex] = useState(0)
  const { addToCart } = useCart()
  const { toast } = useToast()
  const [imageError, setImageError] = useState(false)

  const currentPrice = product.salePrice || product.price

  const handleAddToCart = async () => {
    if (product.variations?.length && !selectedVariation) {
      toast({ title: "Please select a variation", variant: "destructive" })
      return
    }
    try {
      await addToCart(product, quantity, selectedVariation!)
      toast({ title: "Added to cart", description: `${product.name} has been added to your cart.` })
    } catch {
      toast({ title: "Could not add to cart", variant: "destructive" })
    }
  }

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="w-[calc(100vw-2rem)] max-w-4xl max-h-[90vh] p-0 overflow-hidden rounded-2xl">
        <DialogTitle className="sr-only">{product.name}</DialogTitle>

        <div className="flex flex-col md:flex-row md:h-[80vh]">
          {/* ── Image Column ── */}
          <div className="relative bg-muted md:w-1/2 md:h-full overflow-hidden">
            <div className="relative aspect-square md:aspect-auto md:h-full min-w-0">
              <AnimatePresence mode="wait">
                <motion.div
                  key={currentImageIndex}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="absolute inset-0"
                >
                  {imageError ? (
                    <div className="w-full h-full flex items-center justify-center bg-muted">
                      <Icon name="image" className="text-muted-foreground/50" size="xl" />
                    </div>
                  ) : (
                    <Image
                      src={product.images[currentImageIndex] || "/placeholder.svg"}
                      alt={product.name}
                      fill
                      className="object-cover"
                      onError={() => setImageError(true)}
                    />
                  )}
                </motion.div>
              </AnimatePresence>
            </div>

            {/* Thumbnails strip */}
            {product.images.length > 1 && (
              <div className="absolute bottom-3 left-3 right-3 flex gap-2 overflow-x-auto no-scrollbar">
                {product.images.map((img, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentImageIndex(index)}
                    className={`relative w-12 h-12 rounded-lg overflow-hidden shrink-0 border-2 transition-all ${
                      index === currentImageIndex
                        ? "border-white shadow-lg ring-1 ring-black/10 scale-105"
                        : "border-white/60 opacity-70 hover:opacity-100"
                    }`}
                  >
                    <Image src={img || "/placeholder.svg"} alt="" fill className="object-cover" />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* ── Details Column ── */}
          <div className="flex flex-col flex-1 min-w-0 md:w-1/2">
            <div className="flex-1 overflow-y-auto p-6 pb-4">
              {/* Seller */}
              <Link
                href={`/seller/${product.sellerId}`}
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-primary uppercase tracking-wider hover:underline"
              >
                <Icon name="store" size="sm" />
                {product.sellerName}
              </Link>

              {/* Name */}
              <h2 className="text-xl md:text-2xl font-bold mt-1.5 mb-2 leading-tight">{product.name}</h2>

              {/* Rating row */}
              <div className="flex items-center gap-2 text-sm mb-4">
                <div className="flex items-center gap-0.5">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <Icon
                      key={star}
                      name="star"
                      size="sm"
                      className={
                        star <= Math.round(product.rating || 0)
                          ? "text-amber-400 fill-amber-400"
                          : "text-gray-300"
                      }
                    />
                  ))}
                </div>
                <span className="font-medium">{product.rating}</span>
                <span className="text-muted-foreground">({product.reviewCount} reviews)</span>
              </div>

              {/* Price */}
              <div className="flex items-baseline gap-3 mb-5">
                <span className="text-2xl md:text-3xl font-bold text-primary">
                  {formatPrice(currentPrice)}
                </span>
                {product.salePrice && (
                  <span className="text-base text-muted-foreground line-through">
                    {formatPrice(product.price)}
                  </span>
                )}
                {product.salePrice && (
                  <span className="text-xs font-semibold text-green-600 bg-green-100 dark:bg-green-900/40 dark:text-green-400 px-2 py-0.5 rounded-full">
                    -{Math.round((1 - product.salePrice / product.price) * 100)}%
                  </span>
                )}
              </div>

              {/* Description */}
              {product.description && (
                <div
                  className="text-sm text-muted-foreground leading-relaxed mb-5 line-clamp-3 prose prose-sm max-w-none"
                  dangerouslySetInnerHTML={{ __html: product.description }}
                />
              )}

              {/* Divider */}
              <hr className="mb-5 border-muted" />

              {/* Variant Picker */}
              <VariantPicker
                variations={product.variations}
                selected={selectedVariation}
                onSelect={setSelectedVariation}
              />

              {/* Quantity */}
              <div className="mt-5">
                <label className="text-sm font-medium mb-2.5 block">Quantity</label>
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="w-10 h-10 rounded-xl border flex items-center justify-center hover:bg-muted transition-colors active:scale-95"
                    aria-label="Decrease quantity"
                  >
                    <Icon name="minus" />
                  </button>
                  <span className="w-12 text-center font-semibold text-lg">{quantity}</span>
                  <button
                    onClick={() => setQuantity(quantity + 1)}
                    className="w-10 h-10 rounded-xl border flex items-center justify-center hover:bg-muted transition-colors active:scale-95"
                    aria-label="Increase quantity"
                  >
                    <Icon name="plus" />
                  </button>
                </div>
              </div>
            </div>

            {/* ── Sticky Actions ── */}
            <div className="p-6 pt-4 border-t bg-background">
              <div className="flex gap-3">
                <Button variant="outline" className="flex-1" onClick={handleAddToCart}>
                  <Icon name="shopping-cart" className="mr-2" />
                  Add to Cart
                </Button>
                <Button className="flex-1" onClick={handleAddToCart}>
                  Buy Now
                </Button>
              </div>
              <Link
                href={`/product/${product.slug}`}
                className="block text-center text-xs text-muted-foreground hover:text-primary hover:underline mt-3"
                onClick={onClose}
              >
                View Full Details &rarr;
              </Link>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
