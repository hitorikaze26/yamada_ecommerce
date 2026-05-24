"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { buyerApi, resolveImageUrl } from "@/lib/api"
import { Icon } from "@/components/ui/icon"
import { ReviewDisplayCard } from "@/components/reviews/review-display-card"
import type { SerializedReview } from "@/lib/review-types"

function mapReviewRow(raw: Record<string, unknown>): SerializedReview {
  const ratingsRaw = raw.ratings
  const ratings: Record<string, number> = {}
  if (ratingsRaw && typeof ratingsRaw === "object" && !Array.isArray(ratingsRaw)) {
    Object.entries(ratingsRaw as Record<string, unknown>).forEach(([k, v]) => {
      if (typeof v === "number") ratings[k] = v
    })
  }

  const pillsRaw = raw.deliveryPills
  const deliveryPills: string[] = Array.isArray(pillsRaw)
    ? pillsRaw.map((p) => String(p))
    : []

  return {
    id: Number(raw.id ?? 0),
    rating: Number(raw.rating ?? 0),
    reviewFormat: (raw.reviewFormat as SerializedReview["reviewFormat"]) ?? "default",
    ratings,
    comment: (raw.comment as string) ?? null,
    deliverySatisfaction:
      raw.deliverySatisfaction != null ? Number(raw.deliverySatisfaction) : null,
    deliveryPills,
    createdAt: (raw.createdAt as string) ?? null,
    productId: raw.productId != null ? Number(raw.productId) : null,
    productName: (raw.productName as string) ?? null,
    productImage: resolveImageUrl((raw.productImage as string) ?? null),
    buyerName: (raw.buyerName as string) ?? null,
    sellerReply: (raw.sellerReply as string) ?? null,
    sellerReplyAt: (raw.sellerReplyAt as string) ?? null,
    variant: (raw.variant as string) ?? null,
    unitPrice: raw.unitPrice != null ? Number(raw.unitPrice) : null,
    quantity: raw.quantity != null ? Number(raw.quantity) : null,
    orderItemId: raw.orderItemId != null ? Number(raw.orderItemId) : null,
    orderId: raw.orderId != null ? Number(raw.orderId) : null,
  }
}

export default function BuyerReviewsPage() {
  const [reviews, setReviews] = useState<SerializedReview[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getReviews({ page: 1, perPage: 50 })
        const rows = ((res.data.reviews as Record<string, unknown>[]) ?? []).map(mapReviewRow)
        setReviews(rows)
        setTotal(Number(res.data.total ?? rows.length))
      } catch (err) {
        console.error(err)
        setError("Failed to load reviews.")
      } finally {
        setLoading(false)
      }
    }
    void load()
  }, [])

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">My reviews</h1>
          <p className="text-muted-foreground">
            Reviews you submitted after receiving orders, including ratings and delivery feedback.
          </p>
        </div>
        {!loading && total > 0 && (
          <span className="text-sm text-muted-foreground bg-muted px-3 py-1 rounded-full">
            {total} review{total === 1 ? "" : "s"}
          </span>
        )}
      </div>

      {loading && (
        <div className="bg-card border rounded-2xl p-8 flex items-center justify-center gap-2 text-muted-foreground">
          <Icon name="spinner" className="animate-spin" />
          Loading reviews…
        </div>
      )}

      {error && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!loading && !error && reviews.length === 0 && (
        <div className="bg-card border rounded-2xl p-10 text-center">
          <Icon name="star" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h2 className="text-lg font-semibold mb-1">No reviews yet</h2>
          <p className="text-sm text-muted-foreground">
            Rate products from a completed order to see them here.
          </p>
        </div>
      )}

      <div className="space-y-4">
        {reviews.map((review) => (
          <div key={review.id} className="bg-card border rounded-2xl overflow-hidden">
            <div className="p-4 sm:p-5 flex flex-col sm:flex-row gap-4">
              {review.productImage && (
                <Link
                  href={
                    review.productId
                      ? `/product/${review.productId}`
                      : review.orderId
                        ? `/orders/${review.orderId}`
                        : "#"
                  }
                  className="w-full sm:w-24 h-24 rounded-xl border bg-muted overflow-hidden shrink-0 block"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={review.productImage}
                    alt={review.productName ?? "Product"}
                    className="w-full h-full object-cover"
                  />
                </Link>
              )}
              <div className="flex-1 min-w-0 space-y-3">
                <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                  {review.orderId && (
                    <Link
                      href={`/orders/${review.orderId}`}
                      className="inline-flex items-center gap-1 text-primary hover:underline font-medium"
                    >
                      <Icon name="box" size="sm" />
                      Order #{review.orderId}
                    </Link>
                  )}
                  {review.unitPrice != null && review.quantity != null && (
                    <span>
                      {review.quantity} ×{" "}
                      {new Intl.NumberFormat("en-PH", {
                        style: "currency",
                        currency: "PHP",
                      }).format(review.unitPrice)}
                    </span>
                  )}
                </div>
                <ReviewDisplayCard review={review} showSellerReply />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
