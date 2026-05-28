"use client"

import { useEffect, useState } from "react"
import dynamic from "next/dynamic"
import { adminApi, type ActiveDeliveryDto } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

const DeliveryMapView = dynamic(
  () => import("@/components/admin/delivery-map-view").then((m) => m.DeliveryMapView),
  { ssr: false },
)

const statusColors: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  pickup: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  transit: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
}

const statusLabels: Record<string, string> = {
  pending: "Pending",
  pickup: "Pickup",
  transit: "In transit",
}

export default function AdminDeliveriesPage() {
  const [deliveries, setDeliveries] = useState<ActiveDeliveryDto[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedDelivery, setSelectedDelivery] = useState<ActiveDeliveryDto | null>(null)

  const loadDeliveries = async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await adminApi.getActiveDeliveries()
      setDeliveries(res.data.deliveries ?? [])
    } catch {
      setError("Failed to load deliveries")
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadDeliveries()
    const interval = setInterval(loadDeliveries, 30_000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Live Deliveries</h1>
          <p className="text-sm text-muted-foreground mt-1">
            {deliveries.length} active delivery{deliveries.length !== 1 ? "ies" : "y"}
          </p>
        </div>
        <button
          type="button"
          onClick={loadDeliveries}
          className="px-4 py-2 border rounded-xl text-sm hover:bg-muted flex items-center gap-2"
        >
          <Icon name="refresh-cw" size="sm" />
          Refresh
        </button>
      </div>

      {error && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-xl p-4 text-sm">
          {error}
        </div>
      )}

      {loading && deliveries.length === 0 && (
        <div className="flex items-center justify-center h-64 bg-muted/30 rounded-xl border text-sm text-muted-foreground">
          Loading deliveries…
        </div>
      )}

      {!loading && deliveries.length === 0 && !error && (
        <div className="flex items-center justify-center h-64 bg-muted/30 rounded-xl border text-sm text-muted-foreground">
          <div className="text-center">
            <Icon name="truck" className="mx-auto mb-2 text-muted-foreground/50" size="lg" />
            <p>No active deliveries</p>
          </div>
        </div>
      )}

      {deliveries.length > 0 && (
        <DeliveryMapView deliveries={deliveries} />
      )}

      <div className="bg-card border rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50">
                <th className="text-left px-4 py-3 font-medium">Order</th>
                <th className="text-left px-4 py-3 font-medium">Rider</th>
                <th className="text-left px-4 py-3 font-medium">Buyer</th>
                <th className="text-left px-4 py-3 font-medium">Status</th>
                <th className="text-right px-4 py-3 font-medium">Distance</th>
              </tr>
            </thead>
            <tbody>
              {deliveries.map((d) => (
                <tr
                  key={d.deliveryId}
                  onClick={() => setSelectedDelivery(selectedDelivery?.deliveryId === d.deliveryId ? null : d)}
                  className={`border-b last:border-b-0 cursor-pointer hover:bg-muted/50 transition-colors ${
                    selectedDelivery?.deliveryId === d.deliveryId ? "bg-muted/30" : ""
                  }`}
                >
                  <td className="px-4 py-3 font-medium">#{d.orderId}</td>
                  <td className="px-4 py-3">{d.rider?.name ?? "—"}</td>
                  <td className="px-4 py-3">{d.buyer?.name ?? "—"}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${
                        statusColors[d.status] ?? "bg-gray-100 text-gray-700"
                      }`}
                    >
                      {statusLabels[d.status] ?? d.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    {d.distanceKm > 0 ? `${d.distanceKm.toFixed(1)} km` : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
