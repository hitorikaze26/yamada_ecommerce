"use client"

import { useState } from "react"
import Image from "next/image"
import Link from "next/link"
import { motion, AnimatePresence } from "framer-motion"
import type { Product, ProductVariation } from "@/lib/types"
import { useCart } from "@/context/cart-context"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { formatPrice } from "@/lib/format"
import { VariantPicker } from "@/components/product/variant-picker"
import { Dialog, DialogContent } from "@/components/ui/dialog"
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
      <DialogContent className="w-[calc(100vw-2rem)] max-w-5xl max-h-[100dvh] sm:max-h-[90vh] p-0 overflow-hidden rounded-xl">

        <div className="flex flex-col md:flex-row md:h-[85vh]">
          {/* ── Image Column ── */}
          <div className="relative bg-muted md:w-[55%] md:h-full overflow-hidden max-h-[50vh] sm:max-h-[55vh] md:max-h-none">
            <div className="relative aspect-[4/5] sm:aspect-square md:aspect-auto md:h-full min-w-0">
              <AnimatePresence mode="wait">
                <motion.div
                  key={currentImageIndex}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.2 }}
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
                      sizes="(max-width: 768px) 100vw, 55vw"
                      className="object-cover"
                      onError={() => setImageError(true)}
                    />
                  )}
                </motion.div>
              </AnimatePresence>
            </div>

            {/* Thumbnails strip */}
            {product.images.length > 1 && (
              <div className="absolute bottom-4 left-4 right-4 flex gap-2 overflow-x-auto no-scrollbar">
                {product.images.map((img, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentImageIndex(index)}
                    className={`relative w-12 h-12 sm:w-14 sm:h-14 rounded-lg overflow-hidden shrink-0 border-2 transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ${
                      index === currentImageIndex
                        ? "border-white shadow-lg ring-1 ring-black/10 scale-105"
                        : "border-white/60 opacity-60 hover:opacity-100"
                    }`}
                    aria-label={`View image ${index + 1}`}
                  >
                    <Image src={img || "/placeholder.svg"} alt="" fill className="object-cover" />
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* ── Details Column ── */}
          <div className="flex flex-col flex-1 min-w-0 md:w-[45%]">
            <div className="flex-1 overflow-y-auto p-6 sm:p-8 md:p-8 pb-4 space-y-5 sm:space-y-6">
              {/* Seller */}
              <Link
                href={`/seller/${product.sellerId}`}
                className="inline-flex items-center gap-1.5 text-xs sm:text-sm font-semibold text-primary uppercase tracking-wider hover:underline"
              >
                <Icon name="store" size="sm" />
                {product.sellerName}
              </Link>

              {/* Name */}
              <h2 className="text-2xl sm:text-3xl font-semibold leading-tight text-balance">{product.name}</h2>

              {/* Rating row */}
              <div className="flex items-center gap-2 text-sm sm:text-base">
                <div className="flex items-center gap-0.5">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <Icon
                      key={star}
                      name="star"
                      className={
                        star <= Math.round(product.rating || 0)
                          ? "text-amber-500 fill-amber-500 w-4 h-4 sm:w-5 sm:h-5"
                          : "text-muted-foreground w-4 h-4 sm:w-5 sm:h-5"
                      }
                    />
                  ))}
                </div>
                <span className="font-semibold text-foreground">{product.rating}</span>
                <span className="text-muted-foreground">({product.reviewCount} reviews)</span>
              </div>

              {/* Price */}
              <div className="flex items-baseline gap-3 flex-wrap">
                <span className="text-3xl sm:text-4xl font-bold text-primary">
                  {formatPrice(currentPrice)}
                </span>
                {product.salePrice && (
                  <span className="text-lg text-muted-foreground line-through">
                    {formatPrice(product.price)}
                  </span>
                )}
                {product.salePrice && (
                  <Badge variant="destructive" className="rounded-full text-sm px-3 py-1">
                    -{Math.round((1 - product.salePrice / product.price) * 100)}%
                  </Badge>
                )}
              </div>

              {/* Description */}
              {product.description && (
                <div
                  className="text-sm sm:text-base text-muted-foreground leading-relaxed line-clamp-3 md:line-clamp-4 prose prose-sm sm:prose-base max-w-none"
                  dangerouslySetInnerHTML={{ __html: product.description }}
                />
              )}

              {/* Divider */}
              <hr className="border-muted" />

              {/* Variant Picker */}
              <VariantPicker
                variations={product.variations}
                selected={selectedVariation}
                onSelect={setSelectedVariation}
              />

              {/* Quantity */}
              <div>
                <label className="text-sm sm:text-base font-medium mb-3 block">Quantity</label>
                <div className="flex items-center gap-4">
                  <button
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="w-12 h-12 rounded-lg border flex items-center justify-center hover:bg-muted transition-colors active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label="Decrease quantity"
                  >
                    <Icon name="minus" />
                  </button>
                  <span className="w-14 text-center font-semibold text-xl">{quantity}</span>
                  <button
                    onClick={() => setQuantity(quantity + 1)}
                    className="w-12 h-12 rounded-lg border flex items-center justify-center hover:bg-muted transition-colors active:scale-95 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label="Increase quantity"
                  >
                    <Icon name="plus" />
                  </button>
                </div>
              </div>
            </div>

            {/* ── Sticky Actions ── */}
            <div className="p-6 sm:p-8 pt-4 sm:pt-5 border-t bg-background space-y-3">
              <div className="flex gap-3">
                <Button variant="outline" size="lg" className="flex-1 h-12 sm:h-12 text-sm sm:text-base" onClick={handleAddToCart}>
                  <Icon name="shopping-cart" className="mr-2" />
                  Add to Cart
                </Button>
                <Button size="lg" className="flex-1 h-12 sm:h-12 text-sm sm:text-base" onClick={handleAddToCart}>
                  Buy Now
                </Button>
              </div>
              <Link
                href={`/product/${product.slug}`}
                className="block text-center text-sm text-muted-foreground hover:text-primary hover:underline font-medium"
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
