"use client"

import { useEffect, useMemo, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"

import { Icon } from "@/components/ui/icon"
import { riderApi, resolveImageUrl } from "@/lib/api"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"
import { ReportLinkButton } from "@/components/report/report-link-button"

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
  store?: {
    id?: number | null
    name?: string | null
  }
  buyer?: {
    id?: number | null
    email?: string | null
    name?: string | null
  }
  items?: { id: number; name?: string | null; quantity: number }[]
  proofPhotoUrl?: string | null
  proofNote?: string | null
}

const statusColors: Record<string, { bg: string; text: string }> = {
  delivered: { bg: "bg-green-100 dark:bg-green-900/30", text: "text-green-700 dark:text-green-400" },
  transit: { bg: "bg-purple-100 dark:bg-purple-900/30", text: "text-purple-700 dark:text-purple-400" },
  pickup: { bg: "bg-blue-100 dark:bg-blue-900/30", text: "text-blue-700 dark:text-blue-400" },
  pending: { bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-700 dark:text-amber-400" },
}

const statusFilters = ["all", "delivered", "transit", "pickup", "pending"] as const
const statusLabels: Record<string, string> = {
  all: "All Status",
  delivered: "Completed",
  transit: "In Transit",
  pickup: "Pickup",
  pending: "Pending",
}
const dateFilters = ["all", "today", "week", "month"] as const
const dateLabels: Record<string, string> = {
  all: "All Time",
  today: "Today",
  week: "Past 7 Days",
  month: "Past 30 Days",
}

export default function RiderHistoryPage() {
  const { isVerified } = useAuth()
  const [items, setItems] = useState<RiderHistoryItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
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
      result = result.filter((d) => {
        if (!d.createdAt) return false
        return new Date(d.createdAt) >= weekAgo
      })
    } else if (dateFilter === "month") {
      const monthAgo = new Date(now)
      monthAgo.setDate(now.getDate() - 30)
      result = result.filter((d) => {
        if (!d.createdAt) return false
        return new Date(d.createdAt) >= monthAgo
      })
    }

    return result
  }, [items, statusFilter, dateFilter])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
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

  const formatDropoffAddress = (shippingAddress?: string | null, municipalityName?: string | null) => {
    if (!shippingAddress && !municipalityName) return "Customer address"

    let parts: string[] = []
    try {
      if (shippingAddress && shippingAddress.trim().startsWith("{")) {
        let cleaned = shippingAddress.trim()
        if ((cleaned.startsWith('"') && cleaned.endsWith('"')) || (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
          cleaned = cleaned.slice(1, -1)
        }
        cleaned = cleaned
          .replace(/'([^']+)':/g, '"$1":')
          .replace(/: '([^']*)'/g, ': "$1"')
          .replace(/, '([^']*)'/g, ', "$1"')
          .replace(/'}/g, '"}')
          .replace(/',/g, '",')
          .replace(/: None/g, ': null')
          .replace(/: None,/g, ': null,')
          .replace(/, None}/g, ', null}')
        const obj = JSON.parse(cleaned)
        if (obj.streetAddress && obj.streetAddress !== "None" && obj.streetAddress !== null) parts.push(String(obj.streetAddress))
        if (obj.barangayName && obj.barangayName !== "None" && obj.barangayName !== null) parts.push(String(obj.barangayName))
        if (obj.municipalityName && obj.municipalityName !== "None" && obj.municipalityName !== null) parts.push(String(obj.municipalityName))
        if (obj.provinceName && obj.provinceName !== "None" && obj.provinceName !== null) parts.push(String(obj.provinceName))
        if (obj.postalCode && obj.postalCode !== "None" && obj.postalCode !== null) parts.push(String(obj.postalCode))
      }
    } catch {
      // Fall back below
    }

    if (parts.length > 0) return parts.join(", ")
    if (municipalityName && shippingAddress) return `${municipalityName} — ${shippingAddress}`
    if (municipalityName) return municipalityName
    if (shippingAddress) return shippingAddress
    return "Customer address"
  }

  if (!isVerified()) {
    return (
      <div className="space-y-4">
        <h1 className="text-3xl font-bold mb-2">History</h1>
        <div className="bg-amber-50 border border-amber-200 text-amber-900 rounded-2xl p-4 text-sm">
          <p className="font-semibold mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. Completed deliveries will appear here once an admin approves your
            account.
          </p>
        </div>
      </div>
    )
  }

  const totalEarnings = filteredItems.reduce((sum, item) => sum + (item.fee || 0), 0)
  const totalDeliveries = filteredItems.length

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">History</h1>
        <p className="text-muted-foreground">View your delivery history with optional filters.</p>
      </div>

      {totalDeliveries > 0 && (
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-card border rounded-2xl p-4 flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="truck-check" className="text-primary" />
            </div>
            <div>
              <p className="text-2xl font-bold">{totalDeliveries}</p>
              <p className="text-xs text-muted-foreground">Deliveries</p>
            </div>
          </div>
          <div className="bg-card border rounded-2xl p-4 flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
              <Icon name="peso-sign" className="text-green-600" />
            </div>
            <div>
              <p className="text-2xl font-bold">{formatPrice(totalEarnings)}</p>
              <p className="text-xs text-muted-foreground">Total Earnings</p>
            </div>
          </div>
        </div>
      )}

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex gap-1.5">
          {statusFilters.map((f) => (
            <button
              key={f}
              onClick={() => setStatusFilter(f)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium transition-colors ${
                statusFilter === f
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:bg-muted/80"
              }`}
            >
              {statusLabels[f]}
            </button>
          ))}
        </div>
        <div className="flex gap-1.5">
          {dateFilters.map((f) => (
            <button
              key={f}
              onClick={() => setDateFilter(f)}
              className={`px-3 py-1.5 rounded-xl text-xs font-medium transition-colors ${
                dateFilter === f
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:bg-muted/80"
              }`}
            >
              {dateLabels[f]}
            </button>
          ))}
        </div>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-8 text-center text-sm text-muted-foreground">
          Loading history...
        </div>
      )}

      {!isLoading && filteredItems.length === 0 && (
        <div className="bg-card border rounded-2xl p-12 text-center">
          <Icon name="rectangle-vertical-history" size="xl" className="mx-auto text-muted-foreground mb-4" />
          <h3 className="text-lg font-semibold mb-2">No results</h3>
          <p className="text-muted-foreground">No deliveries match the current filters.</p>
        </div>
      )}

      {!isLoading && filteredItems.length > 0 && (
        <AnimatePresence mode="wait">
          <motion.div
            key={`${statusFilter}-${dateFilter}`}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            className="space-y-4"
          >
            {filteredItems.map((item) => {
              const statusColor = statusColors[item.status] || statusColors.pending
              const firstItem = item.items && item.items.length > 0 ? item.items[0] : null
              const extraCount = item.items && item.items.length > 1 ? item.items.length - 1 : 0
              return (
                <motion.div
                  key={item.id}
                  layout
                  initial={{ opacity: 0, y: 6 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="bg-card border rounded-2xl p-5"
                >
                  <div className="flex flex-wrap items-start justify-between gap-4 mb-4">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <p className="font-bold text-lg">{riderDeliveryLabel(item)}</p>
                        <span
                          className={`px-2.5 py-1 rounded-full text-xs font-semibold uppercase tracking-wide ${statusColor.bg} ${statusColor.text}`}
                        >
                          {item.status === "delivered" ? "Completed" : item.status}
                        </span>
                      </div>
                      <p className="text-sm text-muted-foreground">
                        Order #{item.orderId ?? "N/A"} · {formatDate(item.createdAt)}
                      </p>

                      {firstItem && (
                        <div className="mt-3 flex items-center gap-2">
                          <div className="w-8 h-8 rounded-lg bg-muted flex items-center justify-center flex-shrink-0">
                            <Icon name="box" className="text-muted-foreground" size="sm" />
                          </div>
                          <p className="text-sm font-medium truncate">
                            {firstItem.name || "Item"}
                            {extraCount > 0 && (
                              <span className="text-muted-foreground font-normal"> + {extraCount} more</span>
                            )}
                          </p>
                        </div>
                      )}

                      <div className="mt-2 flex flex-wrap gap-3 text-xs text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <Icon name="store" size="sm" />
                          {item.store?.name || "Unknown shop"}
                        </span>
                        {item.buyer && (item.buyer.name || item.buyer.email) && (
                          <span className="flex items-center gap-1">
                            <Icon name="user" size="sm" />
                            {item.buyer.name || item.buyer.email}
                          </span>
                        )}
                      </div>
                    </div>

                    <div className="text-right bg-primary/5 rounded-xl px-4 py-3">
                      <p className="font-bold text-xl text-primary">{formatPrice(item.fee)}</p>
                      {item.distanceKm ? (
                        <p className="text-xs text-muted-foreground flex items-center justify-end gap-1 mt-1">
                          <Icon name="road" size="sm" />
                          {item.distanceKm.toFixed(1)} km
                        </p>
                      ) : null}
                    </div>
                  </div>

                  <div className="mt-4 space-y-3">
                    <div className="flex items-start gap-3 p-3 bg-muted/40 rounded-xl">
                      <div className="w-10 h-10 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center flex-shrink-0">
                        <Icon name="map-pin" className="text-green-600" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-1">Dropoff Location</p>
                        <p className="text-sm font-medium leading-relaxed">
                          {formatDropoffAddress(item.shippingAddress, item.municipalityName)}
                        </p>
                      </div>
                    </div>

                    {(item.proofPhotoUrl || item.proofNote) && (
                      <div className="flex items-start gap-3 p-3 bg-blue-50/50 dark:bg-blue-900/10 rounded-xl border border-blue-100 dark:border-blue-900/20">
                        <div className="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center flex-shrink-0">
                          <Icon name="camera" className="text-blue-600" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">Proof of Delivery</p>
                          {item.proofPhotoUrl && (
                            (() => {
                              const resolvedUrl = resolveImageUrl(item.proofPhotoUrl)
                              return resolvedUrl ? (
                                <a
                                  href={resolvedUrl}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="group inline-flex items-center gap-3 text-sm text-primary hover:text-primary/80 transition-colors"
                                >
                                  <div className="relative w-16 h-16 rounded-lg overflow-hidden border-2 border-primary/20 group-hover:border-primary/40 transition-colors bg-muted flex-shrink-0">
                                    <img
                                      src={resolvedUrl}
                                      alt="Proof of delivery"
                                      className="w-full h-full object-cover"
                                      onError={(e) => {
                                        const target = e.target as HTMLImageElement;
                                        target.style.display = 'none';
                                        const parent = target.parentElement;
                                        if (parent) {
                                          parent.innerHTML = '<div class="w-full h-full flex items-center justify-center"><span class="text-xs text-muted-foreground">No image</span></div>';
                                        }
                                      }}
                                    />
                                  </div>
                                  <span className="group-hover:underline">View delivery photo</span>
                                </a>
                              ) : (
                                <p className="text-sm text-muted-foreground">Photo unavailable</p>
                              )
                            })()
                          )}
                          {item.proofNote && (
                            <p className="text-sm text-muted-foreground mt-2 bg-white dark:bg-background rounded-lg p-2 border">
                              <span className="font-medium text-foreground">Rider note:</span> {item.proofNote}
                            </p>
                          )}
                        </div>
                      </div>
                    )}
                  </div>

                  {item.orderId != null && (
                    <div className="mt-4 flex flex-wrap gap-2 border-t pt-4">
                      {item.store?.id != null && (
                        <ReportLinkButton
                          reporterRole="rider"
                          params={{
                            targetRole: "seller",
                            storeId: item.store.id,
                            orderId: item.orderId,
                            label: item.store.name ?? undefined,
                          }}
                        >
                          Report seller
                        </ReportLinkButton>
                      )}
                      {item.buyer?.id != null && (
                        <ReportLinkButton
                          reporterRole="rider"
                          params={{
                            targetRole: "buyer",
                            targetUserId: item.buyer.id,
                            orderId: item.orderId,
                            label: item.buyer.name ?? undefined,
                          }}
                        >
                          Report buyer
                        </ReportLinkButton>
                      )}
                    </div>
                  )}
                </motion.div>
              )
            })}
          </motion.div>
        </AnimatePresence>
      )}
    </div>
  )
}
