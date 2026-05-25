"use client"

import Image from "next/image"
import { Icon } from "@/components/ui/icon"
import { ShopLogo } from "@/components/store/shop-logo"
import type { StoreProfile } from "@/lib/stores/types"

interface StoreProfileHeaderProps {
  store: StoreProfile
}

export function StoreProfileHeader({ store }: StoreProfileHeaderProps) {
  return (
    <div className="relative">
      <div className="relative h-36 sm:h-48 md:h-56 w-full overflow-hidden bg-muted rounded-b-2xl">
        {store.bannerUrl ? (
          <Image
            src={store.bannerUrl}
            alt=""
            fill
            sizes="100vw"
            className="object-cover"
            priority
            unoptimized
          />
        ) : (
          <div className="w-full h-full bg-gradient-to-br from-primary/20 via-primary/10 to-muted" />
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-background/90 via-background/20 to-transparent" />
      </div>

      <div className="relative px-4 sm:px-6 -mt-12 sm:-mt-14 pb-4">
        <div className="flex flex-col sm:flex-row sm:items-end gap-4">
          <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-2xl border-4 border-background bg-card overflow-hidden shadow-lg flex-shrink-0">
            <ShopLogo
              src={store.logoUrl}
              alt={store.name}
              width={96}
              height={96}
              className="w-full h-full object-cover"
              unoptimized
            />
          </div>

          <div className="flex-1 min-w-0 pb-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-bold truncate">{store.name}</h1>
              {store.isVerified && (
                <span className="text-[10px] px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
                  Verified
                </span>
              )}
              <span
                className={`text-[10px] px-2 py-0.5 rounded-full font-medium ${
                  store.isOpen
                    ? "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
                    : "bg-muted text-muted-foreground"
                }`}
              >
                {store.isOpen ? "Open now" : "Closed"}
              </span>
            </div>
            {store.tagline && (
              <p className="text-sm text-muted-foreground mt-1 line-clamp-2">{store.tagline}</p>
            )}
            <div className="flex flex-wrap items-center gap-3 mt-2 text-xs text-muted-foreground">
              <span className="flex items-center gap-1">
                <Icon name="star" className="text-amber-500" />
                <span className="font-medium text-foreground">{store.rating.toFixed(1)}</span>
                ({store.reviewCount} reviews)
              </span>
              <span>{store.followersCount.toLocaleString()} followers</span>
              <span>{store.productCount} products</span>
            </div>
          </div>
        </div>

        {store.announcement && (
          <div className="mt-4 rounded-xl border bg-primary/5 border-primary/20 px-4 py-3 text-sm">
            {store.announcement}
          </div>
        )}
      </div>
    </div>
  )
}
