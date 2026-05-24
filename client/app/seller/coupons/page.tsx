"use client"

import { useCallback, useEffect, useState } from "react"
import Swal from "sweetalert2"
import { toast } from "sonner"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { sellerCouponsApi, type SellerCouponDto } from "@/lib/api"

export default function SellerCouponsPage() {
  const [coupons, setCoupons] = useState<SellerCouponDto[]>([])
  const [loading, setLoading] = useState(true)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({
    code: "",
    title: "",
    discountValue: "10",
    minOrderAmount: "0",
  })

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await sellerCouponsApi.list()
      setCoupons(res.data.coupons || [])
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
        "Failed to load coupons"
      toast.error(msg)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const handleCreate = async () => {
    if (!form.code.trim() || !form.title.trim()) {
      toast.error("Code and title are required")
      return
    }
    setSaving(true)
    try {
      await sellerCouponsApi.create({
        code: form.code.trim().toUpperCase(),
        title: form.title.trim(),
        discountType: "percent",
        discountValue: parseFloat(form.discountValue) || 0,
        minOrderAmount: parseFloat(form.minOrderAmount) || 0,
        isActive: true,
      })
      toast.success("Coupon created")
      setDialogOpen(false)
      setForm({ code: "", title: "", discountValue: "10", minOrderAmount: "0" })
      await load()
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
        "Failed to create coupon"
      toast.error(msg)
    } finally {
      setSaving(false)
    }
  }

  const toggleActive = async (coupon: SellerCouponDto) => {
    try {
      await sellerCouponsApi.update(coupon.id, { isActive: !coupon.isActive })
      await load()
    } catch {
      toast.error("Failed to update coupon")
    }
  }

  const handleDelete = async (coupon: SellerCouponDto) => {
    const result = await Swal.fire({
      title: "Delete coupon?",
      text: `Remove ${coupon.code}?`,
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#ef4444",
    })
    if (!result.isConfirmed) return
    try {
      await sellerCouponsApi.delete(coupon.id)
      toast.success("Coupon deleted")
      await load()
    } catch {
      toast.error("Failed to delete coupon")
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">Coupons</h1>
          <p className="text-sm text-muted-foreground">
            Create discount codes for your store.
          </p>
        </div>
        <Button onClick={() => setDialogOpen(true)}>
          <Icon name="plus" className="mr-2" />
          New coupon
        </Button>
      </div>

      {loading ? (
        <p className="text-sm text-muted-foreground">Loading coupons…</p>
      ) : coupons.length === 0 ? (
        <div className="rounded-2xl border bg-card p-8 text-center text-muted-foreground text-sm">
          No coupons yet. Create one to offer discounts to buyers.
        </div>
      ) : (
        <div className="rounded-2xl border bg-card overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="text-left p-3 font-medium">Code</th>
                <th className="text-left p-3 font-medium">Title</th>
                <th className="text-left p-3 font-medium">Discount</th>
                <th className="text-left p-3 font-medium">Uses</th>
                <th className="text-left p-3 font-medium">Status</th>
                <th className="text-right p-3 font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {coupons.map((c) => (
                <tr key={c.id} className="border-b last:border-0">
                  <td className="p-3 font-mono font-semibold">{c.code}</td>
                  <td className="p-3">{c.title}</td>
                  <td className="p-3">{c.discountValue}%</td>
                  <td className="p-3">
                    {c.usedCount}
                    {c.maxUses != null ? ` / ${c.maxUses}` : ""}
                  </td>
                  <td className="p-3">
                    <span
                      className={`text-xs px-2 py-0.5 rounded-full ${
                        c.isActive
                          ? "bg-green-100 text-green-800"
                          : "bg-muted text-muted-foreground"
                      }`}
                    >
                      {c.isActive ? "Active" : "Inactive"}
                    </span>
                  </td>
                  <td className="p-3 text-right space-x-2">
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => void toggleActive(c)}
                    >
                      {c.isActive ? "Deactivate" : "Activate"}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="text-destructive"
                      onClick={() => void handleDelete(c)}
                    >
                      Delete
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New coupon</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div>
              <Label htmlFor="code">Code</Label>
              <Input
                id="code"
                value={form.code}
                onChange={(e) => setForm((f) => ({ ...f, code: e.target.value }))}
                placeholder="SAVE10"
              />
            </div>
            <div>
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                value={form.title}
                onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                placeholder="10% off"
              />
            </div>
            <div>
              <Label htmlFor="discount">Discount %</Label>
              <Input
                id="discount"
                type="number"
                min={0}
                max={100}
                value={form.discountValue}
                onChange={(e) =>
                  setForm((f) => ({ ...f, discountValue: e.target.value }))
                }
              />
            </div>
            <div>
              <Label htmlFor="min">Min order (PHP)</Label>
              <Input
                id="min"
                type="number"
                min={0}
                value={form.minOrderAmount}
                onChange={(e) =>
                  setForm((f) => ({ ...f, minOrderAmount: e.target.value }))
                }
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleCreate()} disabled={saving}>
              {saving ? "Saving…" : "Create"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
