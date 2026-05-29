"use client"

import { Icon } from "@/components/ui/icon"
import {
  type SerializedReview,
  dimensionLabelsForFormat,
  type ReviewFormat,
} from "@/lib/review-types"

function Stars({ rating }: { rating: number }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((star) => (
        <Icon
          key={star}
          name="star"
          className={rating >= star ? "text-yellow-500" : "text-muted-foreground"}
        />
      ))}
    </div>
  )
}

export function ReviewDisplayCard({
  review,
  showSellerReply = true,
}: {
  review: SerializedReview
  showSellerReply?: boolean
}) {
  const format = (review.reviewFormat || "default") as ReviewFormat
  const labels = dimensionLabelsForFormat(format)
  const ratings = review.ratings ?? {}

  return (
    <div className="border rounded-xl p-4 space-y-3">
      <div className="flex items-start justify-between gap-2">
        <div>
          {review.buyerName && (
            <p className="text-sm font-medium">{review.buyerName}</p>
          )}
          {review.productName && (
            <p className="text-xs text-muted-foreground">{review.productName}</p>
          )}
          {review.variant && (
            <p className="text-xs text-muted-foreground">{review.variant}</p>
          )}
        </div>
        <div className="text-right shrink-0">
          <Stars rating={review.rating} />
          {review.createdAt && (
            <p className="text-xs text-muted-foreground mt-1">
              {new Date(review.createdAt).toLocaleDateString("en-PH", {
                month: "short",
                day: "numeric",
                year: "numeric",
              })}
            </p>
          )}
        </div>
      </div>

      {Object.keys(ratings).length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-4 gap-y-1 text-xs">
          {Object.entries(ratings).map(([key, val]) => (
            <div key={key} className="flex justify-between gap-2">
              <span className="text-muted-foreground">{labels[key] ?? key}</span>
              <span className="font-medium">{val}/5</span>
            </div>
          ))}
        </div>
      )}

      {review.comment && <p className="text-sm">{review.comment}</p>}

      {review.deliverySatisfaction != null && review.deliverySatisfaction > 0 && (
        <div className="text-xs">
          <span className="text-muted-foreground">Delivery satisfaction: </span>
          <span className="text-muted-foreground font-medium">{review.deliverySatisfaction}/5</span>
        </div>
      )}

      {review.deliveryPills && review.deliveryPills.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {review.deliveryPills.map((pill) => (
            <span
              key={pill}
              className="px-2 py-0.5 rounded-full text-xs bg-muted border"
            >
              {pill}
            </span>
          ))}
        </div>
      )}

      {showSellerReply && review.sellerReply && (
        <div className="bg-muted/50 rounded-lg p-3 text-sm">
          <span className="font-medium">Seller reply: </span>
          {review.sellerReply}
        </div>
      )}
    </div>
  )
}
