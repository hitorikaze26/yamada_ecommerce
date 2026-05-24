"use client"
import { useEffect, useState } from "react"
import Link from "next/link"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { riderApi } from "@/lib/api"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"
interface RiderStats {
  todayDeliveries: number
  completed: number
  pending: number
  earnings: number
}

interface RiderDeliverySummary {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  orderId: number | null
  status: string
  fee: number
  distanceKm: number
  createdAt: string | null
  pickup?: string
  dropoff?: string
  isAutoMatched?: boolean
}

const statusColors: Record<string, { bg: string; text: string }> = {
  pending: { bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-700 dark:text-amber-400" },
  pickup: { bg: "bg-blue-100 dark:bg-blue-900/30", text: "text-blue-700 dark:text-blue-400" },
  transit: { bg: "bg-purple-100 dark:bg-purple-900/30", text: "text-purple-700 dark:text-purple-400" },
  delivered: { bg: "bg-green-100 dark:bg-green-900/30", text: "text-green-700 dark:text-green-400" },
}

export default function RiderDashboard() {
  const { isVerified } = useAuth()
  const [isOnline, setIsOnline] = useState(true)
  const [stats, setStats] = useState<RiderStats | null>(null)
  const [recentDeliveries, setRecentDeliveries] = useState<RiderDeliverySummary[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!isVerified()) {
      setIsLoading(false)
      setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
      setRecentDeliveries([])
      return
    }

    const loadData = async () => {
      try {
        const [statsRes, deliveriesRes] = await Promise.all([
          riderApi.getDashboard(),
          riderApi.getDeliveries(),
        ])

        const statsData = (statsRes.data as any)?.stats as RiderStats | undefined
        const deliveriesData = ((deliveriesRes.data as any)?.deliveries || []) as RiderDeliverySummary[]

        if (statsData) {
          setStats(statsData)
        } else {
          setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
        }

        // Show the most recent few deliveries in the dashboard list
        setRecentDeliveries(deliveriesData.slice(0, 3))
      } catch (e) {
        setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
        setRecentDeliveries([])
      } finally {
        setIsLoading(false)
      }
    }

    void loadData()
  }, [])

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">Good Morning, Juan!</h1>
          <p className="text-muted-foreground">Ready for today&apos;s deliveries?</p>
        </div>
        <button
          onClick={() => setIsOnline(!isOnline)}
          className={`flex items-center gap-3 px-6 py-3 rounded-xl font-medium transition-colors ${
            isOnline ? "bg-green-500 text-white" : "bg-muted text-muted-foreground"
          }`}
        >
          <span className={`w-3 h-3 rounded-full ${isOnline ? "bg-white animate-pulse" : "bg-gray-400"}`} />
          {isOnline ? "Online" : "Offline"}
        </button>
      </div>

      {/* If not verified, show approval notice and skip stats/deliveries */}
      {!isVerified() && (
        <div className="bg-amber-50 border border-amber-200 text-amber-900 rounded-2xl p-4 text-sm">
          <p className="font-semibold mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. You can log in, but deliveries and earnings will
            be available only after an admin approves your account.
          </p>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card border rounded-2xl p-6"
        >
          <div className="w-12 h-12 rounded-xl bg-primary flex items-center justify-center mb-4">
            <Icon name="truck-container" className="text-primary-foreground" />
          </div>
          <p className="text-2xl font-bold">{stats?.todayDeliveries ?? 0}</p>
          <p className="text-sm text-muted-foreground">Today&apos;s Deliveries</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card border rounded-2xl p-6"
        >
          <div className="w-12 h-12 rounded-xl bg-primary flex items-center justify-center mb-4">
            <Icon name="check-circle" className="text-primary-foreground" />
          </div>
          <p className="text-2xl font-bold">{stats?.completed ?? 0}</p>
          <p className="text-sm text-muted-foreground">Completed</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card border rounded-2xl p-6"
        >
          <div className="w-12 h-12 rounded-xl bg-primary flex items-center justify-center mb-4">
            <Icon name="clock" className="text-primary-foreground" />
          </div>
          <p className="text-2xl font-bold">{stats?.pending ?? 0}</p>
          <p className="text-sm text-muted-foreground">Pending</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-card border rounded-2xl p-6"
        >
          <div className="w-12 h-12 rounded-xl bg-primary flex items-center justify-center mb-4">
            <Icon name="peso-sign" className="text-primary-foreground" />
          </div>
          <p className="text-2xl font-bold">
            ₱{(stats?.earnings ?? 0).toLocaleString("en-PH", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}
          </p>
          <p className="text-sm text-muted-foreground">Today&apos;s Earnings</p>
        </motion.div>
      </div>

      {/* Pending Deliveries */}
      <div className="bg-card border rounded-2xl p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold">Pending Deliveries</h2>
          <Link href="/rider/deliveries" className="text-primary hover:underline text-sm font-medium">
            View All
          </Link>
        </div>

        <div className="space-y-4">
          {!isVerified() ? (
            <div className="border rounded-xl p-4 text-sm text-muted-foreground">
              Deliveries will appear here once your rider account is verified.
            </div>
          ) : (
            <>
              {isLoading && recentDeliveries.length === 0 && (
                <div className="border rounded-xl p-4 text-sm text-muted-foreground">Loading deliveries...</div>
              )}
              {!isLoading && recentDeliveries.length === 0 && (
                <div className="border rounded-xl p-4 text-sm text-muted-foreground">No recent deliveries.</div>
              )}
            </>
          )}

          {isVerified() && recentDeliveries.map((delivery) => (
            <div key={delivery.id} className="border rounded-xl p-4">
              <div className="flex flex-wrap items-start justify-between gap-4 mb-4">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <p className="font-semibold">{riderDeliveryLabel(delivery)}</p>
                    <span
                      className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${statusColors[delivery.status].bg} ${statusColors[delivery.status].text}`}
                    >
                      {delivery.status === "pickup" ? "Ready for Pickup" : delivery.status}
                    </span>
                  </div>
                  <p className="text-sm text-muted-foreground">{delivery.orderId}</p>
                </div>
                <div className="text-right">
                  <p className="font-bold text-lg">₱{delivery.fee.toFixed(0)}</p>
                  {delivery.distanceKm ? (
                    <p className="text-sm text-muted-foreground">{delivery.distanceKm.toFixed(1)} km</p>
                  ) : null}
                </div>
              </div>

              <div className="space-y-3 mb-4">
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Icon name="store" size="sm" className="text-primary" />
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Pickup</p>
                    <p className="text-sm font-medium">{delivery.pickup}</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center flex-shrink-0">
                    <Icon name="map-marker-alt" size="sm" className="text-green-500" />
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Dropoff</p>
                    <p className="text-sm font-medium">{delivery.dropoff}</p>
                  </div>
                </div>
              </div>

              {/* Hide action buttons for auto-matched (unaccepted) deliveries.
                  Buttons only show once the delivery is explicitly assigned
                  to this rider (isAutoMatched is false/undefined). */}
              {!delivery.isAutoMatched && (
                <div className="flex flex-wrap gap-2">
                  <a
                    href={`tel:${(delivery as any).phone ?? ""}`}
                    className="flex items-center gap-2 px-4 py-2 bg-muted rounded-lg text-sm font-medium hover:bg-muted/80 transition-colors"
                  >
                    <Icon name="phone" size="sm" />
                    Call Customer
                  </a>
                  <button
                    onClick={() => {
                      const dest = delivery.dropoff || delivery.pickup || ""
                      if (dest) window.open(`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(dest)}`, "_blank")
                    }}
                    className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors"
                  >
                    <Icon name="directions" size="sm" />
                    Navigate
                  </button>
                  {delivery.status === "pickup" && (
                    <button className="flex items-center gap-2 px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600 transition-colors ml-auto">
                      <Icon name="check" size="sm" />
                      Picked Up
                    </button>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
