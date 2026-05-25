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
      <DialogContent className="w-[96vw] max-w-7xl max-h-[90vh] p-0 overflow-hidden">
        <DialogTitle className="sr-only">{product.name}</DialogTitle>
        <div className="grid md:grid-cols-2 md:h-[80vh]">
          {/* Image Section */}
          <div className="relative bg-muted md:h-full">
            <div className="relative aspect-square md:aspect-auto md:h-full">
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

            {/* Thumbnail navigation */}
            {product.images.length > 1 && (
              <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-2">
                {product.images.map((_, index) => (
                  <button
                    key={index}
                    onClick={() => setCurrentImageIndex(index)}
                    className={`w-2 h-2 rounded-full transition-all ${
                      index === currentImageIndex ? "bg-primary w-6" : "bg-foreground/30"
                    }`}
                    aria-label={`View image ${index + 1}`}
                  />
                ))}
              </div>
            )}
          </div>

          {/* Content Section */}
          <div className="p-6 flex flex-col overflow-y-auto overflow-x-hidden">
            <div className="flex-1">
              <Link href={`/seller/${product.sellerId}`} className="text-sm text-primary hover:underline">
                {product.sellerName}
              </Link>

              <h2 className="text-2xl font-bold mt-1 mb-2">{product.name}</h2>

              <div className="flex items-center gap-2 mb-4">
                <div className="flex items-center gap-1">
                  <Icon name="star" className="text-yellow-500" />
                  <span className="font-medium">{product.rating}</span>
                </div>
                <span className="text-muted-foreground">({product.reviewCount} reviews)</span>
              </div>

              <div className="flex items-baseline gap-3 mb-6">
                <span className="text-3xl font-bold text-primary">{formatPrice(currentPrice)}</span>
                {product.salePrice && (
                  <span className="text-lg text-muted-foreground line-through">{formatPrice(product.price)}</span>
                )}
              </div>

              <div
                className="text-muted-foreground mb-6 line-clamp-3 prose prose-sm max-w-none"
                dangerouslySetInnerHTML={{ __html: product.description || "" }}
              />

              {/* Variant Picker */}
              <VariantPicker
                variations={product.variations}
                selected={selectedVariation}
                onSelect={setSelectedVariation}
              />

              {/* Quantity */}
              <div className="mt-6">
                <label className="text-sm font-medium mb-2 block">Quantity</label>
                <div className="flex items-center gap-3">
                  <button
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="w-10 h-10 rounded-full border flex items-center justify-center hover:bg-muted transition-colors"
                    aria-label="Decrease quantity"
                  >
                    <Icon name="minus" />
                  </button>
                  <span className="w-12 text-center font-medium">{quantity}</span>
                  <button
                    onClick={() => setQuantity(quantity + 1)}
                    className="w-10 h-10 rounded-full border flex items-center justify-center hover:bg-muted transition-colors"
                    aria-label="Increase quantity"
                  >
                    <Icon name="plus" />
                  </button>
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3 mt-6">
              <Button variant="outline" className="flex-1 bg-transparent" onClick={handleAddToCart}>
                <Icon name="shopping-cart" className="mr-2" />
                Add to Cart
              </Button>
              <Button className="flex-1" onClick={handleAddToCart}>
                Buy Now
              </Button>
            </div>

            <Link
              href={`/product/${product.slug}`}
              className="text-center text-sm text-primary hover:underline mt-4"
              onClick={onClose}
            >
              View Full Details
            </Link>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
