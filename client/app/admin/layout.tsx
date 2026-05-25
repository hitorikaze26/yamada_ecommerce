"use client"
import Link from "next/link"
import type React from "react"
import Swal from "sweetalert2"

import { useCallback, useEffect, useMemo, useState } from "react"
import { usePathname } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { ChatInboxButton } from "@/components/chat/chat-inbox-button"
import { ProtectedRoute } from "@/components/auth/protected-route"
import { useAuth } from "@/context/auth-context"
import { NotificationModal, type NotificationItem } from "@/components/notifications/notification-modal"
import { notificationsApi, type NotificationDto } from "@/lib/api"

const sidebarLinks = [
  { href: "/admin", label: "Dashboard", icon: "home", exact: true },
  { href: "/admin/analytics", label: "Analytics", icon: "chart-histogram" },
  { href: "/admin/users", label: "Users", icon: "users" },
  { href: "/admin/shops", label: "Shops", icon: "shopping-bag" },
  { href: "/admin/products", label: "Products", icon: "box" },
  { href: "/admin/orders", label: "Orders", icon: "shopping-bag" },
  { href: "/admin/refunds", label: "Refunds", icon: "receipt" },
  { href: "/admin/riders", label: "Riders", icon: "truck-side" },
  { href: "/admin/reports", label: "Reports", icon: "exclamation" },
  { href: "/admin/categories", label: "Categories", icon: "tags" },
  { href: "/admin/commission", label: "Commission", icon: "percentage" },
  { href: "/admin/coupons", label: "Coupons", icon: "ticket" },
  { href: "/admin/settings", label: "Settings", icon: "settings" },
]

function AdminLayoutContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const { logout, user } = useAuth()
  const [notifications, setNotifications] = useState<NotificationItem[]>([])
  const [isNotificationOpen, setIsNotificationOpen] = useState(false)

  const unreadNotificationCount = useMemo(
    () => notifications.filter((n) => !n.read).length,
    [notifications],
  )

  const fetchNotifications = useCallback(async () => {
    try {
      const response = await notificationsApi.getAll({
        role: "admin",
        limit: 100,
      })
      const items: NotificationItem[] = (response.data.notifications || []).map(
        (n: NotificationDto): NotificationItem => ({
          id: String(n.id),
          title: n.title,
          description: n.description ?? "",
          createdAt: n.createdAt ?? "",
          read: n.read,
        }),
      )
      setNotifications(items)
    } catch {
      setNotifications([])
    }
  }, [])

  useEffect(() => {
    void fetchNotifications()
    const interval = setInterval(() => void fetchNotifications(), 30000)
    return () => clearInterval(interval)
  }, [fetchNotifications])

  useEffect(() => {
    if (isNotificationOpen) {
      void fetchNotifications()
    }
  }, [isNotificationOpen, fetchNotifications])

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

  const isLinkActive = (href: string, exact?: boolean) => {
    if (exact) return pathname === href
    return pathname === href || pathname.startsWith(`${href}/`)
  }

  return (
    <div className="min-h-screen flex bg-muted/30">
      <aside className="w-64 bg-slate-900 text-white flex-shrink-0 hidden lg:flex flex-col">
        <div className="p-6 border-b border-slate-700">
          <Link href="/admin" className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
              <span className="font-bold text-lg text-primary-foreground">Y</span>
            </div>
            <div>
              <span className="font-bold text-lg">Yamada</span>
              <span className="text-xs text-slate-400 block">Admin Panel</span>
            </div>
          </Link>
        </div>

        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          {sidebarLinks.map((link) => {
            const isActive = isLinkActive(link.href, link.exact)
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-colors ${
                  isActive ? "bg-primary text-primary-foreground" : "hover:bg-slate-800 text-slate-300 hover:text-white"
                }`}
              >
                <Icon name={link.icon} />
                <span className="font-medium">{link.label}</span>
              </Link>
            )
          })}
        </nav>

        <div className="p-4 border-t border-slate-700">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-4 py-3 rounded-xl w-full text-slate-300 hover:bg-slate-800 hover:text-white transition-colors"
          >
            <Icon name="sign-out-alt" />
            <span className="font-medium">Logout</span>
          </button>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-h-screen">
        <header className="h-16 bg-card border-b flex items-center justify-between px-6">
          <div className="lg:hidden">
            <Link href="/admin" className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                <span className="text-primary-foreground font-bold">Y</span>
              </div>
              <span className="font-bold">Admin</span>
            </Link>
          </div>

          <div className="hidden lg:block">
            <h1 className="font-semibold capitalize">
              {pathname === "/admin" ? "Dashboard" : pathname.split("/").pop()?.replace("-", " ")}
            </h1>
          </div>

          <div className="flex items-center gap-4">
            <DarkModeToggle />
            <ChatInboxButton className="relative w-10 h-10 rounded-full hover:bg-muted" />
            <button
              type="button"
              className="relative w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
              onClick={() => setIsNotificationOpen(true)}
              aria-label="Open notifications"
            >
              <Icon name="bell" />
              {unreadNotificationCount > 0 && (
                <span className="absolute top-1 right-1 w-2.5 h-2.5 bg-red-500 rounded-full" />
              )}
            </button>
            <div className="flex items-center gap-3 pl-4 border-l">
              <div className="w-10 h-10 rounded-full bg-slate-900 flex items-center justify-center">
                <Icon name="user-shield" className="text-white" />
              </div>
              <div className="hidden sm:block">
                <p className="text-sm font-medium">
                  {user ? `${user.givenName} ${user.surname}`.trim() || user.email : "Administrator"}
                </p>
                <p className="text-xs text-muted-foreground">Administrator</p>
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1 p-6 overflow-auto">{children}</main>

        <NotificationModal
          open={isNotificationOpen}
          notifications={notifications}
          onClose={() => setIsNotificationOpen(false)}
          onMarkAllAsRead={async () => {
            setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
            try {
              await notificationsApi.markAllAsRead({ role: "admin" })
            } catch {
              // ignore
            }
          }}
          onMarkAsRead={async (id: string) => {
            try {
              await notificationsApi.markAsRead(Number(id))
              setNotifications((prev) =>
                prev.map((n) => (n.id === id ? { ...n, read: true } : n)),
              )
            } catch {
              // ignore
            }
          }}
        />
      </div>
    </div>
  )
}

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute allowedRoles={["admin"]}>
      <AdminLayoutContent>{children}</AdminLayoutContent>
    </ProtectedRoute>
  )
}
