"use client"

import { useState, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Skeleton } from "@/components/ui/skeleton"
import { toast } from "sonner"
import { formatPrice, formatNumber } from "@/lib/format"
import { adminApi } from "@/lib/api"

interface CommissionSettings {
  id: number
  commissionRate: number
  appliesToProductPriceOnly: boolean
  isActive: boolean
  createdAt: string
  updatedAt: string
}

interface ShippingSettings {
  id: number
  regionName: string
  provinceName: string
  cityName: string
  shippingFee: number
  isActive: boolean
  createdAt: string
  updatedAt: string
}

interface CommissionAnalytics {
  totalCommissionEarned: number
  totalAdminRevenueFromShipping: number
  orderStats: Record<string, number>
  totalOrdersWithCommission: number
  commissionBreakdown?: {
    fromProducts: number
    fromShipping: number
    total: number
    rate: number
  }
}

export default function AdminCommissionPage() {
  const [commissionSettings, setCommissionSettings] = useState<CommissionSettings | null>(null)
  const [shippingSettings, setShippingSettings] = useState<ShippingSettings[]>([])
  const [analytics, setAnalytics] = useState<CommissionAnalytics | null>(null)
  const [analyticsError, setAnalyticsError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  const [commissionRate, setCommissionRate] = useState(0.10)
  const [appliesToProductOnly, setAppliesToProductOnly] = useState(true)
  const [newShippingRegion, setNewShippingRegion] = useState("")
  const [newShippingFee, setNewShippingFee] = useState(0)

  const loadData = async () => {
    setIsLoading(true)
    setAnalyticsError(null)

    const [settingsResult, shippingResult, analyticsResult] = await Promise.allSettled([
      adminApi.getCommissionSettings(),
      adminApi.getShippingSettings(),
      adminApi.getCommissionAnalytics(),
    ])

    if (settingsResult.status === "fulfilled") {
      const settings = settingsResult.value.data.settings as CommissionSettings
      setCommissionSettings(settings)
      setCommissionRate(settings.commissionRate)
      setAppliesToProductOnly(settings.appliesToProductPriceOnly)
    } else {
      toast.error("Failed to fetch commission settings")
    }

    if (shippingResult.status === "fulfilled") {
      setShippingSettings((shippingResult.value.data.settings as ShippingSettings[]) ?? [])
    } else {
      toast.error("Failed to fetch shipping settings")
    }

    if (analyticsResult.status === "fulfilled") {
      setAnalytics(analyticsResult.value.data as CommissionAnalytics)
    } else {
      setAnalytics(null)
      setAnalyticsError("Commission analytics could not be loaded.")
    }

    setIsLoading(false)
  }

  const updateCommissionSettings = async () => {
    try {
      setIsSaving(true)
      const res = await adminApi.updateCommissionSettings({
        commissionRate,
        appliesToProductPriceOnly: appliesToProductOnly,
      })
      setCommissionSettings(res.data.settings as CommissionSettings)
      toast.success("Commission settings updated successfully")
      const analyticsRes = await adminApi.getCommissionAnalytics()
      setAnalytics(analyticsRes.data as CommissionAnalytics)
      setAnalyticsError(null)
    } catch {
      toast.error("Failed to update commission settings")
    } finally {
      setIsSaving(false)
    }
  }

  const addShippingSetting = async () => {
    if (!newShippingRegion || newShippingFee <= 0) {
      toast.error("Please provide valid region and shipping fee")
      return
    }

    try {
      setIsSaving(true)
      const res = await adminApi.createShippingSetting({
        regionName: newShippingRegion,
        shippingFee: newShippingFee,
      })
      const setting = res.data.setting as ShippingSettings
      setShippingSettings((prev) => [...prev, setting])
      setNewShippingRegion("")
      setNewShippingFee(0)
      toast.success("Shipping setting added successfully")
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
        "Failed to add shipping setting"
      toast.error(msg)
    } finally {
      setIsSaving(false)
    }
  }

  useEffect(() => {
    void loadData()
  }, [])

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center shadow-lg">
            <Icon name="percent" className="text-white text-xl" />
          </div>
          <div>
            <h1 className="text-2xl font-bold">Commission & Shipping</h1>
            <p className="text-muted-foreground">Manage commission rates and shipping fees</p>
          </div>
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {Array.from({ length: 2 }).map((_, i) => (
            <Card key={i}>
              <CardHeader>
                <Skeleton className="h-6 w-32" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-40" />
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center shadow-lg">
          <Icon name="percent" className="text-white text-xl" />
        </div>
        <div>
          <h1 className="text-2xl font-bold">Commission & Shipping</h1>
          <p className="text-muted-foreground">Manage commission rates and shipping fees</p>
        </div>
      </div>

      {analyticsError && (
        <div className="bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-xl p-4 text-sm text-amber-900 dark:text-amber-200">
          {analyticsError}
        </div>
      )}

      {analytics && (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Card>
            <CardContent className="p-6">
              <p className="text-sm text-muted-foreground">Commission Earned</p>
              <p className="text-2xl font-bold mt-1">{formatPrice(analytics.totalCommissionEarned)}</p>
              {analytics.commissionBreakdown && (
                <p className="text-xs text-muted-foreground mt-1">
                  Current rate: {(analytics.commissionBreakdown.rate * 100).toFixed(1)}%
                </p>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-6">
              <p className="text-sm text-muted-foreground">Orders with Commission</p>
              <p className="text-2xl font-bold mt-1">{formatNumber(analytics.totalOrdersWithCommission)}</p>
            </CardContent>
          </Card>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Icon name="percent" className="text-blue-500" />
              Commission Settings
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <Label htmlFor="commissionRate">Commission Rate (decimal)</Label>
              <Input
                id="commissionRate"
                type="number"
                step="0.01"
                min="0"
                max="1"
                value={commissionRate}
                onChange={(e) => setCommissionRate(parseFloat(e.target.value) || 0)}
                className="mt-1"
              />
              <p className="text-xs text-muted-foreground mt-1">
                Current: {(commissionRate * 100).toFixed(1)}% of product price
              </p>
            </div>

            <div className="flex items-center justify-between">
              <div>
                <Label>Apply to Product Price Only</Label>
                <p className="text-xs text-muted-foreground">
                  Commission calculated on product price, excluding shipping fees
                </p>
              </div>
              <Switch checked={appliesToProductOnly} onCheckedChange={setAppliesToProductOnly} />
            </div>

            <Button onClick={() => void updateCommissionSettings()} disabled={isSaving} className="w-full">
              <Icon name={isSaving ? "spinner" : "save"} className="mr-2" />
              {isSaving ? "Saving..." : "Update Settings"}
            </Button>
            {commissionSettings?.updatedAt && (
              <p className="text-xs text-muted-foreground">
                Last updated: {new Date(commissionSettings.updatedAt).toLocaleString()}
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Icon name="truck" className="text-purple-500" />
              Shipping Settings
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-xs text-muted-foreground rounded-lg border bg-muted/40 px-3 py-2">
              Shipping fees are stored per shop. Sellers manage location rates in the seller portal;
              this list shows all active rates across stores (read-only here).
            </p>
            <div>
              <Label htmlFor="region">Region</Label>
              <Input
                id="region"
                placeholder="e.g., Metro Manila, Luzon, Visayas, Mindanao"
                value={newShippingRegion}
                onChange={(e) => setNewShippingRegion(e.target.value)}
                className="mt-1"
              />
            </div>

            <div>
              <Label htmlFor="shippingFee">Shipping Fee (PHP)</Label>
              <Input
                id="shippingFee"
                type="number"
                step="1"
                min="0"
                value={newShippingFee}
                onChange={(e) => setNewShippingFee(parseFloat(e.target.value) || 0)}
                className="mt-1"
              />
            </div>

            <Button
              onClick={() => void addShippingSetting()}
              disabled
              title="Requires a storeId — configure shipping in the seller portal per shop"
              className="w-full"
            >
              <Icon name="plus" className="mr-2" />
              Add via seller portal (per shop)
            </Button>

            <div className="space-y-2 max-h-40 overflow-y-auto">
              {shippingSettings.length === 0 ? (
                <p className="text-sm text-muted-foreground">No shipping settings configured yet.</p>
              ) : (
                shippingSettings.map((setting) => (
                  <div key={setting.id} className="flex items-center justify-between p-2 bg-muted rounded">
                    <div>
                      <p className="text-sm font-medium">{setting.regionName}</p>
                      <p className="text-xs text-muted-foreground">{formatPrice(setting.shippingFee)}</p>
                    </div>
                    <div className={`w-2 h-2 rounded-full ${setting.isActive ? "bg-green-500" : "bg-red-500"}`} />
                  </div>
                ))
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {analytics?.commissionBreakdown && (
        <Card>
          <CardHeader>
            <CardTitle>Commission Breakdown</CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="text-center p-4 bg-blue-50 dark:bg-blue-950/30 rounded-lg">
              <p className="text-2xl font-bold">{formatPrice(analytics.commissionBreakdown.fromProducts)}</p>
              <p className="text-sm text-muted-foreground">From Products</p>
            </div>
            <div className="text-center p-4 bg-purple-50 dark:bg-purple-950/30 rounded-lg">
              <p className="text-2xl font-bold">{formatPrice(analytics.commissionBreakdown.fromShipping)}</p>
              <p className="text-sm text-muted-foreground">From Shipping Share</p>
            </div>
            <div className="text-center p-4 bg-green-50 dark:bg-green-950/30 rounded-lg">
              <p className="text-2xl font-bold">{formatPrice(analytics.commissionBreakdown.total)}</p>
              <p className="text-sm text-muted-foreground">Total Commission</p>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
