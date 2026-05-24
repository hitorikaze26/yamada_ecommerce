"use client"

import { useEffect, useMemo, useState } from "react"
import { Icon } from "@/components/ui/icon"
import { riderDeliveryLabel } from "@/lib/rider-delivery"
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts"

import { riderApi } from "@/lib/api"
import { useAuth } from "@/context/auth-context"

interface RiderStats {
  todayDeliveries: number
  completed: number
  pending: number
  earnings: number
}

interface RiderEarningsPoint {
  day: string
  earnings: number
  deliveries: number
}

interface RiderDeliveryForEarnings {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  orderId?: number | null
  isAutoMatched?: boolean
  fee: number
  createdAt: string | null
  status: string
}

function buildSeries(deliveries: RiderDeliveryForEarnings[], days: number): RiderEarningsPoint[] {
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

export default function RiderEarningsPage() {
  const { isVerified } = useAuth()
  const [timeRange, setTimeRange] = useState<"week" | "month">("week")
  const [stats, setStats] = useState<RiderStats | null>(null)
  const [allDeliveries, setAllDeliveries] = useState<RiderDeliveryForEarnings[]>([])
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
        const deliveriesData = ((deliveriesRes.data as any)?.deliveries || []) as RiderDeliveryForEarnings[]

        setStats(
          statsData ?? {
            todayDeliveries: 0,
            completed: 0,
            pending: 0,
            earnings: 0,
          },
        )

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

  const totalEarnings = chartData.reduce((acc, d) => acc + d.earnings, 0)
  const totalDeliveries = chartData.reduce((acc, d) => acc + d.deliveries, 0)
  const avgPerDelivery = totalDeliveries > 0 ? totalEarnings / totalDeliveries : 0

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
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    })
  }

  if (!isVerified()) {
    return (
      <div className="space-y-4">
        <h1 className="text-3xl font-bold mb-2">Earnings</h1>
        <div className="bg-amber-50 border border-amber-200 text-amber-900 rounded-2xl p-4 text-sm">
          <p className="font-semibold mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. Earnings will appear here once an admin approves your account.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Earnings</h1>
        <p className="text-muted-foreground">Track your delivery earnings and performance.</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-card border rounded-2xl p-6">
          <Icon name="peso-sign" className="text-green-500 mb-4" />
          <p className="text-2xl font-bold">{formatPrice(stats?.earnings ?? 0)}</p>
          <p className="text-sm text-muted-foreground">Today&apos;s Earnings</p>
        </div>
        <div className="bg-card border rounded-2xl p-6">
          <Icon name="truck-check" className="text-blue-500 mb-4" />
          <p className="text-2xl font-bold">{stats?.todayDeliveries ?? 0}</p>
          <p className="text-sm text-muted-foreground">Today&apos;s Deliveries</p>
        </div>
        <div className="bg-card border rounded-2xl p-6">
          <Icon name="check-circle" className="text-purple-500 mb-4" />
          <p className="text-2xl font-bold">{stats?.completed ?? 0}</p>
          <p className="text-sm text-muted-foreground">Completed</p>
        </div>
        <div className="bg-card border rounded-2xl p-6">
          <Icon name="calculator" className="text-amber-500 mb-4" />
          <p className="text-2xl font-bold">{formatPrice(avgPerDelivery)}</p>
          <p className="text-sm text-muted-foreground">
            Avg per Delivery (last {days} days)
          </p>
        </div>
      </div>

      <div className="bg-card border rounded-2xl p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold">Earnings Overview</h2>
          <div className="flex gap-2">
            {["week", "month"].map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range as "week" | "month")}
                className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-colors ${
                  timeRange === range ? "bg-blue-500 text-white" : "bg-muted hover:bg-muted/80"
                }`}
              >
                {range}
              </button>
            ))}
          </div>
        </div>

        <div className="h-[300px]">
          {isLoading ? (
            <div className="flex items-center justify-center h-full text-sm text-muted-foreground">
              Loading earnings...
            </div>
          ) : chartData.length === 0 ? (
            <div className="flex items-center justify-center h-full text-sm text-muted-foreground">
              No earnings data for the selected period.
            </div>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="day" className="text-muted-foreground" tick={{ fontSize: 12 }} />
                <YAxis className="text-muted-foreground" tick={{ fontSize: 12 }} tickFormatter={(v) => `₱${v}`} />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "hsl(var(--card))",
                    border: "1px solid hsl(var(--border))",
                    borderRadius: "12px",
                  }}
                  formatter={(value: number) => [formatPrice(value as number), "Earnings"]}
                />
                <Bar dataKey="earnings" fill="#3B82F6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {sortedHistory.length > 0 && (
        <div className="bg-card border rounded-2xl p-6">
          <h2 className="text-xl font-semibold mb-4">Earnings History</h2>
          <div className="divide-y">
            {sortedHistory.map((delivery) => (
              <div key={delivery.id} className="flex items-center justify-between py-3">
                <div>
                  <p className="text-sm font-medium">{riderDeliveryLabel(delivery)}</p>
                  <p className="text-xs text-muted-foreground">
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
