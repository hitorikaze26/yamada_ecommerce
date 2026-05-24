"use client"

import { useState } from "react"
import { Icon } from "@/components/ui/icon"
import {
  type ReviewFormat,
  type ReviewableItem,
  type ProductReviewPayload,
  dimensionKeysForFormat,
  dimensionLabelsForFormat,
} from "@/lib/review-types"

function StarPicker({
  value,
  onChange,
  size = "md",
}: {
  value: number
  onChange: (v: number) => void
  size?: "md" | "lg"
}) {
  const iconClass = size === "lg" ? "text-3xl" : "text-xl"
  return (
    <div className="flex gap-1 justify-center">
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          onClick={() => onChange(star)}
          className="p-1 rounded-lg hover:bg-amber-50 dark:hover:bg-amber-950/30 transition-colors"
          aria-label={`${star} stars`}
        >
          <Icon
            name="star"
            className={`${iconClass} ${
              value >= star ? "text-amber-500" : "text-muted-foreground/40"
            }`}
          />
        </button>
      ))}
    </div>
  )
}

function StarRow({
  value,
  onChange,
  label,
}: {
  value: number
  onChange: (v: number) => void
  label: string
}) {
  return (
    <div className="flex items-center justify-between gap-3 py-2 border-b border-border/50 last:border-0">
      <span className="text-sm text-foreground">{label}</span>
      <div className="flex gap-0.5 shrink-0">
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            key={star}
            type="button"
            onClick={() => onChange(star)}
            className="p-0.5"
            aria-label={`${label} ${star} stars`}
          >
            <Icon
              name="star"
              className={value >= star ? "text-amber-500 text-base" : "text-muted-foreground/40 text-base"}
            />
          </button>
        ))}
      </div>
    </div>
  )
}

function formatVariant(v: ReviewableItem["variant"]): string {
  if (!v) return ""
  const parts = []
  if (v.color) parts.push(v.color)
  if (v.size) parts.push(v.size)
  return parts.join(" / ")
}

function formatPrice(amount: number): string {
  return new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(amount)
}

interface OrderReviewFormProps {
  item: ReviewableItem
  deliveryPillOptions: string[]
  onSubmit: (payload: ProductReviewPayload) => Promise<void>
  submitted?: boolean
  itemIndex?: number
  itemTotal?: number
}

