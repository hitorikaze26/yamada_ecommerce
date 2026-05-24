"use client"

import { useState, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { toast } from "sonner"
import { sellerApi } from "@/lib/api"
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
  PieChart,
  Pie,
  Cell,
} from "recharts"

const COLORS = ["#F5A3B5", "#1B365D", "#E8D5B7", "#8B4D62", "#6B7280"]

interface AnalyticsData {
  period: string
  summary: {
    totalRevenue: number
    totalOrders: number
    totalCustomers: number
    avgOrderValue: number
    revenueGrowth: number
    ordersGrowth: number
  }
  salesChart: { name: string; sales: number; orders: number }[]
  topProducts: { name: string; revenue: number; quantitySold: number; growth: number }[]
  categoryData: { name: string; value: number }[]
}

export default function AnalyticsPage() {
  const [timeRange, setTimeRange] = useState("30d")
  const [data, setData] = useState<AnalyticsData | null>(null)
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
      const res = await sellerApi.getAnalytics(days)
      setData(res.data)
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
      const res = await sellerApi.downloadReport(days, "pdf")
      
      // Create blob and download
      const blob = new Blob([res.data], { type: "application/pdf" })
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      link.download = `analytics-report-${timeRange}.pdf`
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
    }).format(price)
  }

  const formatFullPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  const StatCard = ({ 
    icon, 
    label, 
    value, 
    growth, 
    color 
  }: { 
    icon: string; 
    label: string; 
    value: string; 
    growth: number; 
    color: string 
  }) => (
    <div className="bg-card border rounded-2xl p-6">
      <div className="flex items-center justify-between mb-4">
        <Icon name={icon} className={color} />
        <span className={`text-sm font-medium ${growth >= 0 ? "text-green-500" : "text-red-500"}`}>
          {growth >= 0 ? "+" : ""}{growth.toFixed(1)}%
        </span>
      </div>
      {isLoading ? (
        <Skeleton className="h-8 w-32" />
      ) : (
        <p className="text-2xl font-bold">{value}</p>
      )}
      <p className="text-sm text-muted-foreground">{label}</p>
    </div>
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">Analytics</h1>
          <p className="text-muted-foreground">Track your shop performance and insights.</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex gap-2">
            {[
              { key: "7d", label: "7 Days" },
              { key: "30d", label: "30 Days" },
              { key: "90d", label: "90 Days" },
              { key: "1y", label: "1 Year" },
            ].map((range) => (
              <button
                key={range.key}
                onClick={() => setTimeRange(range.key)}
                className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
                  timeRange === range.key
                    ? "bg-primary text-primary-foreground"
                    : "bg-muted hover:bg-muted/80"
                }`}
                disabled={isLoading}
              >
                {range.label}
              </button>
            ))}
          </div>
          <Button
            onClick={downloadReport}
            disabled={isLoading || isDownloading}
            variant="outline"
            className="gap-2"
          >
            {isDownloading ? (
              <Icon name="arrow-path" className="animate-spin" size="sm" />
            ) : (
              <Icon name="arrow-down-tray" size="sm" />
            )}
            Download PDF
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon="peso-sign"
          label="Total Revenue"
          value={formatFullPrice(data?.summary?.totalRevenue || 0)}
          growth={data?.summary?.revenueGrowth || 0}
          color="text-green-500"
        />
        <StatCard
          icon="shopping-bag"
          label="Total Orders"
          value={(data?.summary?.totalOrders || 0).toString()}
          growth={data?.summary?.ordersGrowth || 0}
          color="text-blue-500"
        />
        <StatCard
          icon="users"
          label="Customers"
          value={(data?.summary?.totalCustomers || 0).toString()}
          growth={0}
          color="text-purple-500"
        />
        <StatCard
          icon="chart-line"
          label="Avg. Order Value"
          value={formatFullPrice(data?.summary?.avgOrderValue || 0)}
          growth={0}
          color="text-amber-500"
        />
      </div>

      {/* Charts Row */}
      <div className="grid lg:grid-cols-2 gap-6">
        {/* Sales Chart */}
        <div className="bg-card border rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-6">Sales Overview</h2>
          <div className="h-[300px]">
            {isLoading ? (
              <Skeleton className="h-full w-full rounded-xl" />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data?.salesChart || []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--muted))" />
                  <XAxis 
                    dataKey="name" 
                    tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} 
                  />
                  <YAxis
                    tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }}
                    tickFormatter={(v) => `₱${(v / 1000).toFixed(0)}k`}
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "12px",
                    }}
                    formatter={(value: number) => [formatFullPrice(value), "Sales"]}
                  />
                  <Line
                    type="monotone"
                    dataKey="sales"
                    stroke="hsl(var(--primary))"
                    strokeWidth={2}
                    dot={{ r: 4 }}
                    activeDot={{ r: 6 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>

        {/* Orders Chart */}
        <div className="bg-card border rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-6">Orders Trend</h2>
          <div className="h-[300px]">
            {isLoading ? (
              <Skeleton className="h-full w-full rounded-xl" />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data?.salesChart || []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--muted))" />
                  <XAxis 
                    dataKey="name" 
                    tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} 
                  />
                  <YAxis 
                    tick={{ fill: "hsl(var(--muted-foreground))", fontSize: 12 }} 
                  />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "hsl(var(--card))",
                      border: "1px solid hsl(var(--border))",
                      borderRadius: "12px",
                    }}
                  />
                  <Bar dataKey="orders" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>

      {/* Bottom Row */}
      <div className="grid lg:grid-cols-3 gap-6">
        {/* Category Breakdown */}
        <div className="bg-card border rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-6">Sales by Category</h2>
          <div className="h-[200px]">
            {isLoading ? (
              <Skeleton className="h-full w-full rounded-xl" />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={data?.categoryData || []}
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={80}
                    paddingAngle={5}
                    dataKey="value"
                  >
                    {(data?.categoryData || []).map((_, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value: number) => `${value}%`} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </div>
          <div className="flex flex-wrap gap-3 mt-4 justify-center">
            {isLoading ? (
              <Skeleton className="h-4 w-32" />
            ) : (
              (data?.categoryData || []).map((item, index) => (
                <div key={item.name} className="flex items-center gap-2">
                  <div className="w-3 h-3 rounded-full" style={{ backgroundColor: COLORS[index] }} />
                  <span className="text-xs text-muted-foreground">{item.name}</span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Top Products */}
        <div className="lg:col-span-2 bg-card border rounded-2xl p-6">
          <h2 className="text-lg font-semibold mb-6">Top Performing Products</h2>
          <div className="space-y-4">
            {isLoading ? (
              Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex items-center gap-4">
                  <Skeleton className="h-8 w-8" />
                  <div className="flex-1">
                    <Skeleton className="h-4 w-48 mb-2" />
                    <Skeleton className="h-3 w-32" />
                  </div>
                  <Skeleton className="h-4 w-16" />
                </div>
              ))
            ) : (data?.topProducts || []).length === 0 ? (
              <p className="text-muted-foreground text-center py-8">No sales data available for this period</p>
            ) : (
              (data?.topProducts || []).map((product, index) => (
                <div key={product.name} className="flex items-center gap-4">
                  <span className="text-2xl font-bold text-muted-foreground w-8">
                    #{index + 1}
                  </span>
                  <div className="flex-1">
                    <p className="font-medium">{product.name}</p>
                    <p className="text-sm text-muted-foreground">
                      {formatFullPrice(product.revenue)} revenue • {product.quantitySold} sold
                    </p>
                  </div>
                  <div
                    className={`flex items-center gap-1 ${
                      product.growth >= 0 ? "text-green-500" : "text-red-500"
                    }`}
                  >
                    {product.growth !== 0 && (
                      <Icon
                        name={product.growth >= 0 ? "arrow-up" : "arrow-down"}
                        size="sm"
                      />
                    )}
                    <span className="font-medium">
                      {product.growth !== 0 ? `${Math.abs(product.growth)}%` : "-"}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
