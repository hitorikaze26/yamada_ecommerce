"use client"

import Image from "next/image"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { resolveImageUrl } from "@/lib/api"
import { useChatOpen } from "@/hooks/use-chat-open"
import { toast } from "sonner"
import { ReportLinkButton } from "@/components/report/report-link-button"

export type SellerOrderDetail = {
  id: string
  backendId: number
  date: string
  status: string
  buyerId?: number | null
  customer: {
    name: string
    email: string
    address: string
    notes?: string | null
  }
  items: {
    product: { name: string; images: string[]; price: number; salePrice?: number }
    quantity: number
    variation: { color?: string; size?: string }
  }[]
  total: number
  paymentMethod: string
  riderDelivery?: {
    id: number
    status: string
    fee: number
    distanceKm?: number | null
    hasProofPhoto?: boolean
    proofPhotoUrl?: string | null
    proofNote?: string | null
    rider?: {
      id: number
      name: string
      email: string
      contactNumber?: string
      vehicleType?: string | null
      licenseNumber?: string | null
    } | null
  } | null
}

const statusActions: Record<string, { label: string; next: string }> = {
  pending: { label: "Accept order", next: "processing" },
  processing: { label: "Ready for pickup", next: "shipped" },
}

function getShippingAddressParts(raw: string | null | undefined): { label: string; value: string }[] {
  if (!raw) return []
  try {
    const parsed = JSON.parse(raw)
    if (parsed && typeof parsed === "object") {
      const {
        streetAddress,
        barangayName,
        municipalityName,
        provinceName,
        regionName,
        postalCode,
      } = parsed as Record<string, string>
      const parts: { label: string; value: string }[] = []
      if (streetAddress) parts.push({ label: "Street", value: streetAddress })
      const city = [barangayName, municipalityName].filter(Boolean).join(", ")
      if (city) parts.push({ label: "City", value: city })
      const region = [provinceName, regionName].filter(Boolean).join(", ")
      if (region) parts.push({ label: "Region", value: region })
      if (postalCode) parts.push({ label: "Postal Code", value: postalCode })
      return parts
    }
  } catch {
    /* legacy string */
  }
  return [{ label: "Address", value: raw }]
}

interface SellerOrderExpandedDetailsProps {
  order: SellerOrderDetail
  onUpdateStatus: (orderId: string, newStatus: string) => Promise<void>
  formatPrice: (price: number) => string
}

