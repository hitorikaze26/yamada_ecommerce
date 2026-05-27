"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { buyerApi } from "@/lib/api"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"
import { Icon } from "@/components/ui/icon"
import { ReviewDisplayCard } from "@/components/reviews/review-display-card"
import { normalizeReviewList } from "@/lib/normalizers"
import type { SerializedReview } from "@/lib/review-types"

export default function BuyerReviewsPage() {
  const [reviews, setReviews] = useState<SerializedReview[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getReviews({ page: 1, perPage: 50 })
        const rows = normalizeReviewList(unwrapBuyerList<Record<string, unknown>>(res.data, ["reviews"]))
        setReviews(rows)
        setTotal(Number(res.data.total ?? rows.length))
      } catch (err) {
        console.error(err)
        setError(getBuyerFetchError(err, "Failed to load reviews."))
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
