"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { riderApi } from "@/lib/api"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"

const kPrimaryPink = "#E891A0"
const kGreenOnline = "#4CAF50"

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
  pickup?: string
  dropoff?: string
  isAutoMatched?: boolean
}

export default function RiderMobileDashboard() {
  const { user, isVerified } = useAuth()
  const [isOnline, setIsOnline] = useState(true)
  const [stats, setStats] = useState<RiderStats | null>(null)
  const [recentDeliveries, setRecentDeliveries] = useState<RiderDeliverySummary[]>([])
  const [isLoading, setIsLoading] = useState(true)

  const greeting = () => {
    const hour = new Date().getHours()
    if (hour < 12) return "Good Morning"
    if (hour < 17) return "Good Afternoon"
    return "Good Evening"
  }

  useEffect(() => {
    if (!isVerified()) {
      setIsLoading(false)
      setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
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

        setStats(statsData ?? { todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
        setRecentDeliveries(deliveriesData.slice(0, 3))
      } catch {
        setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
      } finally {
        setIsLoading(false)
      }
    }

    void loadData()
  }, [])

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "pending":
        return "bg-amber-100 text-amber-700"
      case "pickup":
        return "bg-blue-100 text-blue-700"
      case "transit":
        return "bg-purple-100 text-purple-700"
      case "delivered":
        return "bg-green-100 text-green-700"
      default:
        return "bg-gray-100 text-gray-700"
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status.toLowerCase()) {
      case "pickup":
        return "Ready for Pickup"
      case "transit":
        return "In Transit"
      case "pending":
        return "Shipped"
      default:
        return status
    }
  }

  return (
    <div className="p-4 space-y-6">
      {/* Header with greeting and online toggle */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-lg font-semibold dark:text-white">
            {greeting()}, {user?.givenName || "Rider"}!
          </h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Ready for today&apos;s deliveries?</p>
        </div>
        <button
          onClick={() => setIsOnline(!isOnline)}
          className={`flex items-center gap-2 px-4 py-2 rounded-full transition-all ${
            isOnline ? "bg-green-500 text-white" : "bg-gray-300 text-gray-700"
          }`}
        >
          <span className={`w-2 h-2 rounded-full ${isOnline ? "bg-white" : "bg-gray-500"}`} />
          <span className="text-sm font-medium">{isOnline ? "Online" : "Offline"}</span>
        </button>
      </div>

      {/* Not verified notice */}
      {!isVerified() && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="font-semibold text-amber-900 mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. You can log in, but deliveries and earnings will be
            available only after an admin approves your account.
          </p>
        </div>
      )}

      {/* Stats Grid - Pink cards */}
      <div className="grid grid-cols-2 gap-3">
        <div
          className="rounded-2xl p-4 text-white shadow-lg"
          style={{ backgroundColor: kPrimaryPink }}
        >
          <svg className="w-6 h-6 mb-3 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0" />
          </svg>
          <p className="text-2xl font-bold">{stats?.todayDeliveries ?? 0}</p>
          <p className="text-xs opacity-90 mt-1">Today&apos;s Deliveries</p>
        </div>

        <div
          className="rounded-2xl p-4 text-white shadow-lg"
          style={{ backgroundColor: kPrimaryPink }}
        >
          <svg className="w-6 h-6 mb-3 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-2xl font-bold">{stats?.completed ?? 0}</p>
          <p className="text-xs opacity-90 mt-1">Completed</p>
        </div>

        <div
          className="rounded-2xl p-4 text-white shadow-lg"
          style={{ backgroundColor: kPrimaryPink }}
        >
          <svg className="w-6 h-6 mb-3 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-2xl font-bold">{stats?.pending ?? 0}</p>
          <p className="text-xs opacity-90 mt-1">Pending</p>
        </div>

        <div
          className="rounded-2xl p-4 text-white shadow-lg"
          style={{ backgroundColor: kPrimaryPink }}
        >
          <svg className="w-6 h-6 mb-3 opacity-90" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
          </svg>
          <p className="text-2xl font-bold">₱{(stats?.earnings ?? 0).toLocaleString()}</p>
          <p className="text-xs opacity-90 mt-1">Today&apos;s Earnings</p>
        </div>
      </div>

      {/* Recent Deliveries */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold dark:text-white">Recent Deliveries</h2>
          <Link
            href="/rider/mobile/deliveries"
            className="text-sm font-medium"
            style={{ color: kPrimaryPink }}
          >
            View All
          </Link>
        </div>

        {!isVerified() ? (
          <div className="bg-gray-100 dark:bg-gray-800 rounded-xl p-4 text-sm text-gray-600 dark:text-gray-400">
            Deliveries will appear here once your rider account is verified.
          </div>
        ) : isLoading ? (
          <div className="flex justify-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: kPrimaryPink }} />
          </div>
        ) : recentDeliveries.length === 0 ? (
          <div className="bg-gray-100 dark:bg-gray-800 rounded-xl p-4 text-sm text-gray-600 dark:text-gray-400">
            No recent deliveries.
          </div>
        ) : (
          <div className="space-y-3">
            {recentDeliveries.map((delivery) => (
              <div key={delivery.id} className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm dark:shadow-gray-900">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-sm dark:text-white">{riderDeliveryLabel(delivery)}</span>
                    <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(delivery.status)}`}>
                      {getStatusLabel(delivery.status)}
                    </span>
                  </div>
                  <span className="font-bold" style={{ color: kPrimaryPink }}>
                    ₱{delivery.fee.toFixed(0)}
                  </span>
                </div>

                {delivery.distanceKm > 0 && (
                  <p className="text-xs text-gray-500 dark:text-gray-400 mb-3">{delivery.distanceKm.toFixed(1)} km</p>
                )}

                {/* Pickup */}
                <div className="flex items-center gap-3 mb-2">
                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: `${kPrimaryPink}20` }}
                  >
                    <svg className="w-4 h-4" style={{ color: kPrimaryPink }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                    </svg>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs text-gray-500 dark:text-gray-400">Pickup</p>
                    <p className="text-sm font-medium dark:text-gray-300 truncate">{delivery.pickup || "Store location"}</p>
                  </div>
                </div>

                {/* Dropoff */}
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center">
                    <svg className="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs text-gray-500 dark:text-gray-400">Dropoff</p>
                    <p className="text-sm font-medium dark:text-gray-300 truncate">{delivery.dropoff || "Customer address"}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
