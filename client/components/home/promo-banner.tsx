"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"

export function PromoBanner() {
  return (
    <section className="py-8">
      <div className="container mx-auto px-4">
        <div className="grid md:grid-cols-2 gap-4">
          {/* Free Shipping Banner */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-primary/10 to-primary/5 border p-6 md:p-8"
          >
            <div className="relative z-10">
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/20 text-primary text-xs font-semibold mb-3">
                <Icon name="truck" size="sm" />
                Free Delivery
              </div>
              <h3 className="text-xl md:text-2xl font-bold mb-2">Free Shipping on Orders Over ₱1,500</h3>
              <p className="text-muted-foreground text-sm mb-4">
                Enjoy complimentary delivery to your doorstep for qualifying orders.
              </p>
              <Button variant="outline" size="sm" asChild className="rounded-full">
                <Link href="/search">
                  Shop Now
                  <Icon name="arrow-right" className="ml-2" size="sm" />
                </Link>
              </Button>
            </div>
            <div className="absolute -bottom-8 -right-8 w-32 h-32 bg-primary/10 rounded-full blur-2xl" />
          </motion.div>

          {/* New Arrivals Banner */}
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-secondary/30 to-secondary/10 border p-6 md:p-8"
          >
            <div className="relative z-10">
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-secondary text-secondary-foreground text-xs font-semibold mb-3">
                <Icon name="sparkles" size="sm" />
                New Collection
              </div>
              <h3 className="text-xl md:text-2xl font-bold mb-2">Spring/Summer 2026 Collection</h3>
              <p className="text-muted-foreground text-sm mb-4">
                Discover the latest trends and fresh styles for the new season.
              </p>
              <Button size="sm" asChild className="rounded-full">
                <Link href="/search?sort=newest">
                  Explore
                  <Icon name="arrow-right" className="ml-2" size="sm" />
                </Link>
              </Button>
            </div>
            <div className="absolute -bottom-8 -right-8 w-32 h-32 bg-secondary/30 rounded-full blur-2xl" />
          </motion.div>
        </div>
      </div>
    </section>
  )
}
