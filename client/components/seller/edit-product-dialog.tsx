"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { productsApi, sellerApi } from "@/lib/api"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { toast } from "sonner"

interface EditProductDialogProps {
  productId: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function EditProductDialog({ productId, open, onOpenChange }: EditProductDialogProps) {
  const [isLoading, setIsLoading] = useState(false)
  const [isSaving, setIsSaving] = useState(false)
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [price, setPrice] = useState("")
  const [salePrice, setSalePrice] = useState("")

  useEffect(() => {
    if (!open || !productId) return
    const load = async () => {
      setIsLoading(true)
      try {
        const res = await productsApi.getById(productId)
        const data = (res.data as { product?: Record<string, unknown> })?.product
        if (!data) return
        setName(String(data.name ?? ""))
        setDescription(String(data.description ?? ""))
        setPrice(data.price != null ? String(data.price) : "")
        setSalePrice(data.sale_price != null ? String(data.sale_price) : "")
      } catch {
        toast.error("Failed to load product")
      } finally {
        setIsLoading(false)
      }
    }
    void load()
  }, [open, productId])

  const handleSave = async () => {
    if (!productId) return
    setIsSaving(true)
    try {
      await sellerApi.updateProduct(productId, {
        name,
        description,
        price: price !== "" ? Number(price) : undefined,
        ...(salePrice !== "" ? { sale_price: Number(salePrice) } : {}),
      })
      toast.success("Product updated")
      onOpenChange(false)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
        "Failed to update product"
      toast.error(msg)
    } finally {
      setIsSaving(false)
    }
  }

  const inputCls =
    "w-full px-4 py-2.5 rounded-xl border bg-background text-sm focus:ring-2 focus:ring-primary outline-none"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Edit product</DialogTitle>
        </DialogHeader>

        {isLoading ? (
          <p className="text-sm text-muted-foreground py-6">Loading…</p>
        ) : (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1.5">Product name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className={inputCls}
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1.5">Description</label>
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
                className={inputCls}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium mb-1.5">Price (PHP)</label>
                <input
                  type="number"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                  min="0"
                  step="0.01"
                  className={inputCls}
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1.5">Sale price</label>
                <input
                  type="number"
                  value={salePrice}
                  onChange={(e) => setSalePrice(e.target.value)}
                  min="0"
                  step="0.01"
                  className={inputCls}
                />
              </div>
            </div>

            <div className="flex flex-wrap gap-2 pt-2">
              <Button type="button" onClick={() => void handleSave()} disabled={isSaving}>
                {isSaving ? "Saving…" : "Save changes"}
              </Button>
              {productId && (
                <Button type="button" variant="outline" asChild>
                  <Link href={`/seller/products/${productId}`} onClick={() => onOpenChange(false)}>
                    <Icon name="external-link" className="mr-2" />
                    Full editor
                  </Link>
                </Button>
              )}
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
