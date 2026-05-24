"use client"

import { useEffect, useMemo, useState } from "react"
import { riderApi } from "@/lib/api"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"

const kPrimaryPink = "#E891A0"
const kBlue = "#3B82F6"

type TimeRange = "week" | "month"

interface RiderStats {
  todayDeliveries: number
  completed: number
  pending: number
  earnings: number
}

interface EarningsPoint {
  day: string
  earnings: number
  deliveries: number
}

interface DeliveryRecord {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  orderId?: number | null
  isAutoMatched?: boolean
  fee: number
  createdAt: string | null
  status: string
}

function buildSeries(deliveries: DeliveryRecord[], days: number): EarningsPoint[] {
  const now = new Date()
  const start = new Date(now)
  start.setDate(now.getDate() - (days - 1))

  const buckets: Record<string, { earnings: number; deliveries: number }> = {}
  for (let i = 0; i < days; i++) {
    const d = new Date(start)
    d.setDate(start.getDate() + i)
    buckets[d.toISOString().slice(0, 10)] = { earnings: 0, deliveries: 0 }
  }

  deliveries.forEach((delivery) => {
    if (!delivery.createdAt) return
    const d = new Date(delivery.createdAt)
    if (Number.isNaN(d.getTime())) return
    const key = d.toISOString().slice(0, 10)
    if (!buckets[key]) return
    buckets[key].earnings += delivery.fee || 0
    buckets[key].deliveries += 1
  })

  const weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  return Object.entries(buckets).map(([dateStr, value]) => {
    const d = new Date(dateStr)
    return {
      day: days > 7 ? dateStr.slice(5) : weekdayShort[d.getDay()],
      earnings: value.earnings,
      deliveries: value.deliveries,
    }
  })
}

