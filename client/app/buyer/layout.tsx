"use client"
import Link from "next/link"
import type React from "react"
import { useEffect, useState } from "react"

import { usePathname } from "next/navigation"
import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"
import { useAuth } from "@/context/auth-context"
import { buyerApi } from "@/lib/api"

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

export default function BuyerLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const { user } = useAuth()
  const [displayName, setDisplayName] = useState<string | null>(null)

  useEffect(() => {
    const fetchProfileName = async () => {
      try {
        const res = await buyerApi.getProfile()
        const profile = res.data.profile as { givenName?: string; surname?: string }
        const fullName = `${profile.givenName ?? ""} ${profile.surname ?? ""}`.trim()
        if (fullName) {
          setDisplayName(fullName)
        }
      } catch {
        // fall back to auth user email if profile request fails
      }
    }

    void fetchProfileName()
  }, [])

  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />

      <main className="flex-1">
        <div className="container mx-auto px-4 py-8">
          <div className="flex flex-col lg:flex-row gap-8">
            {/* Sidebar */}
            <aside className="lg:w-64 flex-shrink-0">
              <div className="bg-card border rounded-2xl p-6 sticky top-24">
                <div className="flex items-center gap-3 mb-6 pb-6 border-b min-w-0">
                  <div className="w-12 h-12 md:w-14 md:h-14 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Icon name="user" size="lg" className="text-primary" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold text-sm md:text-base truncate">
                      {displayName || user?.email || "Buyer"}
                    </p>
                    <p className="text-xs md:text-sm text-muted-foreground truncate" title={user?.email || ""}>
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
                        className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-colors ${
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
