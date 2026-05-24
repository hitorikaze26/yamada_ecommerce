"use client"

import { useState } from "react"
import Image from "next/image"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { motion } from "framer-motion"
import type { Product } from "@/lib/types"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { ProductModal } from "@/components/product/product-modal"
import { useAuth } from "@/context/auth-context"
import { useWishlist } from "@/context/wishlist-context"
import { useToast } from "@/hooks/use-toast"

interface ProductCardProps {
  product: Product
  onQuickView?: (product: Product) => void
}

export function ProductCard({ product, onQuickView }: ProductCardProps) {
  const router = useRouter()
  const { isAuthenticated, getRole } = useAuth()
  const { isWishlisted, toggleWishlist } = useWishlist()
  const { toast } = useToast()
  const [isHovered, setIsHovered] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [imageError, setImageError] = useState(false)
  const [wishlistBusy, setWishlistBusy] = useState(false)

  const liked = isWishlisted(product.id)

  const handleWishlistClick = async (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (!isAuthenticated || getRole() !== "buyer") {
      router.push("/auth/login?role=buyer")
      return
    }
    if (wishlistBusy) return
    setWishlistBusy(true)
    try {
      const added = await toggleWishlist(product)
      toast({ title: added ? "Added to wishlist" : "Removed from wishlist" })
    } catch {
      toast({ title: "Could not update wishlist", variant: "destructive" })
    } finally {
      setWishlistBusy(false)
    }
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
      minimumFractionDigits: 0,
    }).format(price)
  }

  const discount = product.salePrice ? Math.round((1 - product.salePrice / product.price) * 100) : 0

  const plainDescription = product.description
    ? product.description.replace(/<[^>]+>/g, "").trim().slice(0, 60)
    : ""

  const hasValidImage = product.images[0] && !imageError

  return (
    <>
      <motion.div
        className="group relative bg-card rounded-2xl border overflow-hidden h-full flex flex-col"
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        whileHover={{ y: -6 }}
        transition={{ duration: 0.25, ease: "easeOut" }}
      >
        {/* Image Container */}
        <div className="relative aspect-[4/3] overflow-hidden bg-muted">
          <Link href={`/product/${product.slug}`} className="relative block w-full h-full">
            {hasValidImage ? (
              <Image
                src={product.images[0]}
                alt={product.name}
                fill
                className="object-cover transition-transform duration-500 group-hover:scale-110"
                onError={() => setImageError(true)}
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center bg-muted">
                <Icon name="image" className="text-muted-foreground/50" size="xl" />
              </div>
            )}
          </Link>

          {/* Sale Badge */}
          {discount > 0 && (
            <span className="absolute top-2 left-2 bg-destructive text-destructive-foreground text-[10px] md:text-xs font-bold px-2 py-1 rounded-full shadow-sm">
              -{discount}%
            </span>
          )}

          {/* Favorite Button */}
          <button
            type="button"
            disabled={wishlistBusy}
            onClick={(e) => void handleWishlistClick(e)}
            className="absolute top-2 right-2 w-7 h-7 md:w-8 md:h-8 rounded-full bg-background/90 backdrop-blur-sm flex items-center justify-center hover:bg-background hover:scale-110 transition-all shadow-sm disabled:opacity-60"
            aria-label={liked ? "Remove from wishlist" : "Add to wishlist"}
          >
            <Icon
              name="heart"
              size="sm"
              className={liked ? "text-destructive fill-destructive" : "text-muted-foreground"}
            />
          </button>

          {/* Quick View Overlay */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: isHovered ? 1 : 0, y: isHovered ? 0 : 10 }}
            transition={{ duration: 0.2 }}
            className="absolute inset-x-0 bottom-0 p-2 md:p-3 bg-gradient-to-t from-black/60 to-transparent"
          >
            <Button
              variant="secondary"
              size="sm"
              className="w-full text-xs md:text-sm bg-white/95 hover:bg-white text-foreground"
              onClick={(e) => {
                e.preventDefault()
                setShowModal(true)
              }}
            >
              <Icon name="eye" className="mr-1 md:mr-2" size="sm" />
              Quick View
            </Button>
          </motion.div>
        </div>

        {/* Content */}
        <div className="p-3 md:p-4 flex flex-col flex-1">
          {/* Seller */}
          {product.sellerId ? (
            <Link
              href={`/store/${product.sellerId}`}
              className="text-[10px] md:text-xs text-muted-foreground mb-1 truncate block hover:text-primary"
              onClick={(e) => e.stopPropagation()}
            >
              {product.sellerName || "View boutique"}
            </Link>
          ) : (
            <p className="text-[10px] md:text-xs text-muted-foreground mb-1 truncate">
              {product.sellerName || "Yamada Store"}
            </p>
          )}

          {/* Product Name */}
          <Link href={`/product/${product.slug}`}>
            <h3 className="font-medium text-xs md:text-sm mb-1 line-clamp-2 group-hover:text-primary transition-colors leading-tight">
              {product.name}
            </h3>
          </Link>

          {/* Category/Subcategory Tag */}
          {product.subcategory && (
            <span className="text-[10px] text-primary bg-primary/10 px-1.5 py-0.5 rounded inline-block w-fit mb-2">
              {product.subcategory}
            </span>
          )}

          {/* Rating */}
          <div className="flex items-center gap-1 mb-2">
            <Icon name="star" size="sm" className="text-yellow-500 fill-yellow-500 w-3 h-3" />
            <span className="text-[10px] md:text-xs font-medium">{product.rating || "0.0"}</span>
            <span className="text-[10px] text-muted-foreground">({product.reviewCount || 0})</span>
          </div>

          {/* Price */}
          <div className="flex items-center gap-1.5 md:gap-2 mt-auto">
            {product.salePrice ? (
              <>
                <span className="font-bold text-sm md:text-base text-primary">
                  {formatPrice(product.salePrice)}
                </span>
                <span className="text-[10px] md:text-xs text-muted-foreground line-through">
                  {formatPrice(product.price)}
                </span>
              </>
            ) : (
              <span className="font-bold text-sm md:text-base">{formatPrice(product.price)}</span>
            )}
          </div>
        </div>
      </motion.div>

      {/* Product Modal */}
      <ProductModal product={product} open={showModal} onClose={() => setShowModal(false)} />
    </>
  )
}