export function OrderReviewForm({
  item,
  deliveryPillOptions,
  onSubmit,
  submitted = false,
  itemIndex = 1,
  itemTotal = 1,
}: OrderReviewFormProps) {
  const format = (item.reviewFormat || "default") as ReviewFormat
  const dimKeys = dimensionKeysForFormat(format)
  const dimLabels = dimensionLabelsForFormat(format)
  const isAccessories = format === "accessories_shoes"

  const [overallRating, setOverallRating] = useState(0)
  const [ratings, setRatings] = useState<Record<string, number>>({})
  const [customerReview, setCustomerReview] = useState("")
  const [deliverySatisfaction, setDeliverySatisfaction] = useState(0)
  const [deliveryPills, setDeliveryPills] = useState<string[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const togglePill = (pill: string) => {
    setDeliveryPills((prev) =>
      prev.includes(pill) ? prev.filter((p) => p !== pill) : [...prev, pill],
    )
  }

  const handleSubmit = async () => {
    setError(null)
    if (format === "default" && overallRating < 1) {
      setError("Please select an overall rating.")
      return
    }
    for (const key of dimKeys) {
      if (!ratings[key] || ratings[key] < 1) {
        setError(`Please rate ${dimLabels[key]}.`)
        return
      }
    }
    if (deliverySatisfaction < 1) {
      setError("Please rate delivery satisfaction.")
      return
    }
    setSubmitting(true)
    try {
      await onSubmit({
        orderItemId: item.orderItemId,
        reviewFormat: format,
        overallRating: format === "default" ? overallRating : undefined,
        ratings,
        customerReview: customerReview.trim() || undefined,
        deliverySatisfaction,
        deliveryPills,
      })
    } catch {
      setError("Failed to submit review. Please try again.")
    } finally {
      setSubmitting(false)
    }
  }

  if (submitted) {
    return (
      <div className="rounded-2xl border border-green-200 dark:border-green-900 bg-green-50/80 dark:bg-green-950/30 p-6 flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-green-100 dark:bg-green-900/50 flex items-center justify-center shrink-0">
          <Icon name="check" className="text-green-600 dark:text-green-400 text-xl" />
        </div>
        <div>
          <p className="font-semibold text-green-800 dark:text-green-200">Review submitted</p>
          <p className="text-sm text-green-700/80 dark:text-green-300/80">
            Thank you for your feedback on {item.productName ?? "this item"}.
          </p>
        </div>
      </div>
    )
  }

  const lineTotal =
    item.unitPrice != null && item.quantity != null
      ? item.unitPrice * item.quantity
      : item.unitPrice

  return (
    <article className="rounded-2xl border bg-card shadow-sm overflow-hidden">
      {itemTotal > 1 && (
        <div className="px-5 py-2 bg-muted/40 border-b text-xs font-medium text-muted-foreground">
          Item {itemIndex} of {itemTotal}
        </div>
      )}

      <div className="p-5 sm:p-6 space-y-6">
        <div className="flex flex-wrap items-start justify-between gap-3 pb-4 border-b">
          <div>
            <p className="text-xs uppercase tracking-wide text-muted-foreground font-medium">
              Product
            </p>
            <h3 className="text-lg font-semibold mt-0.5">{item.productName ?? "Item"}</h3>
            {formatVariant(item.variant) && (
              <p className="text-sm text-muted-foreground mt-1">{formatVariant(item.variant)}</p>
            )}
          </div>
          {lineTotal != null && (
            <p className="text-lg font-bold text-primary">{formatPrice(lineTotal)}</p>
          )}
        </div>

        {!isAccessories && (
          <section className="rounded-xl bg-amber-50/60 dark:bg-amber-950/20 p-4 border border-amber-100 dark:border-amber-900/40">
            <p className="text-sm font-semibold text-center mb-3">Overall rating</p>
            <StarPicker value={overallRating} onChange={setOverallRating} size="lg" />
          </section>
        )}

        <section>
          <div className="flex items-center gap-2 mb-3">
            <Icon name="star" className="text-amber-500" />
            <h4 className="text-sm font-semibold">Product quality</h4>
          </div>
          <div className="rounded-xl border bg-background/50 px-3">
            {dimKeys.map((key) => (
              <StarRow
                key={key}
                label={dimLabels[key]}
                value={ratings[key] ?? 0}
                onChange={(v) => setRatings((prev) => ({ ...prev, [key]: v }))}
              />
            ))}
          </div>
        </section>

        <section>
          <div className="flex items-center gap-2 mb-2">
            <Icon name="align-left" className="text-muted-foreground" />
            <h4 className="text-sm font-semibold">Your review</h4>
          </div>
          <textarea
            className="w-full border rounded-xl px-4 py-3 text-sm min-h-[100px] bg-background focus:outline-none focus:ring-2 focus:ring-primary/20"
            placeholder="Tell others about fit, quality, and whether it matched the listing…"
            value={customerReview}
            onChange={(e) => setCustomerReview(e.target.value)}
          />
        </section>

        <section className="rounded-xl border p-4 space-y-4">
          <div className="flex items-center gap-2">
            <Icon name="truck" className="text-primary" />
            <h4 className="text-sm font-semibold">Delivery experience</h4>
          </div>
          <div>
            <p className="text-xs text-muted-foreground mb-2 text-center">Satisfaction</p>
            <StarPicker value={deliverySatisfaction} onChange={setDeliverySatisfaction} />
          </div>
          <div>
            <p className="text-xs text-muted-foreground mb-2">What went well? (optional)</p>
            <div className="flex flex-wrap gap-2">
              {deliveryPillOptions.map((pill) => (
                <button
                  key={pill}
                  type="button"
                  onClick={() => togglePill(pill)}
                  className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-all ${
                    deliveryPills.includes(pill)
                      ? "bg-primary text-primary-foreground border-primary shadow-sm"
                      : "bg-background hover:border-primary/40"
                  }`}
                >
                  {pill}
                </button>
              ))}
            </div>
          </div>
        </section>

        {error && (
          <p className="text-sm text-destructive bg-destructive/10 rounded-lg px-3 py-2">{error}</p>
        )}

        <button
          type="button"
          disabled={submitting}
          onClick={() => void handleSubmit()}
          className="w-full py-3 rounded-xl bg-primary text-primary-foreground text-sm font-semibold disabled:opacity-50 hover:bg-primary/90 transition-colors"
        >
          {submitting ? "Submitting…" : "Submit review"}
        </button>
      </div>
    </article>
  )
}