export default function RiderMobileEarnings() {
  const { isVerified } = useAuth()
  const [timeRange, setTimeRange] = useState<TimeRange>("week")
  const [stats, setStats] = useState<RiderStats | null>(null)
  const [allDeliveries, setAllDeliveries] = useState<DeliveryRecord[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (!isVerified()) {
      setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
      setAllDeliveries([])
      setIsLoading(false)
      return
    }

    const load = async () => {
      try {
        const [statsRes, deliveriesRes] = await Promise.all([
          riderApi.getDashboard(),
          riderApi.getDeliveries(),
        ])

        const statsData = (statsRes.data as any)?.stats as RiderStats | undefined
        const deliveriesData = ((deliveriesRes.data as any)?.deliveries || []) as DeliveryRecord[]

        setStats(statsData ?? { todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
        setAllDeliveries(deliveriesData)
      } catch {
        setStats({ todayDeliveries: 0, completed: 0, pending: 0, earnings: 0 })
        setAllDeliveries([])
      } finally {
        setIsLoading(false)
      }
    }

    void load()
  }, [])

  const days = timeRange === "week" ? 7 : 30
  const chartData = useMemo(() => buildSeries(allDeliveries, days), [allDeliveries, days])

  const totalEarnings = useMemo(() => chartData.reduce((acc, d) => acc + d.earnings, 0), [chartData])
  const totalDeliveries = useMemo(() => chartData.reduce((acc, d) => acc + d.deliveries, 0), [chartData])
  const avgPerDelivery = useMemo(
    () => (totalDeliveries > 0 ? totalEarnings / totalDeliveries : 0),
    [totalEarnings, totalDeliveries]
  )

  const maxEarnings = Math.max(...chartData.map((d) => d.earnings), 1)

  const sortedHistory = useMemo(() => {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - days)
    return allDeliveries
      .filter((d) => {
        if (!d.createdAt) return false
        return new Date(d.createdAt) >= cutoff
      })
      .sort((a, b) => {
        if (!a.createdAt || !b.createdAt) return 0
        return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      })
  }, [allDeliveries, days])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(price)
  }

  const formatDate = (value: string | null) => {
    if (!value) return ""
    const d = new Date(value)
    if (Number.isNaN(d.getTime())) return value
    return d.toLocaleString("en-PH", { month: "short", day: "2-digit", hour: "2-digit", minute: "2-digit" })
  }

  return (
    <div className="p-4 space-y-4">
      <div>
        <h1 className="text-xl font-bold">Earnings</h1>
        <p className="text-sm text-gray-500">Track your delivery earnings</p>
      </div>

      {!isVerified() && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="font-semibold text-amber-900 mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. Earnings will appear here once an admin approves your account.
          </p>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <div className="bg-white rounded-xl p-4 shadow-sm">
          <svg className="w-6 h-6 text-green-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
          </svg>
          <p className="text-xl font-bold">{formatPrice(stats?.earnings ?? 0)}</p>
          <p className="text-xs text-gray-500">Today&apos;s Earnings</p>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm">
          <svg className="w-6 h-6 text-blue-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0" />
          </svg>
          <p className="text-xl font-bold">{stats?.todayDeliveries ?? 0}</p>
          <p className="text-xs text-gray-500">Today&apos;s Deliveries</p>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm">
          <svg className="w-6 h-6 text-purple-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-xl font-bold">{stats?.completed ?? 0}</p>
          <p className="text-xs text-gray-500">Completed</p>
        </div>
        <div className="bg-white rounded-xl p-4 shadow-sm">
          <svg className="w-6 h-6 text-orange-500 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          <p className="text-xl font-bold">{formatPrice(avgPerDelivery)}</p>
          <p className="text-xs text-gray-500">Avg per Delivery</p>
        </div>
      </div>

      <div className="bg-white rounded-xl p-4 shadow-sm">
        <div className="flex items-center justify-between mb-6">
          <h2 className="font-semibold">Earnings Overview</h2>
          <div className="flex gap-2">
            {(["week", "month"] as TimeRange[]).map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={`px-3 py-1 rounded-lg text-xs font-medium capitalize ${
                  timeRange === range ? "text-white" : "bg-gray-100 text-gray-600"
                }`}
                style={{ backgroundColor: timeRange === range ? kBlue : undefined }}
              >
                {range}
              </button>
            ))}
          </div>
        </div>

        <div className="h-48">
          {isLoading ? (
            <div className="flex items-center justify-center h-full">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: kPrimaryPink }} />
            </div>
          ) : chartData.length === 0 ? (
            <div className="flex items-center justify-center h-full text-sm text-gray-500">
              No earnings data available
            </div>
          ) : (
            <div className="flex items-end justify-around h-full pb-8 pt-4">
              {chartData.map((data, index) => {
                const barHeight = maxEarnings > 0 ? (data.earnings / maxEarnings) * 120 : 4
                return (
                  <div key={index} className="flex flex-col items-center">
                    <div
                      className="w-8 rounded-t-md transition-all duration-500"
                      style={{ height: `${Math.max(barHeight, 4)}px`, backgroundColor: kBlue }}
                    />
                    <span className="text-xs text-gray-500 mt-2">{data.day}</span>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>

      <div className="bg-gradient-to-r from-pink-50 to-pink-100 rounded-xl p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm text-gray-600">Total Earnings ({timeRange === "week" ? "7 Days" : "30 Days"})</p>
            <p className="text-2xl font-bold" style={{ color: kPrimaryPink }}>
              {formatPrice(totalEarnings)}
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-600">Deliveries</p>
            <p className="text-xl font-bold" style={{ color: kPrimaryPink }}>
              {totalDeliveries}
            </p>
          </div>
        </div>
      </div>

      {sortedHistory.length > 0 && (
        <div className="bg-white rounded-xl p-4 shadow-sm">
          <h2 className="font-semibold mb-3">Earnings History</h2>
          <div className="divide-y divide-gray-100">
            {sortedHistory.map((delivery) => (
              <div key={delivery.id} className="flex items-center justify-between py-3">
                <div>
                  <p className="text-sm font-medium">{riderDeliveryLabel(delivery)}</p>
                  <p className="text-xs text-gray-500">
                    {delivery.status === "delivered" ? "Completed" : delivery.status} · {formatDate(delivery.createdAt)}
                  </p>
                </div>
                <p className="text-sm font-semibold text-green-600">{formatPrice(delivery.fee)}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
