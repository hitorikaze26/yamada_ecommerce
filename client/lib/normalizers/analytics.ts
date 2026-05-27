import type { DashboardOverview, SalesData, CategoryPerformance } from "@/lib/types"

function str(raw: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return String(v)
  }
  return ""
}

function num(raw: Record<string, unknown>, ...keys: string[]): number {
  for (const k of keys) {
    const v = raw[k]
    if (typeof v === "number") return v
  }
  return Number(_read(raw, keys) ?? 0)
}

function _read(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

export function normalizeDashboardOverview(raw: Record<string, unknown>): DashboardOverview {
  return {
    totalSales: num(raw, "totalSales", "total_sales", "totalRevenue", "total_revenue"),
    totalOrders: num(raw, "totalOrders", "total_orders"),
    totalProducts: num(raw, "totalProducts", "total_products", "productCount", "product_count"),
    netSales: num(raw, "netSales", "net_sales"),
    salesTrend: num(raw, "salesTrend", "sales_trend", "revenueGrowth", "revenue_growth"),
    ordersTrend: num(raw, "ordersTrend", "orders_trend", "ordersGrowth", "orders_growth"),
    recentTransactions: Array.isArray(raw.recentTransactions ?? raw.recent_transactions ?? raw.salesChart)
      ? ((raw.recentTransactions ?? raw.recent_transactions ?? raw.salesChart ?? []) as Record<string, unknown>[]).map(t => ({
          id: str(t, "id"),
          type: (t.type === "sale" || t.type === "refund" ? t.type : "sale") as "sale" | "refund",
          amount: num(t, "amount", "sales"),
          buyerName: str(t, "buyerName", "buyer_name", "name"),
          riderName: str(t, "riderName", "rider_name") || undefined,
          status: str(t, "status"),
          createdAt: str(t, "createdAt", "created_at", "date"),
        }))
      : [],
    visitors: num(raw, "visitors"),
    searchCount: num(raw, "searchCount", "search_count"),
  }
}

export function normalizeSalesData(rawList: unknown[]): SalesData[] {
  return rawList.map(item => {
    const r = item as Record<string, unknown>
    return {
      date: str(r, "date", "createdAt", "created_at"),
      sales: num(r, "sales", "amount", "revenue"),
      orders: num(r, "orders", "count"),
    }
  })
}

export function normalizeCategoryPerformance(rawList: unknown[]): CategoryPerformance[] {
  return rawList.map(item => {
    const r = item as Record<string, unknown>
    return {
      category: str(r, "category", "name"),
      sales: num(r, "sales", "value"),
      orders: num(r, "orders", "count"),
    }
  })
}
