"use client"

import Link from "next/link"
import { useCallback, useEffect, useState } from "react"
import Swal from "sweetalert2"
import { Icon } from "@/components/ui/icon"
import { sellerInsightsApi } from "@/lib/api"
import { ReviewDisplayCard } from "@/components/reviews/review-display-card"
import type { SerializedReview } from "@/lib/review-types"

interface SellerReview extends SerializedReview {
  visibility: string
}

const sortOptions = [
  { id: "newest", label: "Newest" },
  { id: "oldest", label: "Oldest" },
  { id: "rating_high", label: "Highest rating" },
  { id: "rating_low", label: "Lowest rating" },
] as const

const statusOptions = [
  { id: "all", label: "All" },
  { id: "visible", label: "Visible" },
  { id: "hidden", label: "Hidden" },
  { id: "archived", label: "Archived" },
] as const

export default function SellerFeedbackPage() {
  const [sort, setSort] = useState<string>("newest")
  const [status, setStatus] = useState<string>("all")
  const [reviews, setReviews] = useState<SellerReview[]>([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await sellerInsightsApi.getReviews({ sort, status, page: 1 })
      setReviews(res.data?.reviews ?? [])
    } catch {
      setReviews([])
    } finally {
      setLoading(false)
    }
  }, [sort, status])

  useEffect(() => {
    void load()
  }, [load])

  const patchReviewInList = (updated: Record<string, unknown>) => {
    const id = updated.id as number | undefined
    if (id == null) return
    setReviews((prev) =>
      prev.map((r) => (r.id === id ? ({ ...r, ...updated } as SellerReview) : r)),
    )
  }

  const handleReply = async (review: SellerReview) => {
    const result = await Swal.fire({
      title: "Reply to review",
      input: "textarea",
      inputValue: review.sellerReply ?? "",
      inputPlaceholder: "Your reply to the buyer…",
      showCancelButton: true,
      confirmButtonText: "Send",
      inputValidator: (value) => {
        if (!value?.trim()) return "Reply cannot be empty"
        return null
      },
    })
    if (!result.isConfirmed || !result.value?.trim()) return

    try {
      const res = await sellerInsightsApi.replyToReview(review.id, result.value.trim())
      const updated = res.data?.review
      if (updated) {
        patchReviewInList(updated)
      } else {
        await load()
      }
      const warning = res.data?.warning
      await Swal.fire({
        icon: warning ? "warning" : "success",
        title: warning ? "Reply saved with a warning" : "Reply sent",
        text: warning ?? undefined,
        timer: warning ? undefined : 1500,
        showConfirmButton: !!warning,
      })
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data
          ?.msg ?? "Failed to send reply."
      await Swal.fire({ icon: "error", title: msg })
    }
  }

  const handleDeleteReply = async (review: SellerReview) => {
    if (!review.sellerReply?.trim()) return
    const confirm = await Swal.fire({
      title: "Delete your reply?",
      text: "The buyer will no longer see your response on this review.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Delete reply",
      confirmButtonColor: "#ef4444",
    })
    if (!confirm.isConfirmed) return

    try {
      const res = await sellerInsightsApi.deleteReviewReply(review.id)
      const updated = res.data?.review
      if (updated) {
        patchReviewInList(updated)
      } else {
        await load()
      }
      await Swal.fire({
        icon: "success",
        title: "Reply removed",
        timer: 1200,
        showConfirmButton: false,
      })
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data
          ?.msg ?? "Failed to delete reply."
      await Swal.fire({ icon: "error", title: msg })
    }
  }

  const handleModerate = async (
    review: SellerReview,
    action: "hide" | "archive" | "visible" | "delete",
  ) => {
    if (action === "delete") {
      const confirm = await Swal.fire({
        title: "Delete review?",
        text: "This soft-deletes the review for buyers.",
        icon: "warning",
        showCancelButton: true,
        confirmButtonColor: "#ef4444",
      })
      if (!confirm.isConfirmed) return
      try {
        await sellerInsightsApi.moderateReview(review.id, { delete: true })
        await load()
      } catch {
        await Swal.fire({ icon: "error", title: "Delete failed" })
      }
      return
    }

    const visibility =
      action === "hide" ? "hidden" : action === "archive" ? "archived" : "visible"
    try {
      await sellerInsightsApi.moderateReview(review.id, { visibility })
      await load()
    } catch {
      await Swal.fire({ icon: "error", title: "Update failed" })
    }
  }

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <Link
          href="/seller/insights"
          className="text-sm text-muted-foreground hover:text-primary inline-flex items-center gap-1 mb-2"
        >
          <Icon name="arrow-left" /> Insights
        </Link>
        <h1 className="text-2xl font-bold">Feedback management</h1>
      </div>

      <div className="flex flex-wrap gap-2">
        {sortOptions.map((o) => (
          <button
            key={o.id}
            type="button"
            onClick={() => setSort(o.id)}
            className={`px-3 py-1.5 rounded-full text-sm border ${
              sort === o.id
                ? "bg-primary text-primary-foreground border-primary"
                : "hover:bg-muted"
            }`}
          >
            {o.label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        {statusOptions.map((o) => (
          <button
            key={o.id}
            type="button"
            onClick={() => setStatus(o.id)}
            className={`px-3 py-1.5 rounded-full text-sm border ${
              status === o.id
                ? "bg-primary text-primary-foreground border-primary"
                : "hover:bg-muted"
            }`}
          >
            {o.label}
          </button>
        ))}
      </div>

      {loading ? (
        <p className="text-sm text-muted-foreground">Loading reviews…</p>
      ) : reviews.length === 0 ? (
        <p className="text-sm text-muted-foreground">No reviews match this filter.</p>
      ) : (
        <ul className="space-y-4">
          {reviews.map((r) => (
            <li key={r.id} className="bg-card border rounded-2xl p-4 space-y-3">
              <ReviewDisplayCard review={r} showSellerReply={false} />
              <p className="text-xs text-muted-foreground capitalize">Status: {r.visibility}</p>
              {r.sellerReply?.trim() ? (
                <div className="rounded-xl border border-primary/20 bg-primary/5 px-4 py-3 space-y-2">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-xs font-semibold text-primary">Your reply</p>
                    <button
                      type="button"
                      className="text-xs text-destructive hover:underline"
                      onClick={() => void handleDeleteReply(r)}
                    >
                      Delete reply
                    </button>
                  </div>
                  <p className="text-sm text-foreground whitespace-pre-wrap">{r.sellerReply}</p>
                </div>
              ) : null}
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
                  onClick={() => void handleReply(r)}
                >
                  {r.sellerReply?.trim() ? "Edit reply" : "Reply"}
                </button>
                {r.visibility !== "hidden" && (
                  <button
                    type="button"
                    className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
                    onClick={() => void handleModerate(r, "hide")}
                  >
                    Hide
                  </button>
                )}
                {r.visibility !== "archived" && (
                  <button
                    type="button"
                    className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
                    onClick={() => void handleModerate(r, "archive")}
                  >
                    Archive
                  </button>
                )}
                {r.visibility !== "visible" && (
                  <button
                    type="button"
                    className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
                    onClick={() => void handleModerate(r, "visible")}
                  >
                    Show
                  </button>
                )}
                <button
                  type="button"
                  className="text-sm px-3 py-1.5 rounded-lg border border-destructive/40 text-destructive hover:bg-destructive/10"
                  onClick={() => void handleModerate(r, "delete")}
                >
                  Delete review
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
