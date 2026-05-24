"use client"

import { motion } from "framer-motion"

interface ProductSkeletonProps {
  count?: number
}

export function ProductSkeleton({ count = 8 }: ProductSkeletonProps) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3 sm:gap-4 md:gap-5">
      {Array.from({ length: count }).map((_, index) => (
        <motion.div
          key={index}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: index * 0.05 }}
          className="bg-card rounded-2xl border overflow-hidden"
        >
          {/* Image Skeleton */}
          <div className="relative aspect-[4/3] bg-muted animate-pulse" />
          
          {/* Content Skeleton */}
          <div className="p-4 space-y-3">
            <div className="h-4 bg-muted rounded animate-pulse w-3/4" />
            <div className="h-3 bg-muted rounded animate-pulse w-1/2" />
            <div className="h-3 bg-muted rounded animate-pulse w-1/4" />
            <div className="flex items-center gap-2 pt-2">
              <div className="h-4 bg-muted rounded animate-pulse w-16" />
              <div className="h-3 bg-muted rounded animate-pulse w-12" />
            </div>
          </div>
        </motion.div>
      ))}
    </div>
  )
}

export function SectionSkeleton() {
  return (
    <section className="py-16">
      <div className="container mx-auto px-4">
        {/* Header Skeleton */}
        <div className="flex items-end justify-between mb-8 md:mb-10">
          <div className="space-y-2">
            <div className="h-3 bg-muted rounded animate-pulse w-24" />
            <div className="h-8 bg-muted rounded animate-pulse w-48" />
          </div>
          <div className="hidden sm:block h-10 bg-muted rounded animate-pulse w-28" />
        </div>
        
        {/* Products Skeleton */}
        <ProductSkeleton count={8} />
      </div>
    </section>
  )
}
