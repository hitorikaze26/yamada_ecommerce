"use client"

import { useState, use, useEffect, useRef } from "react"
import Image from "next/image"
import Link from "next/link"
import { motion, AnimatePresence } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { VariantPicker } from "@/components/product/variant-picker"
import { ProductCard } from "@/components/product/product-card"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useCart } from "@/context/cart-context"
import { useToast } from "@/hooks/use-toast"
import { productsApi, buyerApi, API_BASE_ORIGIN, resolveImageUrl } from "@/lib/api"
import { useAuth } from "@/context/auth-context"
import { useWishlist } from "@/context/wishlist-context"
import { usePathname, useRouter } from "next/navigation"
import { useChatOpen } from "@/hooks/use-chat-open"
import { setBuyNowCheckout } from "@/lib/buy-now"
import { fetchSellerStoreGate } from "@/lib/seller-store-guard"
import { EditProductDialog } from "@/components/seller/edit-product-dialog"
import type { Product, ProductVariation, SizeChartMatrix, LegacySizeChart } from "@/lib/types"
import { CATEGORY_NAME_TO_ID } from "@/lib/types"
import { ReviewDisplayCard } from "@/components/reviews/review-display-card"
import type { SerializedReview } from "@/lib/review-types"

const extractProductIdFromSlug = (slug: string): string => {
  if (!slug) return ""
  const [idPart] = slug.split("-")
  return idPart || slug
}

const slugify = (value: string): string => {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
}

interface ProductMediaItem {
  id: number
  media_type: string
  path: string
  created_at?: string | null
}

interface SimilarProductItem {
  id: string
  slug: string
  name: string
  price: number
  image_url?: string | null
  rating?: number
  review_count?: number
}

const isSizeChartMatrix = (chart: Product["sizeChart"]): chart is SizeChartMatrix => {
  return Boolean(chart && typeof chart === "object" && "categoryKey" in chart && Array.isArray((chart as any).sizes))
}

const normalizeMediaPath = (path: string | undefined | null): string | undefined => {
  if (!path) return undefined
  if (path.startsWith("http")) return path

  const normalized = path.replace(/\\/g, "/")
  const trimmed = normalized.replace(/^\/+/, "")

  if (trimmed.startsWith("static/")) {
    return resolveImageUrl(`/${trimmed}`) ?? undefined
  }
  return resolveImageUrl(`/static/${trimmed}`) ?? undefined
}

function ProductMessageStoreButton({ storeId }: { storeId: number }) {
  const pathname = usePathname()
  const { isBusy, openBuyerStore } = useChatOpen()
  const busyKey = `product-store-${storeId}`

  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      disabled={!Number.isFinite(storeId) || isBusy(busyKey)}
      onClick={() => void openBuyerStore(busyKey, storeId, pathname || `/store/${storeId}`)}
    >
      {isBusy(busyKey) ? (
        <>
          <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin mr-1" />
          Opening…
        </>
      ) : (
        <>
          <Icon name="envelope" className="mr-1" />
          Message
        </>
      )}
    </Button>
  )
}

