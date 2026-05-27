"use client"

import { useState } from "react"
import { motion } from "framer-motion"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Icon } from "@/components/ui/icon"

export function NewsletterSection() {
  const [email, setEmail] = useState("")
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isSubscribed, setIsSubscribed] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email) return

    setIsSubmitting(true)
    // Simulate API call
    await new Promise((resolve) => setTimeout(resolve, 1000))
    setIsSubmitting(false)
    setIsSubscribed(true)
    setEmail("")
  }

  return (
    <section className="py-16 bg-primary/5">
      <div className="container mx-auto px-4">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="max-w-2xl mx-auto text-center"
        >
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-primary/10 mb-4">
            <Icon name="envelope" className="text-primary" size="lg" />
          </div>
          <h2 className="text-2xl md:text-3xl font-bold mb-2">Stay in the Loop</h2>
          <p className="text-muted-foreground mb-6">
            Subscribe to get exclusive deals, new arrivals, and style tips delivered to your inbox.
          </p>

          {isSubscribed ? (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className="flex items-center justify-center gap-2 text-primary bg-primary/10 rounded-xl p-4"
            >
              <Icon name="check-circle" />
              <span className="font-medium">Thanks for subscribing! Check your inbox soon.</span>
            </motion.div>
          ) : (
            <form onSubmit={handleSubmit} className="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
              <Input
                type="email"
                placeholder="Enter your email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="flex-1 px-5"
                required
              />
              <Button
                type="submit"
                className="px-6"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <Icon name="spinner" className="animate-spin mr-2" />
                ) : (
                  <Icon name="arrow-right" className="mr-2" />
                )}
                Subscribe
              </Button>
            </form>
          )}

          <p className="text-xs text-muted-foreground mt-4">
            By subscribing, you agree to our Privacy Policy. Unsubscribe anytime.
          </p>
        </motion.div>
      </div>
    </section>
  )
}
