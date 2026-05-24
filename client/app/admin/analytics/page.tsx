"use client"

import { useState, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { toast } from "sonner"
import { adminApi } from "@/lib/api"
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  AreaChart,
  Area,
} from "recharts"

interface AdminAnalyticsData {
  period: string
  summary: {
    totalRevenue: number
    totalOrders: number
    totalUsers: number
    totalSellers: number
    revenueGrowth: number
    ordersGrowth: number
    totalCommissionEarned: number
  }
  salesChart: { name: string; revenue: number; orders: number }[]
  userGrowth: { name: string; users: number; sellers: number }[]
}

export default function AdminAnalyticsPage() {
  const [timeRange, setTimeRange] = useState("30d")
  const [data, setData] = useState<AdminAnalyticsData | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isDownloading, setIsDownloading] = useState(false)

  const daysMap: Record<string, number> = {
    "7d": 7,
    "30d": 30,
    "90d": 90,
    "1y": 365,
  }

  const fetchAnalytics = async () => {
    try {
      setIsLoading(true)
      const days = daysMap[timeRange] || 30
      const [analyticsRes, commissionRes] = await Promise.all([
        adminApi.getAnalytics(days),
        adminApi.getCommissionAnalytics().catch(() => null),
      ])

      const analyticsData = analyticsRes.data
      const commissionData = commissionRes?.data ?? null

      setData({
        ...analyticsData,
        summary: {
          ...analyticsData.summary,
          totalCommissionEarned: commissionData?.totalCommissionEarned ?? 0,
        },
      })
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to load analytics")
    } finally {
      setIsLoading(false)
    }
  }

  const downloadReport = async () => {
    try {
      setIsDownloading(true)
      const days = daysMap[timeRange] || 30
      const res = await adminApi.downloadReport(days, "pdf")
      
      const blob = new Blob([res.data], { type: "application/pdf" })
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      link.download = `admin-analytics-report-${timeRange}.pdf`
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      
      toast.success("Report downloaded successfully")
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to download report")
    } finally {
      setIsDownloading(false)
    }
  }

  useEffect(() => {
    fetchAnalytics()
  }, [timeRange])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
      notation: "compact",
    }).format(price || 0)
  }

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat("en-PH").format(num || 0)
  }

  const StatCard = ({
    label,
    value,
    icon,
    color,
    growth,
  }: {
    label: string
    value: string
    icon: string
    color: string
    growth?: number
  }) => (
    <div className="bg-card rounded-xl p-6 border shadow-sm">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-muted-foreground">{label}</p>
          <p className="text-2xl font-bold mt-1">{value}</p>
          {growth !== undefined && (
            <p className={`text-xs mt-1 ${growth >= 0 ? "text-green-600" : "text-red-600"}`}>
              {growth >= 0 ? "+" : ""}{growth.toFixed(1)}% from previous period
            </p>
          )}
        </div>
        <div className={`w-12 h-12 rounded-lg ${color} flex items-center justify-center`}>
          <Icon name={icon} className="text-white" />
        </div>
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-pink-400 to-pink-600 flex items-center justify-center shadow-lg">
            <Icon name="chart-histogram" className="text-white text-xl" />
          </div>
          <div>
            <h1 className="text-2xl font-bold">Analytics</h1>
            <p className="text-muted-foreground">Platform-wide performance metrics</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value)}
            className="px-3 py-2 rounded-lg border bg-background text-sm"
          >
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
            <option value="90d">Last 90 days</option>
            <option value="1y">Last year</option>
          </select>
          <Button
            variant="outline"
            onClick={downloadReport}
            disabled={isDownloading || isLoading}
          >
            <Icon name={isDownloading ? "spinner" : "file-download"} className="mr-2" />
            {isDownloading ? "Downloading..." : "Download Report"}
          </Button>
        </div>
      </div>

      {/* Stats Grid */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {Array.from({ length: 2 }).map((_, i) => (
            <Skeleton key={i} className="h-28" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <StatCard
            label="Total Revenue"
            value={formatPrice(data?.summary?.totalRevenue || 0)}
            icon="coins"
            color="bg-green-500"
            growth={data?.summary?.revenueGrowth}
          />
          <StatCard
            label="Commission Earned"
            value={formatPrice(data?.summary?.totalCommissionEarned || 0)}
            icon="percentage"
            color="bg-blue-500"
          />
        </div>
      )}

      {/* Secondary Stats */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-20" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard
            label="Total Orders"
            value={formatNumber(data?.summary?.totalOrders || 0)}
            icon="shopping-bag"
            color="bg-green-500"
            growth={data?.summary?.ordersGrowth}
          />
          <StatCard
            label="Total Users"
            value={formatNumber(data?.summary?.totalUsers || 0)}
            icon="users"
            color="bg-blue-500"
          />
          <StatCard
            label="Total Sellers"
            value={formatNumber(data?.summary?.totalSellers || 0)}
            icon="shop"
            color="bg-purple-500"
          />
        </div>
      )}

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Sales Chart */}
        <div className="bg-card rounded-xl p-6 border shadow-sm">
          <h3 className="font-semibold mb-4">Revenue & Orders</h3>
          {isLoading ? (
            <Skeleton className="h-64" />
          ) : (
            <ResponsiveContainer width="100%" height={256}>
              <AreaChart data={data?.salesChart || []}>
                <defs>
                  <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#F5A3B5" stopOpacity={0.8} />
                    <stop offset="95%" stopColor="#F5A3B5" stopOpacity={0.1} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="name" fontSize={12} />
                <YAxis fontSize={12} />
                <Tooltip />
                <Area
                  type="monotone"
                  dataKey="revenue"
                  stroke="#F5A3B5"
                  fillOpacity={1}
                  fill="url(#colorRevenue)"
                  name="Revenue"
                />
                <Line
                  type="monotone"
                  dataKey="orders"
                  stroke="#1B365D"
                  strokeWidth={2}
                  name="Orders"
                />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>

        {/* User Growth Chart */}
        <div className="bg-card rounded-xl p-6 border shadow-sm">
          <h3 className="font-semibold mb-4">User & Seller Growth</h3>
          {isLoading ? (
            <Skeleton className="h-64" />
          ) : (
            <ResponsiveContainer width="100%" height={256}>
              <BarChart data={data?.userGrowth || []}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="name" fontSize={12} />
                <YAxis fontSize={12} />
                <Tooltip />
                <Bar dataKey="users" fill="#F5A3B5" name="Users" />
                <Bar dataKey="sellers" fill="#1B365D" name="Sellers" />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

    </div>
  )
}
