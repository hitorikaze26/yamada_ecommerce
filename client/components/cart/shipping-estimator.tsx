"use client"

import { useState } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { useCart } from "@/context/cart-context"
import { SHIPPING_RATES, FREE_SHIPPING_THRESHOLD } from "@/lib/shipping"

interface ShippingEstimatorProps {
  className?: string
}

export function ShippingEstimator({ className }: ShippingEstimatorProps) {
  const { updateShippingEstimate } = useCart()
  const [isOpen, setIsOpen] = useState(false)

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className={className}>
          <Icon name="truck-loading" className="mr-2" size="sm" />
          Shipping Info
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Shipping Fee Information</DialogTitle>
        </DialogHeader>
        
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            Shipping fees are calculated based on the distance between seller and buyer locations:
          </p>
          
          <div className="space-y-3">
            <div className="flex justify-between items-center p-3 bg-muted/50 rounded-lg">
              <div>
                <p className="font-medium text-sm">Same City</p>
                <p className="text-xs text-muted-foreground">Same region, province & city</p>
              </div>
              <span className="font-semibold text-green-600">₱{SHIPPING_RATES.SAME_CITY}</span>
            </div>
            
            <div className="flex justify-between items-center p-3 bg-muted/50 rounded-lg">
              <div>
                <p className="font-medium text-sm">Same Province</p>
                <p className="text-xs text-muted-foreground">Same region & province, different city</p>
              </div>
              <span className="font-semibold text-blue-600">₱{SHIPPING_RATES.SAME_PROVINCE}</span>
            </div>
            
            <div className="flex justify-between items-center p-3 bg-muted/50 rounded-lg">
              <div>
                <p className="font-medium text-sm">Same Region</p>
                <p className="text-xs text-muted-foreground">Same region, different province</p>
              </div>
              <span className="font-semibold text-orange-600">₱{SHIPPING_RATES.SAME_REGION}</span>
            </div>
            
            <div className="flex justify-between items-center p-3 bg-muted/50 rounded-lg">
              <div>
                <p className="font-medium text-sm">Different Region</p>
                <p className="text-xs text-muted-foreground">Different regions</p>
              </div>
              <span className="font-semibold text-red-600">₱{SHIPPING_RATES.DIFFERENT_REGION}</span>
            </div>
          </div>
          
          <div className="p-3 bg-primary/10 rounded-lg">
            <p className="text-sm text-primary font-medium">
              <Icon name="gift" className="inline mr-1" size="sm" />
              Free shipping on orders over ₱{FREE_SHIPPING_THRESHOLD.toLocaleString()}!
            </p>
          </div>
          
          <p className="text-xs text-muted-foreground">
            Final shipping fee will be calculated at checkout based on the seller's location.
          </p>
          
          <Button onClick={() => setIsOpen(false)} className="w-full">
            Got it
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}