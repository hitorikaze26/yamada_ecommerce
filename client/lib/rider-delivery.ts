export interface RiderDeliveryLabelFields {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  orderId?: number | null
  isAutoMatched?: boolean
}

export function riderDeliveryLabel(delivery: RiderDeliveryLabelFields): string {
  return (
    delivery.displayLabel ??
    (delivery.isAutoMatched ? `ORD-${delivery.orderId ?? delivery.id}` : `DEL-${delivery.id}`)
  )
}

export function riderDeliveryEntityId(delivery: RiderDeliveryLabelFields): number {
  return delivery.deliveryId ?? delivery.id
}
