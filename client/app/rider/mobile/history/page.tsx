"use client"

import { useEffect, useMemo, useState } from "react"
import Link from "next/link"
import { riderApi } from "@/lib/api"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"

const kPrimaryPink = "#E891A0"

interface RiderHistoryItem {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  isAutoMatched?: boolean
  orderId: number | null
  status: string
  fee: number
  distanceKm: number
  createdAt: string | null
  shippingAddress?: string | null
  municipalityName?: string | null
  store?: { name?: string | null }
  buyer?: { name?: string | null; email?: string | null }
  items?: { name?: string | null; quantity: number }[]
  proofPhotoUrl?: string | null
  proofNote?: string | null
}

const statusFilters = ["all", "delivered", "transit", "pickup", "pending"] as const
const statusLabels: Record<string, string> = {
  all: "All",
  delivered: "Completed",
  transit: "Transit",
  pickup: "Pickup",
  pending: "Pending",
}
const dateFilters = ["all", "today", "week", "month"] as const
const dateLabels: Record<string, string> = {
  all: "All Time",
  today: "Today",
  week: "7 Days",
  month: "30 Days",
}

export default function RiderMobileHistory() {
  const { isVerified } = useAuth()
  const [items, setItems] = useState<RiderHistoryItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedImage, setSelectedImage] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<string>("all")
  const [dateFilter, setDateFilter] = useState<string>("all")

  useEffect(() => {
    const load = async () => {
      try {
        const res = await riderApi.getDeliveries()
        const data = (res.data as any)?.deliveries as RiderHistoryItem[] | undefined
        setItems(data || [])
      } catch {
        setItems([])
      } finally {
        setIsLoading(false)
      }
    }

    void load()
  }, [])

  const filteredItems = useMemo(() => {
    let result = [...items]

    if (statusFilter !== "all") {
      result = result.filter((d) => d.status === statusFilter)
    }

    const now = new Date()
    if (dateFilter === "today") {
      const todayStr = now.toISOString().slice(0, 10)
      result = result.filter((d) => d.createdAt?.slice(0, 10) === todayStr)
    } else if (dateFilter === "week") {
      const weekAgo = new Date(now)
      weekAgo.setDate(now.getDate() - 7)
      result = result.filter((d) => d.createdAt && new Date(d.createdAt) >= weekAgo)
    } else if (dateFilter === "month") {
      const monthAgo = new Date(now)
      monthAgo.setDate(now.getDate() - 30)
      result = result.filter((d) => d.createdAt && new Date(d.createdAt) >= monthAgo)
    }

    return result
  }, [items, statusFilter, dateFilter])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(price)
  }

  const formatDate = (value: string | null) => {
    if (!value) return ""
    const d = new Date(value)
    if (Number.isNaN(d.getTime())) return value
    return d.toLocaleString("en-PH", {
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    })
  }

  const formatAddress = (shippingAddress?: string | null, municipalityName?: string | null) => {
    if (!shippingAddress && !municipalityName) return "Customer address"
    if (municipalityName && shippingAddress) return `${municipalityName} — ${shippingAddress}`
    return municipalityName || shippingAddress || "Customer address"
  }

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "delivered": return "bg-green-100 text-green-700"
      case "transit": return "bg-purple-100 text-purple-700"
      case "pickup": return "bg-blue-100 text-blue-700"
      case "pending": return "bg-amber-100 text-amber-700"
      default: return "bg-gray-100 text-gray-700"
    }
  }

  return (
    <div className="p-4 space-y-4">
      <div>
        <h1 className="text-xl font-bold">History</h1>
        <p className="text-sm text-gray-500">View your delivery history with filters</p>
      </div>

      {!isVerified() && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="font-semibold text-amber-900 mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. Deliveries will appear here once an admin approves your account.
          </p>
        </div>
      )}

      {/* Filters */}
      <div className="flex flex-wrap gap-1.5">
        <div className="flex gap-1 overflow-x-auto pb-1">
          {statusFilters.map((f) => (
            <button
              key={f}
              onClick={() => setStatusFilter(f)}
              className={`px-2.5 py-1 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${
                statusFilter === f
                  ? "text-white"
                  : "bg-gray-100 text-gray-600"
              }`}
              style={{ backgroundColor: statusFilter === f ? kPrimaryPink : undefined }}
            >
              {statusLabels[f]}
            </button>
          ))}
        </div>
        <div className="flex gap-1 overflow-x-auto pb-1">
          {dateFilters.map((f) => (
            <button
              key={f}
              onClick={() => setDateFilter(f)}
              className={`px-2.5 py-1 rounded-lg text-xs font-medium whitespace-nowrap transition-colors ${
                dateFilter === f
                  ? "text-white"
                  : "bg-gray-100 text-gray-600"
              }`}
              style={{ backgroundColor: dateFilter === f ? kPrimaryPink : undefined }}
            >
              {dateLabels[f]}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="flex justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: kPrimaryPink }} />
        </div>
      ) : filteredItems.length === 0 ? (
        <div className="bg-white rounded-xl p-8 text-center shadow-sm">
          <svg className="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="font-semibold mb-2">No results</h3>
          <p className="text-sm text-gray-500">No deliveries match the current filters.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredItems.map((item) => {
            const firstItem = item.items && item.items.length > 0 ? item.items[0] : null
            const extraCount = item.items && item.items.length > 1 ? item.items.length - 1 : 0

            return (
              <div key={item.id} className="bg-white rounded-xl p-4 shadow-sm">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold text-sm">{riderDeliveryLabel(item)}</span>
                      <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(item.status)}`}>
                        {item.status === "delivered" ? "Completed" : item.status}
                      </span>
                    </div>
                    <p className="text-xs text-gray-500">
                      Order #{item.orderId ?? "N/A"} · {formatDate(item.createdAt)}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="font-bold" style={{ color: kPrimaryPink }}>
                      {formatPrice(item.fee)}
                    </p>
                    {item.distanceKm > 0 && (
                      <p className="text-xs text-gray-500">{item.distanceKm.toFixed(1)} km</p>
                    )}
                  </div>
                </div>

                {firstItem && (
                  <p className="text-xs text-gray-600 mb-1">
                    <span className="font-medium">Product:</span> {firstItem.name || "Item"}
                    {extraCount > 0 && ` + ${extraCount} more`}
                  </p>
                )}
                {item.store && (
                  <p className="text-xs text-gray-600 mb-3">
                    <span className="font-medium">Shop:</span> {item.store.name || "Unknown shop"}
                  </p>
                )}

                <div className="flex items-start gap-3 p-3 bg-green-50 rounded-xl">
                  <div className="w-9 h-9 rounded-full bg-green-100 flex items-center justify-center flex-shrink-0">
                    <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Dropoff Location</p>
                    <p className="text-sm font-medium">{formatAddress(item.shippingAddress, item.municipalityName)}</p>
                  </div>
                </div>

                {(item.proofPhotoUrl || item.proofNote) && (
                  <div className="mt-3 p-3 bg-blue-50 rounded-xl">
                    <div className="flex items-start gap-3">
                      <div className="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center flex-shrink-0">
                        <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                        </svg>
                      </div>
                      <div className="flex-1">
                        <p className="text-xs text-gray-500 mb-1">Proof of delivery</p>
                        {item.proofPhotoUrl && (
                          <button onClick={() => setSelectedImage(item.proofPhotoUrl!)} className="mb-2">
                            <img
                              src={item.proofPhotoUrl}
                              alt="Proof of delivery"
                              className="w-16 h-16 rounded-lg object-cover border"
                            />
                          </button>
                        )}
                        {item.proofNote && (
                          <p className="text-xs text-gray-600">
                            <span className="font-medium">Note:</span> {item.proofNote}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {selectedImage && (
        <div
          className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedImage(null)}
        >
          <img src={selectedImage} alt="Proof of delivery" className="max-w-full max-h-full rounded-lg" onClick={(e) => e.stopPropagation()} />
        </div>
      )}
    </div>
  )
}
