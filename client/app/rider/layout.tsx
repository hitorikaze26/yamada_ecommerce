"use client"
import Link from "next/link"
import type React from "react"
import Swal from "sweetalert2"
import "sweetalert2/dist/sweetalert2.min.css"

import { usePathname, useRouter } from "next/navigation"
import { useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { ChatInboxButton } from "@/components/chat/chat-inbox-button"
import { useAuth } from "@/context/auth-context"
import { ProtectedRoute } from "@/components/auth/protected-route"

const sidebarLinks = [
  { href: "/rider", label: "Dashboard", icon: "home" },
  { href: "/rider/deliveries", label: "Deliveries", icon: "truck-container" },
  { href: "/rider/history", label: "History", icon: "rectangle-vertical-history" },
  { href: "/rider/earnings", label: "Earnings", icon: "peso-sign" },
  { href: "/rider/profile", label: "Profile", icon: "user" },
  { href: "/rider/report", label: "Report", icon: "exclamation" },
  { href: "/rider/settings", label: "Settings", icon: "settings" },
]

const pendingOnlyHrefs = new Set(["/rider", "/rider/profile", "/rider/settings"])

function RiderLayoutContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const { user, logout, isVerified } = useAuth()

  useEffect(() => {
    if (user && !isVerified() && !pendingOnlyHrefs.has(pathname)) {
      router.replace("/rider")
    }
  }, [user, pathname, router, isVerified])

  const visibleLinks = sidebarLinks.filter(
    (link) => isVerified() || pendingOnlyHrefs.has(link.href),
  )

  const handleLogout = async () => {
    const result = await Swal.fire({
      title: "Logout",
      text: "Are you sure you want to logout?",
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Yes, logout",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#ef4444",
    })

    if (result.isConfirmed) {
      await logout()
    }
  }

  const displayName = user
    ? [user.givenName, user.surname].filter(Boolean).join(" ") || user.email
    : "Rider"

  return (
    <div className="min-h-screen flex bg-muted/30">
      {/* Sidebar */}
      <aside className="w-64 bg-card border-r flex-shrink-0 hidden lg:flex flex-col">
        <div className="p-6 border-b">
          <Link href="/rider" className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
              <Icon name="truck-container" className="text-primary-foreground" />
            </div>
            <div>
              <span className="font-bold text-lg">Yamada</span>
              <span className="text-xs text-muted-foreground block">Rider App</span>
            </div>
          </Link>
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {visibleLinks.map((link) => {
            const isActive = pathname === link.href
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-colors text-sm font-medium ${
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

        <div className="p-4 border-t">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-4 py-3 rounded-xl w-full text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          >
            <Icon name="sign-out-alt" />
            <span className="font-medium">Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen">
        <header className="h-16 bg-card border-b flex items-center justify-between px-6">
          <div className="lg:hidden">
            <Link href="/rider" className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                <Icon name="truck-container" className="text-primary-foreground" size="sm" />
              </div>
              <span className="font-bold">Rider App</span>
            </Link>
          </div>

          <div className="hidden lg:block">
            <h1 className="font-semibold capitalize">
              {pathname === "/rider" ? "Dashboard" : pathname.split("/").pop()?.replace("-", " ")}
            </h1>
          </div>

          <div className="flex items-center gap-4">
            <DarkModeToggle />
            <ChatInboxButton className="relative w-10 h-10 rounded-full hover:bg-muted" />
            <div className="flex items-center gap-3 pl-4 border-l">
              <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                <Icon name="user" className="text-primary" />
              </div>
              <div className="hidden sm:block">
                <p className="text-sm font-medium">{displayName}</p>
                <p className="text-xs text-muted-foreground">Rider</p>
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </div>
    </div>
  )
}

export default function RiderLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute allowedRoles={["rider"]}>
      <RiderLayoutContent>{children}</RiderLayoutContent>
    </ProtectedRoute>
  )
}
