"use client"
import Link from "next/link"
import { useEffect, useRef, useState } from "react"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { sellerAccountApi, sellerApi, sellerInsightsApi } from "@/lib/api"
import { formatPrice } from "@/lib/format"
import StatCard from "@/components/dashboard/StatCard"

interface RecentOrderRow {
  id: number
  displayId?: string
  status?: string
  createdAt?: string
  totalAmount?: number
}

interface SellerDashboardProfile {
  givenName: string
  shopName: string
  rating: number
  totalSales: number
  categories: string[]
}

export default function SellerDashboard() {
  const [profile, setProfile] = useState<SellerDashboardProfile | null>(null)
  const [recentOrders, setRecentOrders] = useState<RecentOrderRow[]>([])
  const [totalProducts, setTotalProducts] = useState(0)
  const [insights, setInsights] = useState<{
    rating: number
    followersCount: number
    wishlistBuyerCount: number
  } | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const hasLoadedRef = useRef(false)

  useEffect(() => {
    const fetchData = async () => {
      const isInitialLoad = !hasLoadedRef.current
      try {
        if (isInitialLoad) {
          setIsLoading(true)
        }
        setError(null)

        const profileRes = await sellerAccountApi.getProfile()
        const p = profileRes.data.profile
        setProfile({
          givenName: p.givenName ?? "",
          shopName: p.shopName ?? "",
          rating: typeof p.rating === "number" ? p.rating : 0,
          totalSales: typeof p.totalSales === "number" ? p.totalSales : 0,
          categories: Array.isArray(p.categories) ? p.categories : [],
        })
        
        // Fetch products count
        const productsRes = await sellerApi.getMyProducts()
        const products = productsRes.data?.products || []
        setTotalProducts(products.length)

        try {
          const insightsRes = await sellerInsightsApi.getInsights()
          const d = insightsRes.data
          setInsights({
            rating: typeof d.rating === "number" ? d.rating : 0,
            followersCount: d.followersCount ?? 0,
            wishlistBuyerCount: d.wishlistBuyerCount ?? 0,
          })
        } catch {
          setInsights({ rating: p.rating ?? 0, followersCount: 0, wishlistBuyerCount: 0 })
        }

        try {
          const ordersRes = await sellerApi.getOrders()
          const orders = (ordersRes.data?.orders || []) as RecentOrderRow[]
          const sorted = [...orders].sort((a, b) => {
            const ta = a.createdAt ? new Date(a.createdAt).getTime() : 0
            const tb = b.createdAt ? new Date(b.createdAt).getTime() : 0
            return tb - ta
          })
          setRecentOrders(sorted.slice(0, 5))
        } catch {
          setRecentOrders([])
        }
      } catch (err: any) {
        const msg = err?.response?.data?.msg || "Failed to load dashboard data."
        setError(msg)
      } finally {
        hasLoadedRef.current = true
        setIsLoading(false)
      }
    }

    void fetchData()
  }, [])

  const formatOrderTime = (dateString?: string) => {
    if (!dateString) return ""
    const date = new Date(dateString)
    const now = new Date()
    const diff = Math.floor((now.getTime() - date.getTime()) / 1000)
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
    return `${Math.floor(diff / 86400)}d ago`
  }

  const stats = profile
    ? [
        {
          label: "Total Sales",
          value: formatPrice(profile.totalSales || 0),
          helper: "All-time orders total",
          icon: "peso-sign",
          color: "bg-green-500",
        },
        {
          label: "Total Products",
          value: String(totalProducts),
          helper: "Products in your shop",
          icon: "box",
          color: "bg-purple-500",
        },
        {
          label: "Categories",
          value: String(profile.categories.length || 0),
          helper: "Active shop categories",
          icon: "tags",
          color: "bg-blue-500",
        },
      ]
    : []

  return (
    <div className="space-y-6">
      {/* Welcome */}
      <div>
        <h1 className="text-3xl font-bold mb-2">
          {profile?.shopName ? profile.shopName : "Welcome back!"}
        </h1>
        <p className="text-muted-foreground">
          {profile?.givenName ? `Hi ${profile.givenName}, here's what's happening with your shop.` : "Here's what's happening with your shop today."}
        </p>
      </div>

      {/* Stats + Store Insights */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Link
          href="/seller/insights"
          className="col-span-2 lg:col-span-1 bg-card border rounded-2xl p-5 hover:border-primary hover:shadow-md transition-all group"
        >
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm font-medium text-muted-foreground group-hover:text-primary">
              Store Insights
            </span>
            <Icon name="angle-right" className="text-muted-foreground group-hover:text-primary" />
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Rating</span>
              <span className="font-semibold">
                {(insights?.rating ?? profile?.rating ?? 0).toFixed(1)}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Wishlist buyers</span>
              <span className="font-semibold">{insights?.wishlistBuyerCount ?? 0}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Followers</span>
              <span className="font-semibold">{insights?.followersCount ?? 0}</span>
            </div>
          </div>
        </Link>
        {isLoading && (
          <div className="bg-card border rounded-2xl p-6 col-span-2 lg:col-span-4 text-sm text-muted-foreground">
            Loading dashboard metrics...
          </div>
        )}
        {!isLoading && error && (
          <div className="bg-destructive/10 border border-destructive/30 rounded-2xl p-4 col-span-2 lg:col-span-4 text-sm text-destructive">
            {error}
          </div>
        )}
        {!isLoading && !error &&
          stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={false}
              animate={{ opacity: 1, y: 0 }}
            >
              <StatCard
                title={stat.label}
                value={stat.value}
                percent="20%"
                trend="up"
                fillPercent={76}
                icon={stat.icon}
                pillColor={
                  stat.color === "bg-green-500"
                    ? "#10B981"
                    : stat.color === "bg-amber-500"
                    ? "#F59E0B"
                    : "#3B82F6"
                }
                barColor={
                  stat.color === "bg-green-500"
                    ? "#10B981"
                    : stat.color === "bg-amber-500"
                    ? "#F59E0B"
                    : "#3B82F6"
                }
              />
            </motion.div>
          ))}
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Recent Orders */}
        <div className="bg-card border rounded-2xl p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold">Recent Orders</h2>
            <Link href="/seller/orders" className="text-primary hover:underline text-sm font-medium">
              View All
            </Link>
          </div>

          {recentOrders.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              No orders yet. New customer orders will appear here.
            </p>
          ) : (
            <ul className="space-y-3">
              {recentOrders.map((order) => (
                <li
                  key={order.id}
                  className="flex items-center justify-between py-2 border-b last:border-0 text-sm"
                >
                  <div>
                    <p className="font-medium">
                      Order {order.displayId || `#${order.id}`}
                    </p>
                    <p className="text-xs text-muted-foreground capitalize">
                      {order.status || "pending"}
                      {order.createdAt ? ` · ${formatOrderTime(order.createdAt)}` : ""}
                    </p>
                  </div>
                  {order.totalAmount != null && (
                    <span className="font-semibold">
                      {formatPrice(order.totalAmount)}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="bg-card border rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Recent activity</h2>
            <Link href="/seller/branding" className="text-primary hover:underline text-sm font-medium">
              Shop branding
            </Link>
          </div>
          <p className="text-sm text-muted-foreground">
            Manage branding, wallet, refunds, and coupons from the quick actions below.
          </p>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-card border rounded-2xl p-6">
        <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <Link
            href="/home?shop=1"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="shop" className="text-primary" />
            </div>
            <span className="text-sm font-medium text-center">Browse marketplace</span>
          </Link>
          <Link
            href="/seller/insights"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="chart-simple" className="text-primary" />
            </div>
            <span className="text-sm font-medium text-center">Store insights</span>
          </Link>
          <Link
            href="/seller/products/new"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="plus" className="text-primary" />
            </div>
            <span className="text-sm font-medium">Add Product</span>
          </Link>
          <Link
            href="/seller/orders"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="clipboard-list" className="text-primary" />
            </div>
            <span className="text-sm font-medium">Manage Orders</span>
          </Link>
          <Link
            href="/seller/analytics"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="chart-pie-alt" className="text-primary" />
            </div>
            <span className="text-sm font-medium">View Analytics</span>
          </Link>
          <Link
            href="/seller/branding"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="palette" className="text-primary" />
            </div>
            <span className="text-sm font-medium">Shop branding</span>
          </Link>
          <Link
            href="/seller/shop"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="shop" className="text-primary" />
            </div>
            <span className="text-sm font-medium">Shop operations</span>
          </Link>
          <Link
            href="/seller/account-settings"
            className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
          >
            <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <Icon name="settings" className="text-primary" />
            </div>
            <span className="text-sm font-medium">Account security</span>
          </Link>
        </div>
      </div>
    </div>
  )
}
