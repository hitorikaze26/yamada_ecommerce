"use client"

import { useState } from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { VariantPicker } from "@/components/product/variant-picker"
import { Button } from "@/components/ui/button"
import { useCart } from "@/context/cart-context"
import type { CartItem, ProductVariation } from "@/lib/types"

interface CartVariantDialogProps {
  item: CartItem
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CartVariantDialog({ item, open, onOpenChange }: CartVariantDialogProps) {
  const { changeVariation } = useCart()
  const [selected, setSelected] = useState<ProductVariation>(item.selectedVariation)

  const variations: ProductVariation[] = Array.isArray(item.product.variations) ? item.product.variations : []

  const handleConfirm = () => {
    if (selected.id !== item.selectedVariation.id) {
      changeVariation(item.id, selected)
    }
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{item.product.name}</DialogTitle>
        </DialogHeader>
        <VariantPicker
          variations={variations}
          selected={selected}
          onSelect={setSelected}
        />
        <div className="flex gap-3 justify-end pt-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            onClick={handleConfirm}
            disabled={selected.id === item.selectedVariation.id}
          >
            Update
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