export default function ProductPage(props: { params: Promise<{ slug: string }> }) {
  const params = use(props.params)
  const productSlug = params.slug
  const productId = extractProductIdFromSlug(productSlug)
  const [product, setProduct] = useState<Product | null>(null)
  const [media, setMedia] = useState<ProductMediaItem[]>([])
  const [similarProducts, setSimilarProducts] = useState<SimilarProductItem[]>([])
  const [reviews, setReviews] = useState<SerializedReview[]>([])
  const [isLoadingReviews, setIsLoadingReviews] = useState(false)
  const [selectedVariation, setSelectedVariation] = useState<ProductVariation | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [currentImageIndex, setCurrentImageIndex] = useState(0)
  const { addToCart } = useCart()
  const { toast } = useToast()
  const router = useRouter()
  const { isAuthenticated, getRole } = useAuth()
  const { isWishlisted, toggleWishlist } = useWishlist()
  const [wishlistBusy, setWishlistBusy] = useState(false)
  const [isFollowingStore, setIsFollowingStore] = useState(false)
  const [followLoading, setFollowLoading] = useState(false)
  const [activeTab, setActiveTab] = useState("description")
  const [showFullDetails, setShowFullDetails] = useState(false)
  const tabsRef = useRef<HTMLDivElement | null>(null)
  const [isCarouselPaused, setIsCarouselPaused] = useState(false)
  const [myStoreId, setMyStoreId] = useState<number | null>(null)
  const [editDialogOpen, setEditDialogOpen] = useState(false)

  const isOwnProduct =
    myStoreId != null &&
    product != null &&
    String(product.sellerId) === String(myStoreId)

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const response = await productsApi.getById(String(productId))
        const apiProduct = response.data.product

        if (!apiProduct) return

        const mediaItems: ProductMediaItem[] = apiProduct.media || []
        setMedia(mediaItems)

        const apiCategories: string[] = Array.isArray(apiProduct.categories) ? apiProduct.categories : []

        let parsedTags: string[] | undefined
        if (apiProduct.tags_json) {
          try {
            const raw = typeof apiProduct.tags_json === "string" ? JSON.parse(apiProduct.tags_json) : apiProduct.tags_json
            if (Array.isArray(raw)) {
              parsedTags = raw.map((t: any) => String(t)).filter(Boolean)
            } else if (typeof raw === "string") {
              parsedTags = raw
                .split(",")
                .map((t) => t.trim())
                .filter(Boolean)
            }
          } catch {
            parsedTags = undefined
          }
        }

        let parsedSizeChart: Product["sizeChart"] | undefined
        const rawSizeChart = (apiProduct.size_chart as any) ?? (apiProduct.size_chart_json as any)
        if (rawSizeChart) {
          try {
            const obj = typeof rawSizeChart === "string" ? JSON.parse(rawSizeChart) : rawSizeChart

            if (obj && typeof obj === "object" && "categoryKey" in obj && Array.isArray((obj as any).sizes)) {
              parsedSizeChart = obj as SizeChartMatrix
            } else {
              const legacy: LegacySizeChart = {
                bust: obj.bust ?? undefined,
                waist: obj.waist ?? undefined,
                hips: obj.hips ?? undefined,
                length: obj.length ?? undefined,
                otherNotes: obj.other_notes ?? undefined,
              }
              parsedSizeChart = legacy
            }
          } catch {
            parsedSizeChart = undefined
          }
        }

        // Normalize main image URL (from image_url) and additional media images
        let imageUrl: string | undefined = apiProduct.image_url || apiProduct.imageUrl

        if (!imageUrl && Array.isArray(apiProduct.media)) {
          const firstImage = apiProduct.media.find((m: any) => m && m.media_type === "image" && m.path) ??
            apiProduct.media[0]
          if (firstImage?.path) {
            imageUrl = firstImage.path
          }
        }

        imageUrl = normalizeMediaPath(imageUrl)

        const extraImages = mediaItems
          .filter((m) => m.media_type === "image" && m.path)
          .map((m) => normalizeMediaPath(m.path))

        const allImages = Array.from(new Set([imageUrl, ...extraImages].filter(Boolean))) as string[]

        const normalized: Product = {
          id: String(apiProduct.id ?? productId),
          slug: productSlug,
          name: apiProduct.name ?? "",
          category: apiCategories[0] ?? "",
          subcategory: apiProduct.subcategory ?? undefined,
          categories: apiCategories,
          description: apiProduct.description ?? "",
          images: allImages,
          variations:
            Array.isArray(apiProduct.variations)
              ? apiProduct.variations.map((v: any) => ({
                  id: String(v.id),
                  size: v.size ?? "",
                  color: v.color ?? "",
                  sku: v.sku ?? "",
                  inventory: typeof v.inventory === "number" ? v.inventory : 0,
                  price: typeof v.price === "number" ? v.price : undefined,
                }))
              : [],
          price: typeof apiProduct.price === "number" ? apiProduct.price : 0,
          salePrice: typeof apiProduct.sale_price === "number" ? apiProduct.sale_price : undefined,
          brand: apiProduct.brand ?? undefined,
          productCondition: apiProduct.product_condition ?? undefined,
          weightKg: typeof apiProduct.weight_kg === "number" ? apiProduct.weight_kg : undefined,
          material: apiProduct.material ?? undefined,
          careInstructions: apiProduct.care_instructions ?? undefined,
          tags: parsedTags,
          sizeChart: parsedSizeChart,
          rating: typeof apiProduct.rating === "number" ? apiProduct.rating : 0,
          reviewCount: typeof apiProduct.review_count === "number" ? apiProduct.review_count : 0,
          sellerId: apiProduct.store_id ? String(apiProduct.store_id) : "",
          sellerName: apiProduct.seller_name ?? "",
          sellerLogo: apiProduct.seller_logo ?? undefined,
          visibility: true,
          createdAt: apiProduct.created_at ?? new Date().toISOString(),
          updatedAt: apiProduct.updated_at ?? apiProduct.created_at ?? new Date().toISOString(),
        }

        setProduct(normalized)
      } catch (error) {
        console.error("Failed to load product from API", error)
      }
    }

    fetchProduct()
  }, [productId])

  useEffect(() => {
    if (!isAuthenticated || getRole() !== "seller") {
      setMyStoreId(null)
      return
    }
    void fetchSellerStoreGate().then((g) => setMyStoreId(g.storeId))
  }, [isAuthenticated, getRole])

  useEffect(() => {
    if (!product?.id || !isAuthenticated || getRole() !== "buyer") return
    const pid = Number(product.id)
    if (!Number.isFinite(pid)) return
    void buyerApi.recordRecentlyViewed(pid).catch(() => {})
  }, [product?.id, isAuthenticated, getRole])

  useEffect(() => {
    if (!product?.sellerId || !isAuthenticated || getRole() !== "buyer") return
    const storeId = Number(product.sellerId)
    if (!Number.isFinite(storeId)) return
    void buyerApi
      .getFollowingStatus(storeId)
      .then((res) => setIsFollowingStore(Boolean(res.data?.following)))
      .catch(() => setIsFollowingStore(false))
  }, [product?.sellerId, isAuthenticated, getRole])

  const handleToggleFollowStore = async () => {
    if (!product?.sellerId || getRole() !== "buyer") {
      toast({ title: "Sign in as a buyer to follow stores", variant: "destructive" })
      return
    }
    const storeId = Number(product.sellerId)
    if (!Number.isFinite(storeId)) return
    setFollowLoading(true)
    try {
      if (isFollowingStore) {
        await buyerApi.unfollowStore(storeId)
        setIsFollowingStore(false)
        toast({ title: "Unfollowed store" })
      } else {
        await buyerApi.followStore(storeId)
        setIsFollowingStore(true)
        toast({ title: "Following store" })
      }
    } catch {
      toast({ title: "Could not update follow status", variant: "destructive" })
    } finally {
      setFollowLoading(false)
    }
  }

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  const handleAddToCart = () => {
    if (!product) return

    if (!selectedVariation) {
      toast({
        title: "Please select a variant",
        description: "Choose a size and color before adding to cart.",
        variant: "destructive",
      })
      return
    }

    if (selectedVariation.inventory <= 0) {
      toast({
        title: "Out of stock",
        description: "This variant is currently unavailable.",
        variant: "destructive",
      })
      return
    }

    if (quantity > selectedVariation.inventory) {
      toast({
        title: "Not enough stock",
        description: `Only ${selectedVariation.inventory} item(s) available for this variant.`,
        variant: "destructive",
      })
      return
    }

    addToCart(product, quantity, selectedVariation)
    toast({
      title: "Added to cart",
      description: `${product.name} has been added to your cart.`,
    })
  }

  const handleBuyNow = () => {
    if (!product) return

    if (!selectedVariation) {
      toast({
        title: "Please select a variant",
        description: "Choose a size and color before proceeding.",
        variant: "destructive",
      })
      return
    }

    setBuyNowCheckout({ product, quantity, selectedVariation })
    window.location.href = "/checkout?buyNow=1"
  }

  const handleViewSizeChartFromVariants = () => {
    if (!product?.sizeChart) return
    setActiveTab("size_chart")
    if (tabsRef.current) {
      tabsRef.current.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  useEffect(() => {
    const loadReviews = async () => {
      try {
        const reviewsRes = await productsApi.getReviews(productId)
        const reviewsData = (reviewsRes.data as any)?.reviews ?? []

        setReviews(reviewsData as SerializedReview[])
      } catch (error) {
        console.error("Failed to load product reviews", error)
        setReviews([])
      } finally {
        setIsLoadingReviews(false)
      }
    }

    void loadReviews()
  }, [productId])

  useEffect(() => {
    // Reset or clamp quantity when the selected variation changes
    if (selectedVariation) {
      const maxQty = Math.max(1, selectedVariation.inventory || 0)
      // When the user selects a different variant (e.g., color/size),
      // reset the main product image back to the first image to reflect the change.
      setCurrentImageIndex(0)
      setQuantity((prev) => {
        if (prev <= 0) return 1
        if (prev > maxQty) return maxQty
        return prev
      })
    } else {
      setQuantity(1)
    }
  }, [selectedVariation])

  useEffect(() => {
    const fetchSimilar = async () => {
      if (!product?.sellerId) return

      try {
        const response = await productsApi.getAll({ seller: product.sellerId, exclude: product.id })
        const items: SimilarProductItem[] = (response.data.products || []).map((p: any) => {
          const numericId = String(p.id)
          const nameForSlug = p.name ?? numericId
          const slug = `${numericId}-${slugify(nameForSlug)}`

          return {
            id: numericId,
            slug,
            name: p.name,
            price: p.price,
            image_url: p.image_url,
            rating: p.rating,
            review_count: p.review_count,
          }
        })
        setSimilarProducts(items)
      } catch (error) {
        console.error("Failed to load similar products", error)
      }
    }

    fetchSimilar()
  }, [product?.sellerId, product?.id])

  useEffect(() => {
    if (!product?.images || product.images.length <= 1 || isCarouselPaused) return

    const interval = setInterval(() => {
      setCurrentImageIndex((prev) => {
        const nextIndex = (prev + 1) % product.images.length
        return nextIndex
      })
    }, 3000)

    return () => clearInterval(interval)
  }, [product?.images, isCarouselPaused])

  if (!product) {
    return (
      <div className="min-h-screen flex flex-col">
        <Navbar />
        <main className="flex-1 flex items-center justify-center">
          <p className="text-muted-foreground">Loading product...</p>
        </main>
        <Footer />
      </div>
    )
  }

  const currentPrice = selectedVariation?.price ?? product.salePrice ?? product.price
  const discount = product.salePrice ? Math.round((1 - product.salePrice / product.price) * 100) : 0

  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-5 md:px-8 lg:px-40 py-8">
          {/* Breadcrumb */}
          <nav className="flex items-center gap-2 text-sm text-muted-foreground mb-6">
            <Link href="/" className="hover:text-foreground">
              Home
            </Link>
            <Icon name="angle-right" size="sm" />
            <Link href="/search" className="hover:text-foreground">
              Products
            </Link>
            <Icon name="angle-right" size="sm" />
            <span className="text-foreground truncate">{product.name}</span>
          </nav>

          <div className="grid lg:grid-cols-2 gap-8 lg:gap-12">
            {/* Image Gallery */}
            <div className="space-y-4">
              <div
                className="relative aspect-square rounded-2xl overflow-hidden bg-muted"
                onMouseEnter={() => setIsCarouselPaused(true)}
                onMouseLeave={() => setIsCarouselPaused(false)}
              >
                <AnimatePresence mode="wait">
                  <motion.div
                    key={currentImageIndex}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="absolute inset-0"
                  >
                    <Image
                      src={product.images[currentImageIndex] || "/placeholder.svg"}
                      alt={product.name}
                      fill
                      className="object-cover"
                      priority
                    />
                  </motion.div>
                </AnimatePresence>

                {discount > 0 && (
                  <span className="absolute top-4 left-4 bg-destructive text-destructive-foreground text-sm font-medium px-3 py-1 rounded-full">
                    -{discount}%
                  </span>
                )}

                <button
                  type="button"
                  disabled={wishlistBusy || !product}
                  onClick={() => {
                    if (!product) return
                    if (!isAuthenticated || getRole() !== "buyer") {
                      router.push("/login?role=buyer")
                      return
                    }
                    setWishlistBusy(true)
                    void toggleWishlist(product)
                      .then((added) => {
                        toast({
                          title: added ? "Added to wishlist" : "Removed from wishlist",
                        })
                      })
                      .catch(() => {
                        toast({ title: "Could not update wishlist", variant: "destructive" })
                      })
                      .finally(() => setWishlistBusy(false))
                  }}
                  className="absolute top-4 right-4 w-10 h-10 rounded-full bg-background/80 backdrop-blur-sm flex items-center justify-center hover:bg-background transition-colors disabled:opacity-60"
                  aria-label={
                    product && isWishlisted(product.id) ? "Remove from wishlist" : "Add to wishlist"
                  }
                >
                  <Icon
                    name="heart"
                    className={
                      product && isWishlisted(product.id)
                        ? "text-destructive fill-destructive"
                        : ""
                    }
                  />
                </button>
              </div>

              {/* Thumbnails */}
              {product.images.length > 1 && (
                <div className="flex gap-3 overflow-x-auto pb-2">
                  {product.images.map((image, index) => (
                    <button
                      key={index}
                      onClick={() => setCurrentImageIndex(index)}
                      className={`relative w-20 h-20 rounded-xl overflow-hidden flex-shrink-0 border-2 transition-all ${
                        index === currentImageIndex ? "border-primary" : "border-transparent hover:border-primary/50"
                      }`}
                    >
                      <Image
                        src={image || "/placeholder.svg"}
                        alt={`${product.name} ${index + 1}`}
                        fill
                        className="object-cover"
                      />
                    </button>
                  ))}
                </div>
              )}

              {/* Product Videos */}
              {media.filter((m) => m.media_type === "video").length > 0 && (
                <div className="mt-4 space-y-2">
                  <p className="text-sm font-medium">Product Videos</p>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {media
                      .filter((m) => m.media_type === "video")
                      .map((m) => (
                        <video
                          key={m.id}
                          src={normalizeMediaPath(m.path) ?? ""}
                          controls
                          className="w-full max-h-64 rounded-xl border bg-black object-contain"
                        />
                      ))}
                  </div>
                </div>
              )}
            </div>

            {/* Product Info */}
            <div className="space-y-6">
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  {product.sellerId ? (
                    <Link
                      href={`/store/${encodeURIComponent(product.sellerId)}`}
                      className="text-primary hover:underline text-sm font-medium"
                    >
                      {product.sellerName || "View store"}
                    </Link>
                  ) : (
                    <span className="text-sm text-muted-foreground">{product.sellerName}</span>
                  )}
                  {product.sellerId && getRole() === "buyer" && (
                    <>
                      <Button
                        type="button"
                        variant={isFollowingStore ? "secondary" : "outline"}
                        size="sm"
                        disabled={followLoading}
                        onClick={() => void handleToggleFollowStore()}
                      >
                        <Icon name={isFollowingStore ? "check" : "plus"} className="mr-1" />
                        {isFollowingStore ? "Following" : "Follow store"}
                      </Button>
                      <ProductMessageStoreButton storeId={Number(product.sellerId)} />
                    </>
                  )}
                </div>
                <h1 className="text-2xl font-bold mt-1 md:text-3xl">{product.name}</h1>

                {product.subcategory && (
                  <p className="mt-1 text-xs font-medium text-muted-foreground uppercase tracking-wide">
                    {product.subcategory}
                  </p>
                )}

                {product.categories && product.categories.length > 0 && (
                  <div className="flex flex-wrap gap-2 mt-2">
                    {product.categories.map((cat) => {
                      const categoryId = CATEGORY_NAME_TO_ID[cat]
                      if (!categoryId) {
                        return (
                          <span
                            key={cat}
                            className="inline-flex items-center rounded-full bg-muted px-3 py-1 text-xs font-medium text-muted-foreground"
                          >
                            {cat}
                          </span>
                        )
                      }

                      return (
                        <Link
                          key={cat}
                          href={`/search?category=${encodeURIComponent(categoryId)}`}
                          className="inline-flex items-center rounded-full bg-muted px-3 py-1 text-xs font-medium text-muted-foreground hover:bg-primary/10 hover:text-primary transition-colors"
                        >
                          {cat}
                        </Link>
                      )
                    })}
                  </div>
                )}

                <div className="flex items-center gap-4 mt-3">
                  <div className="flex items-center gap-1">
                    <Icon name="star" className="text-yellow-500" />
                    <span className="font-semibold">{product.rating}</span>
                  </div>
                  <span className="text-muted-foreground">{product.reviewCount} reviews</span>
                  <span className="text-muted-foreground">|</span>
                  <span className="text-muted-foreground">
                    {product.variations.reduce((sum, v) => sum + v.inventory, 0)} in stock
                  </span>
                </div>
              </div>

              <div className="flex items-baseline gap-3">
                <span className="text-3xl font-bold text-primary md:text-4xl">{formatPrice(currentPrice)}</span>
                {product.salePrice && (
                  <span className="text-lg text-muted-foreground line-through md:text-xl">
                    {formatPrice(product.price)}
                  </span>
                )}
              </div>

              {/* Variant Picker */}
              <div className="border-t border-b py-6">
                <VariantPicker
                  variations={product.variations}
                  selected={selectedVariation}
                  onSelect={setSelectedVariation}
                  onViewSizeChart={product.sizeChart ? handleViewSizeChartFromVariants : undefined}
                />
              </div>

              {/* Quantity */}
              <div>
                <label className="text-sm font-medium mb-3 block">Quantity</label>
                <div className="flex items-center gap-4">
                  <div className="flex items-center border rounded-xl">
                    <button
                      onClick={() => setQuantity(Math.max(1, quantity - 1))}
                      className="w-12 h-12 flex items-center justify-center hover:bg-muted transition-colors rounded-l-xl"
                      aria-label="Decrease quantity"
                    >
                      <Icon name="minus" />
                    </button>
                    <span className="w-16 text-center font-medium">{quantity}</span>
                    {(() => {
                      const maxQty = selectedVariation ? selectedVariation.inventory || 0 : 0
                      const isAtMax = maxQty > 0 && quantity >= maxQty
                      const isDisabled = selectedVariation ? maxQty <= 0 || isAtMax : false

                      return (
                        <button
                          type="button"
                          onClick={() => {
                            if (isDisabled) return
                            if (selectedVariation) {
                              const limit = selectedVariation.inventory || 0
                              if (limit <= 0) return
                              setQuantity((prev) => Math.min(limit, prev + 1))
                            } else {
                              setQuantity((prev) => prev + 1)
                            }
                          }}
                          disabled={isDisabled}
                          className={`w-12 h-12 flex items-center justify-center rounded-r-xl transition-colors ${
                            isDisabled
                              ? "cursor-not-allowed opacity-50 bg-muted"
                              : "hover:bg-muted"
                          }`}
                          aria-label="Increase quantity"
                        >
                          <Icon name="plus" />
                        </button>
                      )
                    })()}
                  </div>

                  {selectedVariation && (
                    <span className="text-sm text-muted-foreground">{selectedVariation.inventory} available</span>
                  )}
                </div>
              </div>

              {/* Actions */}
              {isOwnProduct ? (
                <div className="space-y-3">
                  <div className="rounded-xl border border-amber-200 bg-amber-50 dark:bg-amber-900/20 dark:border-amber-800 px-4 py-3 text-sm text-amber-900 dark:text-amber-100">
                    This is your product. You cannot purchase from your own store.
                  </div>
                  <Button size="lg" className="w-full" onClick={() => setEditDialogOpen(true)}>
                    <Icon name="edit" className="mr-2" />
                    Edit product
                  </Button>
                  <EditProductDialog
                    productId={product.id}
                    open={editDialogOpen}
                    onOpenChange={setEditDialogOpen}
                  />
                </div>
              ) : (
                <div className="flex gap-4">
                  <Button variant="outline" size="lg" className="flex-1 bg-transparent" onClick={handleAddToCart}>
                    <Icon name="shopping-cart" className="mr-2" />
                    Add to Cart
                  </Button>
                  <Button size="lg" className="flex-1" onClick={handleBuyNow}>
                    Buy Now
                  </Button>
                </div>
              )}

              {/* Delivery Info */}
              <div className="bg-muted/50 rounded-xl p-4 space-y-3">
                <div className="flex items-center gap-3">
                  <Icon name="truck-loading" className="text-primary" />
                  <div>
                    <p className="font-medium text-sm">Free Shipping</p>
                    <p className="text-xs text-muted-foreground">On orders over ₱2,000</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <Icon name="redo" className="text-primary" />
                  <div>
                    <p className="font-medium text-sm">Easy Returns</p>
                    <p className="text-xs text-muted-foreground">30-day return policy</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <Icon name="shield-check" className="text-primary" />
                  <div>
                    <p className="font-medium text-sm">Secure Payment</p>
                    <p className="text-xs text-muted-foreground">100% secure checkout</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Product Details Tabs */}
          <div className="mt-12" ref={tabsRef}>
            <Tabs value={activeTab} onValueChange={setActiveTab}>
              <TabsList className="w-full justify-start border-b rounded-none bg-transparent h-auto p-0">
                <TabsTrigger
                  value="description"
                  className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
                >
                  Description
                </TabsTrigger>
                <TabsTrigger
                  value="reviews"
                  className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
                >
                  Reviews ({product.reviewCount})
                </TabsTrigger>
                <TabsTrigger
                  value="shipping"
                  className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
                >
                  Shipping
                </TabsTrigger>
                {product.sizeChart && (
                  <TabsTrigger
                    value="size_chart"
                    className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
                  >
                    Size Chart
                  </TabsTrigger>
                )}
              </TabsList>

              <TabsContent value="description" className="mt-6">
                <div className="prose dark:prose-invert max-w-none space-y-4">
                  <div
                    className="text-muted-foreground"
                    dangerouslySetInnerHTML={{ __html: product.description || "" }}
                  />

                  <div>
                    <h3>Product Details</h3>
                    {(() => {
                      const details: { label: string; value: string }[] = []

                      if (product.brand) details.push({ label: "Brand", value: product.brand })
                      if (product.productCondition)
                        details.push({ label: "Condition", value: product.productCondition })
                      if (typeof product.weightKg === "number")
                        details.push({ label: "Weight", value: `${product.weightKg} kg` })
                      if (product.material) details.push({ label: "Material", value: product.material })
                      if (product.careInstructions)
                        details.push({ label: "Care instructions", value: product.careInstructions })
                      if (product.tags && product.tags.length > 0)
                        details.push({ label: "Tags", value: product.tags.join(", ") })

                      if (details.length === 0) return null

                      const visible = showFullDetails ? details : details.slice(0, 4)

                      return (
                        <>
                          <ul>
                            {visible.map((item, idx) => (
                              <li key={`${item.label}-${idx}`}>
                                <strong>{item.label}:</strong> {item.value}
                              </li>
                            ))}
                          </ul>
                          {details.length > 4 && (
                            <button
                              type="button"
                              onClick={() => setShowFullDetails((prev) => !prev)}
                              className="mt-2 text-xs font-medium text-primary hover:underline"
                            >
                              {showFullDetails ? "Show less" : "Show more"}
                            </button>
                          )}
                        </>
                      )
                    })()}
                  </div>
                </div>
              </TabsContent>

              {(() => {
                const sizeChart = product.sizeChart;
                if (!sizeChart) return null;
                return (
                <TabsContent value="size_chart" className="mt-6">
                  <div className="prose dark:prose-invert max-w-none">
                    <h3>Size Chart</h3>
                    {isSizeChartMatrix(sizeChart) ? (
                      <div className="mt-2 overflow-x-auto rounded-xl border bg-muted/30">
                        <table className="min-w-full text-xs">
                          <thead className="bg-muted/60">
                            <tr>
                              {sizeChart.categoryKey === "shoes" ? (
                                <>
                                  <th className="px-3 py-2 text-left font-medium">US</th>
                                  <th className="px-3 py-2 text-left font-medium">EU</th>
                                  <th className="px-3 py-2 text-left font-medium">Foot length (cm)</th>
                                  <th className="px-3 py-2 text-left font-medium">Foot length (inch)</th>
                                </>
                              ) : (
                                <>
                                  <th className="px-3 py-2 text-left font-medium">Size</th>
                                  <th className="px-3 py-2 text-left font-medium">Intl</th>
                                  <th className="px-3 py-2 text-left font-medium">Numeric</th>
                                  {sizeChart.measurements.map((m) => (
                                    <th key={`${m}-cm`} className="px-3 py-2 text-left font-medium">
                                      {String(m).replace("_", " ")} (cm)
                                    </th>
                                  ))}
                                  {sizeChart.measurements.map((m) => (
                                    <th key={`${m}-inch`} className="px-3 py-2 text-left font-medium">
                                      {String(m).replace("_", " ")} (inch)
                                    </th>
                                  ))}
                                </>
                              )}
                            </tr>
                          </thead>
                          <tbody>
                            {sizeChart.categoryKey === "shoes"
                              ? sizeChart.sizes.map((row, idx) => (
                                  <tr key={`${row.us}-${row.eu}-${idx}`} className="border-t">
                                    <td className="px-3 py-2">{row.us}</td>
                                    <td className="px-3 py-2">{row.eu}</td>
                                    <td className="px-3 py-2">{row.cm.foot_length}</td>
                                    <td className="px-3 py-2">{row.inch.foot_length}</td>
                                  </tr>
                                ))
                              : sizeChart.sizes.map((row, idx) => (
                                  <tr key={`${row.label}-${idx}`} className="border-t">
                                    <td className="px-3 py-2">{row.label}</td>
                                    <td className="px-3 py-2">{row.international}</td>
                                    <td className="px-3 py-2">{row.numeric}</td>
                                    {sizeChart.measurements.map((m) => (
                                      <td key={`${row.label}-${m}-cm`} className="px-3 py-2">
                                        {row.cm[m]}
                                      </td>
                                    ))}
                                    {sizeChart.measurements.map((m) => (
                                      <td key={`${row.label}-${m}-inch`} className="px-3 py-2">
                                        {row.inch[m]}
                                      </td>
                                    ))}
                                  </tr>
                                ))}
                          </tbody>
                        </table>
                      </div>
                    ) : (
                      <ul>
                        {sizeChart.bust && <li>Bust: {sizeChart.bust}</li>}
                        {sizeChart.waist && <li>Waist: {sizeChart.waist}</li>}
                        {sizeChart.hips && <li>Hips: {sizeChart.hips}</li>}
                        {sizeChart.length && <li>Length: {sizeChart.length}</li>}
                        {sizeChart.otherNotes && <li>Other: {sizeChart.otherNotes}</li>}
                      </ul>
                    )}
                  </div>
                </TabsContent>
                );
              })()}

              <TabsContent value="reviews" className="mt-6">
                {isLoadingReviews ? (
                  <div className="text-center py-8 text-muted-foreground">Loading reviews...</div>
                ) : reviews.length === 0 ? (
                  <div className="text-center py-8">
                    <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
                      <Icon name="star" size="xl" className="text-muted-foreground" />
                    </div>
                    <p className="text-muted-foreground text-sm">
                      No reviews yet. Reviews appear after buyers complete their orders.
                    </p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {reviews.map((r) => (
                      <ReviewDisplayCard key={r.id} review={r} />
                    ))}
                  </div>
                )}
              </TabsContent>

              <TabsContent value="shipping" className="mt-6">
                <div className="grid gap-6 md:grid-cols-2">
                  <div>
                    <h3 className="font-semibold mb-2">Shipping Information</h3>
                    <p className="text-muted-foreground">
                      We offer nationwide shipping across the Philippines. Standard delivery takes 3-5 business days.
                      Express delivery is available for select areas.
                    </p>
                  </div>
                  <div>
                    <h3 className="font-semibold mb-2">Return Policy</h3>
                    <p className="text-muted-foreground">
                      Items can be returned within 30 days of delivery. Items must be unworn, unwashed, and with
                      original tags attached.
                    </p>
                  </div>
                </div>
              </TabsContent>
            </Tabs>
          </div>

          {/* Related Products */}
          {similarProducts.length > 0 && (
            <div className="mt-16">
              <h2 className="text-2xl font-bold mb-6">You May Also Like</h2>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6">
                {similarProducts.map((sp) => {
                  const normalizedImageUrl = normalizeMediaPath(sp.image_url)
                  const tempProduct: Product = {
                    id: sp.id,
                    slug: sp.slug,
                    name: sp.name,
                    category: "",
                    subcategory: undefined,
                    categories: [],
                    description: "",
                    images: normalizedImageUrl ? [normalizedImageUrl] : [],
                    variations: [],
                    price: typeof sp.price === "number" ? sp.price : 0,
                    salePrice: undefined,
                    rating: typeof sp.rating === "number" ? sp.rating : 0,
                    reviewCount: typeof sp.review_count === "number" ? sp.review_count : 0,
                    sellerId: "",
                    sellerName: "",
                    sellerLogo: undefined,
                    visibility: true,
                    createdAt: new Date().toISOString(),
                    updatedAt: new Date().toISOString(),
                  }

                  return (
                    <div key={sp.id}>
                      <ProductCard product={tempProduct} />
                    </div>
                  )
                })}
              </div>
            </div>
          )}
        </div>
      </main>

      <Footer />
    </div>
  )
}
