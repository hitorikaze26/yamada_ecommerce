"use client"
import { useEffect, useState } from "react"
import Link from "next/link"
import Image from "next/image"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { ordersApi, productsApi, reportsApi, resolveImageUrl } from "@/lib/api"
import type { Order, Product, ProblemReportDto } from "@/lib/types"
import { useAuth } from "@/context/auth-context"
import {
  BUYER_ORDER_FILTERS,
  countOrdersByBuyerFilter,
  type BuyerOrderFilterKey,
} from "@/lib/buyer/order-filters"
import { formatOrderStatusLabel, getEffectiveOrderStatus } from "@/lib/buyer/order-status"
import { getBuyerFetchError, unwrapBuyerList } from "@/lib/buyer-fetch"

const statusColors: Record<string, string> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  processing: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  shipped: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
  delivered: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  cancelled: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
}

export default function BuyerDashboard() {
  const { user } = useAuth()
  const [orders, setOrders] = useState<Order[]>([])
  const [products, setProducts] = useState<Product[]>([])
  const [reports, setReports] = useState<ProblemReportDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const [ordersRes, productsRes, reportsRes] = await Promise.all([
          ordersApi.getAll(),
          productsApi.getAll({ limit: 4 }),
          reportsApi.getMyReports().catch(() => ({ data: { reports: [] } })),
        ])

        setOrders(unwrapBuyerList<Order>(ordersRes.data, ["orders"]))
        setProducts(unwrapBuyerList<Product>(productsRes.data, ["products"]))
        setReports(unwrapBuyerList<ProblemReportDto>(reportsRes.data, ["reports"]))
      } catch (err) {
        console.error("Failed to load buyer dashboard data", err)
        setError(getBuyerFetchError(err, "Failed to load your dashboard data. Please try again."))
      } finally {
        setIsLoading(false)
      }
    }

    void fetchData()
  }, [])

  const orderCounts = countOrdersByBuyerFilter(orders)
  const totalOrders = orders.length
  const pendingOrders = orderCounts.to_pay
  const deliveredOrders = orderCounts.delivered

  const openReports = reports.filter((r) =>
    ["pending", "under_review", "investigating"].includes(r.status),
  ).length

  const stats = [
    { label: "Total Orders", value: totalOrders.toString(), icon: "shopping-bag", color: "bg-blue-500" },
    { label: "Pending", value: pendingOrders.toString(), icon: "clock", color: "bg-amber-500" },
    { label: "Delivered", value: deliveredOrders.toString(), icon: "check-circle", color: "bg-green-500" },
    { label: "Open Reports", value: openReports.toString(), icon: "exclamation", color: "bg-orange-500" },
  ]

  const recentOrders = [...orders]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 3)

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Welcome back, {user?.email || "buyer"}!</h1>
        <p className="text-muted-foreground">Here&apos;s what&apos;s happening with your orders.</p>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading your dashboard...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && (
        <div>
          <h2 className="text-lg font-semibold mb-3">Order shortcuts</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {BUYER_ORDER_FILTERS.filter((f) => f.key !== "all").map((f) => {
              const counts = countOrdersByBuyerFilter(orders)
              const count = counts[f.key as BuyerOrderFilterKey]
              return (
                <Link
                  key={f.key}
                  href={`/buyer/orders?filter=${f.key}`}
                  className="bg-card border rounded-xl p-4 hover:border-primary/50 transition-colors"
                >
                  <p className="text-sm font-medium">{f.label}</p>
                  <p className="text-2xl font-bold mt-1">{count}</p>
                </Link>
              )
            })}
          </div>
        </div>
      )}

      {/* Stats Grid */}
      {!isLoading && !error && (
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((stat, index) => (
          <motion.div
            key={stat.label}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            className="bg-card border rounded-2xl p-6"
          >
            <div className={`w-12 h-12 rounded-xl ${stat.color} flex items-center justify-center mb-4`}>
              <Icon name={stat.icon} className="text-white" />
            </div>
            <p className="text-3xl font-bold">{stat.value}</p>
            <p className="text-sm text-muted-foreground">{stat.label}</p>
          </motion.div>
        ))}
      </div>
      )}

      {/* Recent Orders */}
      {!isLoading && !error && (
      <div className="bg-card border rounded-2xl p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold">Recent Orders</h2>
          <Link href="/buyer/orders" className="text-primary hover:underline text-sm font-medium">
            View All
          </Link>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b">
                <th className="text-left py-3 px-4 font-medium text-muted-foreground">Order ID</th>
                <th className="text-left py-3 px-4 font-medium text-muted-foreground">Date</th>
                <th className="text-left py-3 px-4 font-medium text-muted-foreground">Status</th>
                <th className="text-left py-3 px-4 font-medium text-muted-foreground">Items</th>
                <th className="text-right py-3 px-4 font-medium text-muted-foreground">Total</th>
                <th className="text-right py-3 px-4 font-medium text-muted-foreground">Action</th>
              </tr>
            </thead>
            <tbody>
              {recentOrders.map((order) => (
                <tr key={order.id} className="border-b last:border-0">
                  <td className="py-4 px-4 font-medium">{order.orderNumber}</td>
                  <td className="py-4 px-4 text-muted-foreground">
                    {new Date(order.createdAt).toLocaleDateString("en-PH", {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </td>
                  <td className="py-4 px-4">
                    {(() => {
                      const rd = (order as Order & { riderDelivery?: { status?: string } }).riderDelivery
                      const effective = getEffectiveOrderStatus(
                        order.status ?? "",
                        rd?.status,
                      )
                      return (
                        <span
                          className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${
                            statusColors[effective] || "bg-muted text-muted-foreground"
                          }`}
                        >
                          {formatOrderStatusLabel(effective)}
                        </span>
                      )
                    })()}
                  </td>
                  <td className="py-4 px-4 text-muted-foreground">
                    {order.items?.length ?? 0} items
                  </td>
                  <td className="py-4 px-4 text-right font-medium">
                    {formatPrice(order.total ?? order.grandTotal ?? 0)}
                  </td>
                  <td className="py-4 px-4 text-right">
                    <Link href={`/orders/${order.id}`} className="text-primary hover:underline text-sm">
                      View
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      )}

      {/* Recent Reports */}
      {!isLoading && !error && reports.length > 0 && (
        <div className="bg-card border rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Recent Reports</h2>
            <Link href="/buyer/reports" className="text-primary hover:underline text-sm font-medium">
              View all
            </Link>
          </div>
          <div className="space-y-3">
            {reports.slice(0, 3).map((report) => (
              <div
                key={report.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-xl border bg-muted/30 px-4 py-3"
              >
                <div className="min-w-0">
                  <p className="text-sm font-medium truncate">{report.reportType || "Report"}</p>
                  <p className="text-xs text-muted-foreground">
                    #{report.id}
                    {report.targetLabel ? ` · ${report.targetLabel}` : ""}
                  </p>
                </div>
                <span className="px-2 py-0.5 rounded-full text-xs font-medium capitalize bg-background border">
                  {report.status.replace(/_/g, " ")}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Recommended Products */}
      {!isLoading && !error && products.length > 0 && (
        <div className="bg-card border rounded-2xl p-6">
          <h2 className="text-xl font-semibold mb-6">Recommended Products</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {products.map((product) => {
              const img = resolveImageUrl(product.image_url || product.images?.[0]) || "/placeholder.svg"
              return (
                <Link key={product.id} href={`/product/${product.slug}`} className="group">
                  <div className="relative aspect-square rounded-xl overflow-hidden bg-muted mb-3">
                    <Image
                      src={img}
                      alt={product.name}
                      fill
                      className="object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  </div>
                  <p className="font-medium text-sm line-clamp-1 group-hover:text-primary transition-colors">
                    {product.name}
                  </p>
                  <p className="text-sm text-primary font-semibold">{formatPrice(product.salePrice || product.price)}</p>
                </Link>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
