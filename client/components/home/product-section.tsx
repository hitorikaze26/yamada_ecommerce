"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import type { Product } from "@/lib/types"
import { ProductCard } from "@/components/product/product-card"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"

interface ProductSectionProps {
  title: string
  subtitle: string
  products: Product[]
  viewAllHref: string
}

export function ProductSection({ title, subtitle, products, viewAllHref }: ProductSectionProps) {
  return (
    <section className="py-16">
      <div className="container mx-auto px-4">
        <div className="flex items-end justify-between mb-8 md:mb-10">
          <div className="space-y-1">
            <span className="text-xs font-semibold text-primary uppercase tracking-wider">{subtitle}</span>
            <h2 className="text-2xl md:text-3xl font-bold">{title}</h2>
          </div>
          <Button variant="outline" asChild className="hidden sm:flex rounded-full group">
            <Link href={viewAllHref}>
              View All
              <Icon name="arrow-right" className="ml-2 group-hover:translate-x-1 transition-transform" />
            </Link>
          </Button>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-4 gap-3 sm:gap-4 md:gap-5">
          {products.slice(0, 8).map((product, index) => (
            <motion.div
              key={product.id}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-50px" }}
              transition={{ delay: index * 0.05, duration: 0.4 }}
            >
              <ProductCard product={product} />
            </motion.div>
          ))}
        </div>

        <div className="mt-8 text-center sm:hidden">
          <Button variant="outline" asChild>
            <Link href={viewAllHref}>
              View All
              <Icon name="arrow-right" className="ml-2" />
            </Link>
          </Button>
        </div>
      </div>
    </section>
  )
}
