"use client"

import Link from "next/link"
import Image from "next/image"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"

interface Shop {
  id: string
  name: string
  logo: string
  tagline: string
  rating: number
  productCount: number
}

interface FeaturedShopsProps {
  shops: Shop[]
}

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
    },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: {
      duration: 0.5,
      ease: "easeOut" as const,
    },
  },
}

export function FeaturedShops({ shops }: FeaturedShopsProps) {
  return (
    <section className="py-12 md:py-20 bg-muted/30">
      <div className="container mx-auto px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="text-center mb-10 md:mb-12"
        >
          <span className="text-xs font-semibold text-primary uppercase tracking-wider mb-2 block">
            Trusted Partners
          </span>
          <h2 className="text-2xl md:text-3xl font-bold mb-2">Featured Shops</h2>
          <p className="text-muted-foreground text-sm md:text-base">
            Discover our curated selection of trusted sellers
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-50px" }}
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6"
        >
          {shops.map((shop) => (
            <motion.div key={shop.id} variants={itemVariants} className="h-full">
              <Link
                href={`/seller/${shop.id}`}
                className="group block h-full bg-card rounded-2xl border p-5 md:p-6 hover:border-primary/50 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
              >
                <div className="flex items-center gap-4 mb-4">
                  <div className="relative w-14 h-14 md:w-16 md:h-16 rounded-full overflow-hidden bg-muted ring-2 ring-transparent group-hover:ring-primary/20 transition-all">
                    <Image
                      src={shop.logo || "/placeholder.svg"}
                      alt={shop.name}
                      fill
                      className="object-cover"
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h3 className="font-semibold group-hover:text-primary transition-colors truncate">
                      {shop.name}
                    </h3>
                    <p className="text-xs md:text-sm text-muted-foreground truncate">{shop.tagline}</p>
                  </div>
                </div>
                <div className="flex items-center justify-between text-xs md:text-sm pt-3 border-t">
                  <div className="flex items-center gap-1">
                    <Icon name="star" className="text-yellow-500" size="sm" />
                    <span className="font-medium">{shop.rating}</span>
                    <span className="text-muted-foreground">rating</span>
                  </div>
                  <span className="text-muted-foreground bg-muted px-2 py-0.5 rounded-full text-xs">
                    {shop.productCount} products
                  </span>
                </div>
              </Link>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
