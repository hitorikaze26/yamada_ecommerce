"use client"

import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { chatApi } from "@/lib/api"
import { getBuyerFetchError } from "@/lib/buyer-fetch"
import { useRouter } from "next/navigation"

const SUPPORT_EMAIL = "yamadaecommerce929@gmail.com"

export default function HelpCenterPage() {
  const router = useRouter()

  const openSupport = async () => {
    try {
      const res = await chatApi.getSupportConversation()
      const conv = res.data.conversation
      if (conv?.id) {
        router.push(`/home?openChat=${conv.id}`)
      }
    } catch (err) {
      alert(getBuyerFetchError(err, "Could not open support chat. Use the chat icon in the header."))
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Help Center</h1>
        <p className="text-muted-foreground">Answers about orders, payments, and your account.</p>
      </div>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="text-lg font-semibold">Orders & delivery</h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          Track orders under{" "}
          <Link href="/buyer/orders" className="text-primary hover:underline">
            My Orders
          </Link>
          . After delivery, confirm receipt on the order page so you can leave a review.
        </p>
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="text-lg font-semibold">Payments</h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          We support Cash on Delivery (COD). Pay when your order arrives.
        </p>
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="text-lg font-semibold">Account verification</h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          New buyer accounts need admin approval before checkout. You can browse and add to cart while waiting.
        </p>
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="text-lg font-semibold">Refunds & issues</h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          Request a refund from an order detail page, or view status on{" "}
          <Link href="/buyer/refunds" className="text-primary hover:underline">
            Refunds
          </Link>
          . Track reports you filed on{" "}
          <Link href="/buyer/reports" className="text-primary hover:underline">
            My Reports
          </Link>
          .
        </p>
      </section>

      <section className="bg-card border rounded-2xl p-6 space-y-3">
        <h2 className="text-lg font-semibold">Report a problem</h2>
        <p className="text-sm text-muted-foreground leading-relaxed">
          Experiencing issues with an order, store, rider, or the app? Let us know.
        </p>
        <Link
          href="/buyer/report"
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-destructive/10 text-destructive rounded-xl text-sm font-medium hover:bg-destructive/20 transition-colors"
        >
          <Icon name="exclamation" />
          Report a problem
        </Link>
      </section>

      <div className="flex flex-col sm:flex-row gap-3">
        <button
          type="button"
          onClick={() => void openSupport()}
          className="inline-flex items-center justify-center gap-2 px-4 py-3 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90"
        >
          <Icon name="comments" />
          Chat with support
        </button>
        <a
          href={`mailto:${SUPPORT_EMAIL}`}
          className="inline-flex items-center justify-center gap-2 px-4 py-3 border rounded-xl font-medium hover:bg-muted"
        >
          <Icon name="envelope" />
          {SUPPORT_EMAIL}
        </a>
      </div>
    </div>
  )
}
