"use client"

import { useCallback, useEffect, useState } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { adminApi } from "@/lib/api"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"
import { toast } from "sonner"

interface CouponDto {
  id: number
  code: string
  title: string
  description: string
  discountType: string
  discountValue: number
  minOrderAmount: number
  maxUses: number | null
  usedCount: number
  expiresAt: string | null
  isActive: boolean
  scope: string
  storeId: number | null
}

const emptyForm = {
  code: "",
  title: "",
  description: "",
  discountType: "percent",
  discountValue: "10",
  minOrderAmount: "0",
  maxUses: "",
  expiresAt: "",
  scope: "platform",
  isActive: true,
}

export default function AdminCouponsPage() {
  const [coupons, setCoupons] = useState<CouponDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState(emptyForm)
  const [isSaving, setIsSaving] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)

  const fetchCoupons = useCallback(async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await adminApi.getCoupons()
      setCoupons(unwrapAdminList<CouponDto>(res.data, ["coupons"]))
    } catch (err) {
      console.error("Failed to load coupons", err)
      setError(getAdminFetchError(err, "Failed to load coupons."))
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    void fetchCoupons()
  }, [fetchCoupons])

  const resetForm = () => {
    setForm(emptyForm)
    setEditingId(null)
    setShowForm(false)
  }

  const handleEdit = (coupon: CouponDto) => {
    setEditingId(coupon.id)
    setShowForm(true)
    setForm({
      code: coupon.code,
      title: coupon.title,
      description: coupon.description ?? "",
      discountType: coupon.discountType,
      discountValue: String(coupon.discountValue),
      minOrderAmount: String(coupon.minOrderAmount),
      maxUses: coupon.maxUses != null ? String(coupon.maxUses) : "",
      expiresAt: coupon.expiresAt ? coupon.expiresAt.slice(0, 16) : "",
      scope: coupon.scope,
      isActive: coupon.isActive,
    })
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.code.trim() || !form.title.trim()) {
      toast.error("Code and title are required")
      return
    }

    const payload: Record<string, unknown> = {
      code: form.code.trim().toUpperCase(),
      title: form.title.trim(),
      description: form.description,
      discountType: form.discountType,
      discountValue: parseFloat(form.discountValue) || 0,
      minOrderAmount: parseFloat(form.minOrderAmount) || 0,
      maxUses: form.maxUses ? parseInt(form.maxUses, 10) : null,
      expiresAt: form.expiresAt ? new Date(form.expiresAt).toISOString() : null,
      scope: form.scope,
      isActive: form.isActive,
    }

    setIsSaving(true)
    try {
      if (editingId != null) {
        await adminApi.updateCoupon(editingId, payload)
        toast.success("Coupon updated")
      } else {
        await adminApi.createCoupon(payload)
        toast.success("Coupon created")
      }
      resetForm()
      await fetchCoupons()
    } catch (err) {
      console.error("Failed to save coupon", err)
      toast.error("Failed to save coupon")
    } finally {
      setIsSaving(false)
    }
  }

  const handleDelete = async (couponId: number) => {
    if (!confirm("Delete this coupon?")) return
    try {
      await adminApi.deleteCoupon(couponId)
      toast.success("Coupon deleted")
      await fetchCoupons()
    } catch (err) {
      console.error("Failed to delete coupon", err)
      toast.error("Failed to delete coupon")
    }
  }

  const formatPrice = (amount: number) =>
    new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(amount)

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold mb-2">Coupons</h1>
          <p className="text-muted-foreground">Manage platform promotional coupons.</p>
        </div>
        <Button
          onClick={() => {
            resetForm()
            setShowForm(true)
          }}
        >
          <Icon name="plus" className="mr-2" />
          New Coupon
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleSubmit} className="bg-card border rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-semibold">{editingId != null ? "Edit Coupon" : "Create Coupon"}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <Label htmlFor="code">Code</Label>
              <Input
                id="code"
                value={form.code}
                onChange={(e) => setForm({ ...form, code: e.target.value })}
                className="mt-1 uppercase"
                required
              />
            </div>
            <div>
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                className="mt-1"
                required
              />
            </div>
            <div>
              <Label htmlFor="discountType">Discount Type</Label>
              <select
                id="discountType"
                value={form.discountType}
                onChange={(e) => setForm({ ...form, discountType: e.target.value })}
                className="mt-1 w-full border rounded-lg px-3 py-2 text-sm bg-background"
              >
                <option value="percent">Percent</option>
                <option value="fixed">Fixed amount</option>
              </select>
            </div>
            <div>
              <Label htmlFor="discountValue">Discount Value</Label>
              <Input
                id="discountValue"
                type="number"
                step="0.01"
                value={form.discountValue}
                onChange={(e) => setForm({ ...form, discountValue: e.target.value })}
                className="mt-1"
              />
            </div>
            <div>
              <Label htmlFor="minOrderAmount">Min Order Amount</Label>
              <Input
                id="minOrderAmount"
                type="number"
                step="0.01"
                value={form.minOrderAmount}
                onChange={(e) => setForm({ ...form, minOrderAmount: e.target.value })}
                className="mt-1"
              />
            </div>
            <div>
              <Label htmlFor="maxUses">Max Uses (optional)</Label>
              <Input
                id="maxUses"
                type="number"
                value={form.maxUses}
                onChange={(e) => setForm({ ...form, maxUses: e.target.value })}
                className="mt-1"
              />
            </div>
            <div>
              <Label htmlFor="expiresAt">Expires At (optional)</Label>
              <Input
                id="expiresAt"
                type="datetime-local"
                value={form.expiresAt}
                onChange={(e) => setForm({ ...form, expiresAt: e.target.value })}
                className="mt-1"
              />
            </div>
            <div>
              <Label htmlFor="scope">Scope</Label>
              <select
                id="scope"
                value={form.scope}
                onChange={(e) => setForm({ ...form, scope: e.target.value })}
                className="mt-1 w-full border rounded-lg px-3 py-2 text-sm bg-background"
              >
                <option value="platform">Platform</option>
                <option value="store">Store</option>
              </select>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="isActive"
              checked={form.isActive}
              onChange={(e) => setForm({ ...form, isActive: e.target.checked })}
            />
            <Label htmlFor="isActive">Active</Label>
          </div>
          <div className="flex gap-3">
            <Button type="submit" disabled={isSaving}>
              {isSaving ? "Saving..." : editingId != null ? "Update" : "Create"}
            </Button>
            <Button type="button" variant="outline" onClick={resetForm}>
              Cancel
            </Button>
          </div>
        </form>
      )}

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading coupons...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && coupons.length === 0 && (
        <div className="bg-card border rounded-2xl p-8 text-center text-muted-foreground">
          No coupons yet. Create one to get started.
        </div>
      )}

      {!isLoading && !error && coupons.length > 0 && (
        <div className="bg-card border rounded-2xl overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="p-4">Code</th>
                <th className="p-4">Title</th>
                <th className="p-4">Discount</th>
                <th className="p-4">Usage</th>
                <th className="p-4">Status</th>
                <th className="p-4">Actions</th>
              </tr>
            </thead>
            <tbody>
              {coupons.map((coupon) => (
                <tr key={coupon.id} className="border-b last:border-0">
                  <td className="p-4 font-mono font-medium">{coupon.code}</td>
                  <td className="p-4">{coupon.title}</td>
                  <td className="p-4">
                    {coupon.discountType === "percent"
                      ? `${coupon.discountValue}%`
                      : formatPrice(coupon.discountValue)}
                    {coupon.minOrderAmount > 0 && (
                      <span className="block text-xs text-muted-foreground">
                        Min {formatPrice(coupon.minOrderAmount)}
                      </span>
                    )}
                  </td>
                  <td className="p-4">
                    {coupon.usedCount}
                    {coupon.maxUses != null ? ` / ${coupon.maxUses}` : ""}
                  </td>
                  <td className="p-4">
                    <span
                      className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                        coupon.isActive
                          ? "bg-emerald-100 text-emerald-700"
                          : "bg-muted text-muted-foreground"
                      }`}
                    >
                      {coupon.isActive ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td className="p-4">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleEdit(coupon)}
                        className="text-xs text-primary hover:underline"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => void handleDelete(coupon.id)}
                        className="text-xs text-destructive hover:underline"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