export function SellerOrderExpandedDetails({
  order,
  onUpdateStatus,
  formatPrice,
}: SellerOrderExpandedDetailsProps) {
  const itemCount = order.items.reduce((s, i) => s + i.quantity, 0)
  const canMessage = order.status !== "cancelled"
  const nextAction = statusActions[order.status]

  const { isBusy, openSellerOrder } = useChatOpen()
  const chatBusyKey = `seller-order-${order.backendId}`

  const handleMessageBuyer = async () => {
    const first = order.items[0]
    await openSellerOrder(chatBusyKey, {
      orderId: order.backendId,
      productName: first?.product?.name ?? `Order ${order.id}`,
      productImageUrl: first?.product?.images?.[0],
      status: order.status,
      totalAmount: order.total,
      displayId: order.id,
    })
  }

  return (
    <div className="px-4 pb-4 pt-2 space-y-4 border-t bg-muted/10" onClick={(e) => e.stopPropagation()}>
      <div className="flex flex-wrap items-center justify-between gap-3 text-sm rounded-xl border bg-card p-3">
        <div>
          <p className="text-xs text-muted-foreground">Order total</p>
          <p className="text-xl font-bold text-primary">{formatPrice(order.total)}</p>
        </div>
        <div className="text-right text-muted-foreground">
          <p>{order.items.length} line item(s) · {itemCount} unit(s)</p>
          {order.paymentMethod && (
            <p className="text-xs font-medium text-foreground mt-0.5">{order.paymentMethod}</p>
          )}
        </div>
      </div>

      <div>
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2 flex items-center gap-1">
          <Icon name="shopping-bag" size="sm" />
          Items
        </p>
        <ul className="space-y-2">
          {order.items.map((item, index) => {
            const imgSrc = resolveImageUrl(item.product.images[0]) || "/placeholder.svg"
            const unit = item.product.salePrice ?? item.product.price
            return (
              <li key={index} className="flex gap-3 rounded-xl border bg-card p-3">
                <div className="relative w-12 h-12 rounded-lg overflow-hidden bg-muted shrink-0">
                  <Image src={imgSrc} alt={item.product.name} fill className="object-cover" sizes="48px" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-sm">{item.product.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {[
                      item.variation.color && `Color: ${item.variation.color}`,
                      item.variation.size && `Size: ${item.variation.size}`,
                      `Qty: ${item.quantity}`,
                    ]
                      .filter(Boolean)
                      .join(" · ")}
                  </p>
                </div>
                <p className="text-sm font-semibold shrink-0">{formatPrice(unit * item.quantity)}</p>
              </li>
            )
          })}
        </ul>
      </div>

      <div className="rounded-xl border bg-card p-3 text-sm space-y-2">
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide flex items-center gap-1">
          <Icon name="user" size="sm" />
          Customer
        </p>
        <p>
          <span className="text-muted-foreground">Name: </span>
          <span className="font-medium">{order.customer.name}</span>
        </p>
        {order.customer.email && (
          <p className="break-all">
            <span className="text-muted-foreground">Email: </span>
            <span className="font-medium">{order.customer.email}</span>
          </p>
        )}
        {order.customer.notes && (
          <p>
            <span className="text-muted-foreground">Notes: </span>
            {order.customer.notes}
          </p>
        )}
      </div>

      {order.customer.address && (
        <div className="rounded-xl border bg-card p-3 text-sm space-y-2">
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide flex items-center gap-1">
            <Icon name="map-marker" size="sm" />
            Shipping address
          </p>
          {getShippingAddressParts(order.customer.address).map((part) => (
            <p key={part.label}>
              <span className="text-muted-foreground">{part.label}: </span>
              {part.value}
            </p>
          ))}
        </div>
      )}

      {order.riderDelivery?.rider && (
        <div className="rounded-xl border bg-card p-3 text-sm space-y-2">
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide flex items-center gap-1">
            <Icon name="truck" size="sm" />
            Delivery rider
          </p>
          <p className="font-semibold">{order.riderDelivery.rider.name}</p>
          {order.riderDelivery.rider.email && (
            <p className="text-muted-foreground">{order.riderDelivery.rider.email}</p>
          )}
          {order.riderDelivery.rider.contactNumber && (
            <p>
              <span className="text-muted-foreground">Contact: </span>
              {order.riderDelivery.rider.contactNumber}
            </p>
          )}
          {order.riderDelivery.rider.vehicleType && (
            <p>
              <span className="text-muted-foreground">Vehicle: </span>
              <span className="capitalize">{order.riderDelivery.rider.vehicleType}</span>
            </p>
          )}
          {order.riderDelivery.distanceKm != null && (
            <p>
              <span className="text-muted-foreground">Distance: </span>
              {order.riderDelivery.distanceKm.toFixed(1)} km
            </p>
          )}
          {order.riderDelivery.fee > 0 && (
            <p>
              <span className="text-muted-foreground">Fee: </span>
              <span className="font-semibold">{formatPrice(order.riderDelivery.fee)}</span>
            </p>
          )}
          {order.riderDelivery.proofPhotoUrl && (
            <a
              href={order.riderDelivery.proofPhotoUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-block text-primary text-xs hover:underline"
            >
              View proof of delivery
            </a>
          )}
          {order.riderDelivery.proofNote && (
            <p>
              <span className="text-muted-foreground">Note: </span>
              {order.riderDelivery.proofNote}
            </p>
          )}
        </div>
      )}

      <div className="flex flex-wrap gap-2 pt-1 border-t">
        {canMessage && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={isBusy(chatBusyKey)}
            onClick={() => void handleMessageBuyer()}
          >
            {isBusy(chatBusyKey) ? (
              <>
                <span className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin mr-2" />
                Opening chat…
              </>
            ) : (
              <>
                <Icon name="envelope" className="mr-2" />
                Message buyer
              </>
            )}
          </Button>
        )}
        {(order.status === "pending" || order.status === "processing") && (
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="border-destructive text-destructive hover:bg-destructive/10"
            onClick={() => void onUpdateStatus(order.id, "cancelled")}
          >
            Cancel order
          </Button>
        )}
        {nextAction && (
          <Button type="button" size="sm" onClick={() => void onUpdateStatus(order.id, nextAction.next)}>
            {nextAction.label}
          </Button>
        )}
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => {
            toast.success("Label generated successfully.")
          }}
        >
          Print label
        </Button>
        {order.buyerId != null && (
          <ReportLinkButton
            reporterRole="seller"
            params={{
              targetRole: "buyer",
              targetUserId: order.buyerId,
              orderId: order.backendId,
              label: order.customer.name,
            }}
          >
            Report buyer
          </ReportLinkButton>
        )}
        {order.riderDelivery?.rider?.id != null && (
          <ReportLinkButton
            reporterRole="seller"
            params={{
              targetRole: "rider",
              targetUserId: order.riderDelivery.rider.id,
              orderId: order.backendId,
              label: order.riderDelivery.rider.name,
            }}
          >
            Report rider
          </ReportLinkButton>
        )}
      </div>
    </div>
  )
}
