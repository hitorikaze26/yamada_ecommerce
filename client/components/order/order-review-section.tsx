"use client"

import { useRef, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { OrderReviewForm } from "@/components/order/order-review-form"
import type { ReviewableItem, ProductReviewPayload } from "@/lib/review-types"

interface OrderReviewSectionProps {
  orderId: number
  reviewableItems: ReviewableItem[]
  submittedReviewItemIds: Set<number>
  deliveryPillOptions: string[]
  onSubmit: (payload: ProductReviewPayload) => Promise<void>
  highlight?: boolean
}

export function OrderReviewSection({
  reviewableItems,
  submittedReviewItemIds,
  deliveryPillOptions,
  onSubmit,
  highlight = false,
}: OrderReviewSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (highlight && sectionRef.current) {
      sectionRef.current.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }, [highlight])

  const pending = reviewableItems.filter(
    (i) => !submittedReviewItemIds.has(i.orderItemId),
  )
  const allDone = reviewableItems.length > 0 && pending.length === 0

  return (
    <div
      ref={sectionRef}
      id="rate-order"
      className={`mt-8 rounded-2xl overflow-hidden border ${
        highlight ? "ring-2 ring-primary/30 border-primary/40" : ""
      }`}
    >
      <div className="bg-gradient-to-r from-amber-500/10 via-primary/5 to-transparent px-6 py-5 border-b">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-100 dark:bg-amber-900/40 flex items-center justify-center shrink-0">
            <Icon name="star" className="text-amber-600 dark:text-amber-400 text-2xl" />
          </div>
          <div>
            <h2 className="text-xl font-bold">
              {highlight && !allDone ? "Thanks for confirming!" : "Rate your order"}
            </h2>
            <p className="text-sm text-muted-foreground mt-1">
              {allDone
                ? "You have reviewed every item — thank you!"
                : highlight
                  ? `Share feedback for ${pending.length} item${pending.length === 1 ? "" : "s"} while your experience is fresh.`
                  : `Share feedback for ${pending.length} item${pending.length === 1 ? "" : "s"}. Your ratings help other shoppers.`}
            </p>
          </div>
        </div>
        {reviewableItems.length > 1 && !allDone && (
          <div className="mt-4 flex gap-1">
            {reviewableItems.map((item, idx) => {
              const done = submittedReviewItemIds.has(item.orderItemId)
              return (
                <div
                  key={item.orderItemId}
                  className={`h-1.5 flex-1 rounded-full transition-colors ${
                    done ? "bg-green-500" : "bg-muted"
                  }`}
                  title={`Item ${idx + 1}`}
                />
              )
            })}
          </div>
        )}
      </div>

      <div className="p-6 space-y-6 bg-card">
        {reviewableItems.length === 0 && submittedReviewItemIds.size === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-4">
            No items to review for this order.
          </p>
        ) : (
          reviewableItems.map((item, index) => (
            <OrderReviewForm
              key={item.orderItemId}
              item={item}
              deliveryPillOptions={deliveryPillOptions}
              onSubmit={onSubmit}
              submitted={submittedReviewItemIds.has(item.orderItemId)}
              itemIndex={index + 1}
              itemTotal={reviewableItems.length}
            />
          ))
        )}
      </div>
    </div>
  )
}
