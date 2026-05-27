"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { CATEGORIES } from "@/lib/types"

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.08,
    },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 20, scale: 0.95 },
  visible: {
    opacity: 1,
    y: 0,
    scale: 1,
    transition: {
      duration: 0.4,
      ease: "easeOut" as const,
    },
  },
}

export function CategorySection() {
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
            Browse Collection
          </span>
          <h2 className="text-2xl md:text-3xl font-semibold mb-2">Shop by Category</h2>
          <p className="text-muted-foreground text-sm md:text-base">
            Find exactly what you&apos;re looking for
          </p>
        </motion.div>

        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-100px" }}
          className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 md:gap-4"
        >
          {CATEGORIES.map((category) => (
            <motion.div key={category.id} variants={itemVariants} className="h-full">
              <Link
                href={`/search?category=${category.id}`}
                className="group flex h-full flex-col items-center p-4 md:p-6 bg-card rounded-xl border hover:border-primary/50 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
              >
                <div className="w-12 h-12 md:w-16 md:h-16 rounded-full bg-gradient-to-br from-primary/10 to-primary/5 flex items-center justify-center mb-3 md:mb-4 group-hover:scale-110 transition-transform duration-300">
                  <Icon name={category.icon} size="lg" className="text-primary" />
                </div>
                <span className="text-xs md:text-sm font-medium text-center group-hover:text-primary transition-colors">
                  {category.name}
                </span>
              </Link>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
