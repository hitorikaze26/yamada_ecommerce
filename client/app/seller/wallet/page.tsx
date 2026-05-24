"use client"

import Link from "next/link"
import { useEffect, useState } from "react"
import { sellerApi } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

interface Wallet {
  sellerId: number
  balance: number
  updatedAt?: string | null
}

interface WalletTransaction {
  id: number
  orderId?: number | null
  amount: number
  platformFee: number
  netAmount: number
  status: string
  createdAt?: string | null
  updatedAt?: string | null
}

export default function SellerWalletPage() {
  const [wallet, setWallet] = useState<Wallet | null>(null)
  const [transactions, setTransactions] = useState<WalletTransaction[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<string>("all")
  const [startDate, setStartDate] = useState<string>("")
  const [endDate, setEndDate] = useState<string>("")
  const [preset, setPreset] = useState<"all" | "this_month" | "last_month">("all")
  const [page, setPage] = useState<number>(1)
  const pageSize = 10

  useEffect(() => {
    const load = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const [walletRes, txRes] = await Promise.all([
          sellerApi.getWallet(),
          sellerApi.getWalletTransactions(),
        ])

        const walletData = (walletRes.data as any)?.wallet ?? null
        const txData = (txRes.data as any)?.transactions ?? []

        setWallet(walletData)
        setTransactions(txData)
      } catch (err) {
        console.error("Failed to load wallet data", err)
        setError("Failed to load wallet data. Please try again.")
      } finally {
        setIsLoading(false)
      }
    }

    void load()
  }, [])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", {
      style: "currency",
      currency: "PHP",
    }).format(price)
  }

  const filteredTransactions = transactions.filter((tx) => {
    const statusOk =
      statusFilter === "all" || tx.status.toLowerCase() === statusFilter.toLowerCase()

    const created = tx.createdAt ? new Date(tx.createdAt) : null

    let startOk = true
    let endOk = true

    if (created && startDate) {
      startOk = created >= new Date(startDate)
    }
    if (created && endDate) {
      // include whole end day
      const end = new Date(endDate)
      end.setHours(23, 59, 59, 999)
      endOk = created <= end
    }

    return statusOk && startOk && endOk
  })

  // Update date range when preset changes
  useEffect(() => {
    const now = new Date()

    const toISODate = (d: Date) => d.toISOString().slice(0, 10)

    if (preset === "all") {
      setStartDate("")
      setEndDate("")
      return
    }

    if (preset === "this_month") {
      const start = new Date(now.getFullYear(), now.getMonth(), 1)
      const end = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      setStartDate(toISODate(start))
      setEndDate(toISODate(end))
      return
    }

    if (preset === "last_month") {
      const start = new Date(now.getFullYear(), now.getMonth() - 1, 1)
      const end = new Date(now.getFullYear(), now.getMonth(), 0)
      setStartDate(toISODate(start))
      setEndDate(toISODate(end))
    }
  }, [preset])

  // Reset to first page when filters change
  useEffect(() => {
    setPage(1)
  }, [statusFilter, startDate, endDate])

  const totalPages = Math.max(1, Math.ceil(filteredTransactions.length / pageSize))
  const paginatedTransactions = filteredTransactions.slice(
    (page - 1) * pageSize,
    page * pageSize,
  )

  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear = now.getFullYear()
  const thisMonthNet = filteredTransactions
    .filter((tx) => {
      if (!tx.createdAt) return false
      const d = new Date(tx.createdAt)
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear
    })
    .reduce((sum, tx) => sum + tx.netAmount, 0)

  const refundedCount = transactions.filter(
    (t) => t.status.toLowerCase() === "refunded",
  ).length

  const totalRefunded = transactions
    .filter((t) => t.status.toLowerCase() === "refunded")
    .reduce((sum, t) => sum + t.netAmount, 0)

  const getStatusBadgeClasses = (status: string) => {
    const s = status.toLowerCase()
    if (s === "settled") {
      return "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300 capitalize"
    }
    if (s === "held") {
      return "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300 capitalize"
    }
    if (s === "refunded") {
      return "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300 capitalize"
    }
    if (s === "failed") {
      return "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300 capitalize"
    }
    return "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-muted text-muted-foreground capitalize"
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-2">
        <div>
          <h1 className="text-3xl font-bold mb-2">Wallet</h1>
          <p className="text-muted-foreground">View your available balance and recent earnings.</p>
        </div>
        <Link
          href="/seller/refunds"
          className="inline-flex items-center gap-2 text-sm px-3 py-1.5 rounded-full border bg-background hover:bg-muted transition-colors"
        >
          <Icon name="receipt-alt" className="w-4 h-4" />
          <span>View refunds</span>
        </Link>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4 text-sm text-muted-foreground">Loading wallet...</div>
      )}

      {!isLoading && error && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && (
        <>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <div className="bg-card border rounded-2xl p-6 flex flex-col justify-between">
              <div>
                <p className="text-sm text-muted-foreground mb-1">Available Balance</p>
                <p className="text-3xl font-bold">
                  {formatPrice(wallet?.balance ?? 0)}
                </p>
              </div>
              {wallet?.updatedAt && (
                <p className="mt-4 text-xs text-muted-foreground">
                  Updated {new Date(wallet.updatedAt).toLocaleString("en-PH")}
                </p>
              )}
            </div>

            <div className="bg-card border rounded-2xl p-6 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                <Icon name="wallet" className="text-primary" />
              </div>
              <div>
                <p className="font-semibold">Completed Payouts</p>
                <p className="text-sm text-muted-foreground">
                  {transactions.filter((t) => t.status.toLowerCase() === "settled").length} settled transactions
                </p>
              </div>
            </div>

            <div className="bg-card border rounded-2xl p-6 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
                <Icon name="clock" className="text-amber-600 dark:text-amber-300" />
              </div>
              <div>
                <p className="font-semibold">Held Earnings</p>
                <p className="text-sm text-muted-foreground">
                  {formatPrice(
                    transactions
                      .filter((t) => t.status.toLowerCase() === "held")
                      .reduce((sum, t) => sum + t.netAmount, 0),
                  )}
                </p>
              </div>
            </div>

            <div className="bg-card border rounded-2xl p-6 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center">
                <Icon name="calendar-check" className="text-emerald-600 dark:text-emerald-300" />
              </div>
              <div>
                <p className="font-semibold">This Month Net Earnings</p>
                <p className="text-sm text-muted-foreground">
                  {formatPrice(thisMonthNet)}
                </p>
              </div>
            </div>

            <div className="bg-card border rounded-2xl p-6 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
                <Icon name="receipt-refund" className="text-red-600 dark:text-red-300" />
              </div>
              <div>
                <p className="font-semibold">Refunds Impact</p>
                <p className="text-sm text-muted-foreground">
                  {refundedCount} refunded transactions ({formatPrice(totalRefunded)})
                </p>
              </div>
            </div>
          </div>

          <div className="bg-card border rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">Recent Transactions</h2>
              <div className="flex flex-wrap gap-3 items-center text-xs md:text-sm">
                <div className="flex flex-col">
                  <span className="text-muted-foreground mb-1">Preset</span>
                  <select
                    className="border bg-background rounded-md px-2 py-1 text-xs md:text-sm"
                    value={preset}
                    onChange={(e) => setPreset(e.target.value as any)}
                  >
                    <option value="all">All time</option>
                    <option value="this_month">This month</option>
                    <option value="last_month">Last month</option>
                  </select>
                </div>
                <div className="flex flex-col">
                  <span className="text-muted-foreground mb-1">Status</span>
                  <select
                    className="border bg-background rounded-md px-2 py-1 text-xs md:text-sm"
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                  >
                    <option value="all">All</option>
                    <option value="held">Held</option>
                    <option value="settled">Settled</option>
                    <option value="refunded">Refunded</option>
                    <option value="failed">Failed</option>
                  </select>
                </div>
                <div className="flex flex-col">
                  <span className="text-muted-foreground mb-1">From</span>
                  <input
                    type="date"
                    className="border bg-background rounded-md px-2 py-1 text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    disabled={preset !== "all"}
                  />
                </div>
                <div className="flex flex-col">
                  <span className="text-muted-foreground mb-1">To</span>
                  <input
                    type="date"
                    className="border bg-background rounded-md px-2 py-1 text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                    disabled={preset !== "all"}
                  />
                </div>
              </div>
            </div>

            {filteredTransactions.length === 0 ? (
              <div className="text-sm text-muted-foreground">No transactions yet.</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b text-muted-foreground">
                      <th className="py-2 pr-4 text-left">Date</th>
                      <th className="py-2 pr-4 text-left">Order</th>
                      <th className="py-2 pr-4 text-right">Gross</th>
                      <th className="py-2 pr-4 text-right">Fee</th>
                      <th className="py-2 pr-4 text-right">Net</th>
                      <th className="py-2 pr-4 text-left">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedTransactions.map((tx) => (
                      <tr key={tx.id} className="border-b last:border-0">
                        <td className="py-2 pr-4">
                          {tx.createdAt
                            ? new Date(tx.createdAt).toLocaleString("en-PH")
                            : "-"}
                        </td>
                        <td className="py-2 pr-4">
                          {tx.orderId ? `#${String(tx.orderId).padStart(6, "0")}` : "-"}
                        </td>
                        <td className="py-2 pr-4 text-right">{formatPrice(tx.amount)}</td>
                        <td className="py-2 pr-4 text-right">{formatPrice(tx.platformFee)}</td>
                        <td className="py-2 pr-4 text-right">{formatPrice(tx.netAmount)}</td>
                        <td className="py-2 pr-4">
                          <span className={getStatusBadgeClasses(tx.status)}>{tx.status.toLowerCase()}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                <div className="flex items-center justify-between mt-4 text-xs md:text-sm">
                  <span className="text-muted-foreground">
                    Showing {(page - 1) * pageSize + 1}–
                    {Math.min(page * pageSize, filteredTransactions.length)} of {filteredTransactions.length} transactions
                  </span>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      disabled={page <= 1}
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                      className="px-3 py-1 rounded-md border text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-muted"
                    >
                      Previous
                    </button>
                    <span className="text-muted-foreground">
                      Page {page} of {totalPages}
                    </span>
                    <button
                      type="button"
                      disabled={page >= totalPages}
                      onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                      className="px-3 py-1 rounded-md border text-xs md:text-sm disabled:opacity-50 disabled:cursor-not-allowed hover:bg-muted"
                    >
                      Next
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}
