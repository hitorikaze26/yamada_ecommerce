"use client"
import Link from "next/link"
import { useEffect, useState } from "react"
import { Icon } from "@/components/ui/icon"
import { adminApi } from "@/lib/api"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"
import StatCard from "@/components/dashboard/StatCard"

interface AdminStats {
  totalUsers: number
  pendingStoreRegistrations: number
  productsUnderReview: number
  openRefundDisputes: number
}

interface StoreRegistrationDto {
  [key: string]: unknown
}

export default function AdminDashboard() {
  const [stats, setStats] = useState<AdminStats | null>(null)
  const [pendingRegistrations, setPendingRegistrations] = useState<StoreRegistrationDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      setIsLoading(true)
      setError(null)

      try {
        const [usersRes, approvalsRes, reviewRes, disputesRes] = await Promise.all([
          adminApi.getUsers(),
          adminApi.getApprovals(),
          adminApi.getProducts({ status: "under_review" }),
          adminApi.getRefundRequests({ queue: "disputes" }),
        ])

        const users = unwrapAdminList(usersRes.data, ["users"])
        const storeRegistrations = unwrapAdminList(approvalsRes.data, ["StoreRegistrations"])
        const underReview = unwrapAdminList(reviewRes.data, ["products"])
        const disputes = unwrapAdminList(disputesRes.data, ["refunds"])

        setStats({
          totalUsers: users.length,
          pendingStoreRegistrations: storeRegistrations.length,
          productsUnderReview: underReview.length,
          openRefundDisputes: disputes.length,
        })

        setPendingRegistrations(storeRegistrations)
      } catch (err) {
        console.error("Failed to load admin dashboard data", err)
        setError(getAdminFetchError(err, "Failed to load dashboard data. Please try again."))
      } finally {
        setIsLoading(false)
      }
    }

    fetchData()
  }, [])

  const maxStat = stats
    ? Math.max(
        stats.totalUsers,
        stats.pendingStoreRegistrations,
        stats.productsUnderReview,
        stats.openRefundDisputes,
        1,
      )
    : 1

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Admin Dashboard</h1>
        <p className="text-muted-foreground">Platform overview based on live data.</p>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-6">Loading dashboard data...</div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && stats && (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              title="Total Users"
              value={stats.totalUsers}
              fillPercent={Math.round((stats.totalUsers / maxStat) * 100)}
              icon="users"
              pillColor="#3B82F6"
              barColor="#3B82F6"
            />
            <StatCard
              title="Pending Store Registrations"
              value={stats.pendingStoreRegistrations}
              fillPercent={Math.round((stats.pendingStoreRegistrations / maxStat) * 100)}
              icon="store-alt"
              pillColor="#F59E0B"
              barColor="#F59E0B"
            />
            <StatCard
              title="Products Under Review"
              value={stats.productsUnderReview}
              fillPercent={Math.round((stats.productsUnderReview / maxStat) * 100)}
              icon="box"
              pillColor="#8B5CF6"
              barColor="#8B5CF6"
            />
            <StatCard
              title="Open Refund Disputes"
              value={stats.openRefundDisputes}
              fillPercent={Math.round((stats.openRefundDisputes / maxStat) * 100)}
              icon="receipt-refund"
              pillColor="#EF4444"
              barColor="#EF4444"
            />
          </div>

          <div className="bg-card border rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">Pending Store Registrations</h2>
              <span className="text-sm text-muted-foreground">
                {pendingRegistrations.length} pending
              </span>
            </div>

            {pendingRegistrations.length === 0 ? (
              <p className="text-sm text-muted-foreground">No pending store registrations.</p>
            ) : (
              <div className="space-y-3">
                {pendingRegistrations.map((reg) => (
                  <div
                    key={(reg as { id?: number }).id ?? (reg as { "Store name"?: string })["Store name"]}
                    className="flex items-start justify-between gap-4 rounded-xl border bg-muted/40 px-4 py-3"
                  >
                    <div className="flex items-start gap-3">
                      <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                        <Icon name="store" className="text-primary" />
                      </div>
                      <div className="space-y-1">
                        <p className="text-sm font-medium">
                          {(reg as { "Store name"?: string })["Store name"] ?? "Store registration"}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {(reg as { "Seller full name"?: string })["Seller full name"] ?? ""}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="bg-card border rounded-2xl p-6">
            <h2 className="text-xl font-semibold mb-6">Quick Actions</h2>
            <div className="grid grid-cols-2 gap-4">
              <Link
                href="/admin/users"
                className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
              >
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Icon name="person-circle-plus" className="text-primary" />
                </div>
                <span className="text-sm font-medium">Manage Users</span>
              </Link>
              <Link
                href="/admin/shops"
                className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
              >
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Icon name="store-alt" className="text-primary" />
                </div>
                <span className="text-sm font-medium">Verify Shops</span>
              </Link>
              <Link
                href="/admin/riders"
                className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
              >
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Icon name="truck-container" className="text-primary" />
                </div>
                <span className="text-sm font-medium">Verify Riders</span>
              </Link>
              <Link
                href="/admin/reports"
                className="flex flex-col items-center gap-2 p-4 rounded-xl border hover:border-primary hover:bg-primary/5 transition-colors"
              >
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Icon name="exclamation" className="text-primary" />
                </div>
                <span className="text-sm font-medium">Problem Reports</span>
              </Link>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
