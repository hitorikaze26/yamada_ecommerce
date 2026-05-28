"use client"
import Link from "next/link"
import type React from "react"
import { useEffect, useState } from "react"

import { usePathname } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"
import { useAuth } from "@/context/auth-context"
import { ProtectedRoute } from "@/components/auth/protected-route"
import { buyerApi } from "@/lib/api"


function readBuyerProfile(data: unknown): { givenName?: string; surname?: string } | null {
  if (!data || typeof data !== "object") return null
  const record = data as Record<string, unknown>
  const profile = (record.profile ?? record) as Record<string, unknown>
  return {
    givenName: profile.givenName as string | undefined,
    surname: profile.surname as string | undefined,
  }
}

const sidebarLinks = [
  { href: "/buyer", label: "Dashboard", icon: "home" },
  { href: "/buyer/orders", label: "My Orders", icon: "shopping-bag" },
  { href: "/buyer/refunds", label: "Refunds", icon: "refund-alt" },
  { href: "/buyer/reports", label: "My Reports", icon: "exclamation" },
  { href: "/buyer/wishlist", label: "Wishlist", icon: "heart" },
  { href: "/buyer/following", label: "Following", icon: "seller-store" },
  { href: "/buyer/recently-viewed", label: "Recently Viewed", icon: "time-past" },
  { href: "/buyer/coupons", label: "Coupons", icon: "ticket-alt" },
  { href: "/buyer/reviews", label: "My Reviews", icon: "star" },
  { href: "/buyer/addresses", label: "Addresses", icon: "map-marker-home" },
  { href: "/buyer/profile", label: "Profile", icon: "user" },
  { href: "/buyer/settings", label: "Settings", icon: "settings" },
  { href: "/buyer/help", label: "Help Center", icon: "interrogation" },
]

function BuyerLayoutContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const { user } = useAuth()
  const [displayName, setDisplayName] = useState<string | null>(null)
  const [sidebarOpen, setSidebarOpen] = useState(false)

  useEffect(() => {
    const fetchProfileName = async () => {
      try {
        const res = await buyerApi.getProfile()
        const profile = readBuyerProfile(res.data)
        const fullName = `${profile?.givenName ?? ""} ${profile?.surname ?? ""}`.trim()
        if (fullName) {
          setDisplayName(fullName)
        }
      } catch {
        // fall back to auth user email if profile request fails
      }
    }

    void fetchProfileName()
  }, [])

  // Close sidebar on route change (mobile)
  useEffect(() => {
    setSidebarOpen(false)
  }, [pathname])

  const sidebarNav = (
    <div className="bg-card border rounded-2xl p-4 lg:p-6">
      <div className="flex items-center gap-3 mb-5 pb-5 border-b min-w-0">
        <div className="w-10 h-10 sm:w-12 sm:h-12 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
          <Icon name="user" size="lg" className="text-primary" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-sm truncate">
            {displayName || user?.email || "Buyer"}
          </p>
          <p className="text-xs text-muted-foreground truncate" title={user?.email || ""}>
            {user?.email}
          </p>
        </div>
      </div>

      <nav className="space-y-1">
        {sidebarLinks.map((link) => {
          const isActive =
            pathname === link.href ||
            (link.href !== "/buyer" && pathname.startsWith(`${link.href}/`))
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-3 px-3 py-2.5 lg:px-4 lg:py-3 rounded-xl transition-colors text-sm lg:text-base ${
                isActive
                  ? "bg-primary text-primary-foreground"
                  : "hover:bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              <Icon name={link.icon} />
              <span className="font-medium">{link.label}</span>
            </Link>
          )
        })}
      </nav>
    </div>
  )

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-4 lg:py-8">
          {/* Mobile sidebar toggle */}
          <div className="flex items-center gap-3 mb-4 lg:hidden">
            <button
              type="button"
              onClick={() => setSidebarOpen(true)}
              className="flex items-center gap-2 px-3 py-2 rounded-xl border bg-card text-sm font-medium hover:bg-muted transition-colors"
              aria-label="Open navigation menu"
            >
              <Icon name="bars" />
              <span>Menu</span>
            </button>
            <span className="text-sm text-muted-foreground">
              {sidebarLinks.find((l) => l.href === pathname || pathname.startsWith(l.href))?.label || "Dashboard"}
            </span>
          </div>

          {/* Mobile drawer overlay */}
          <AnimatePresence>
            {sidebarOpen && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.15 }}
                className="fixed inset-0 z-50 bg-black/50 lg:hidden"
                onClick={() => setSidebarOpen(false)}
              >
                <motion.aside
                  initial={{ x: "-100%" }}
                  animate={{ x: 0 }}
                  exit={{ x: "-100%" }}
                  transition={{ type: "spring", damping: 30, stiffness: 300 }}
                  className="absolute left-0 top-0 bottom-0 w-72 max-w-[85vw] overflow-y-auto bg-background p-4"
                  onClick={(e) => e.stopPropagation()}
                >
                  <div className="flex items-center justify-between mb-4">
                    <span className="font-semibold text-sm">Navigation</span>
                    <button
                      type="button"
                      onClick={() => setSidebarOpen(false)}
                      className="w-8 h-8 rounded-full hover:bg-muted flex items-center justify-center"
                      aria-label="Close menu"
                    >
                      <Icon name="times" />
                    </button>
                  </div>
                  {sidebarNav}
                </motion.aside>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="flex flex-col lg:flex-row gap-6 lg:gap-8">
            {/* Desktop sidebar */}
            <aside className="hidden lg:block lg:w-64 flex-shrink-0">
              <div className="sticky top-24">{sidebarNav}</div>
            </aside>

            {/* Main Content */}
            <div className="flex-1 min-w-0">{children}</div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}

export default function BuyerLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute allowedRoles={["buyer"]}>
      <BuyerLayoutContent>{children}</BuyerLayoutContent>
    </ProtectedRoute>
  )
}
