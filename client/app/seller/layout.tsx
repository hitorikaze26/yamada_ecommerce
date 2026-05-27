"use client"
import Link from "next/link"
import type React from "react"
import Swal from "sweetalert2"

import { Suspense, useEffect, useMemo, useState, useCallback } from "react"
import { usePathname, useRouter, useSearchParams } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { ChatInboxButton } from "@/components/chat/chat-inbox-button"
import { useAuth } from "@/context/auth-context"
import { ProtectedRoute } from "@/components/auth/protected-route"
import { NotificationModal, type NotificationItem } from "@/components/notifications/notification-modal"
import { notificationsApi, type NotificationDto, sellerAccountApi } from "@/lib/api"
import {
  isSellerRestrictedPath,
  SELLER_PENDING_SWAL_TEXT,
} from "@/lib/seller-access"

const sidebarLinks = [
  { href: "/seller", label: "Dashboard", icon: "home" },
  { href: "/seller/products", label: "Products", icon: "box" },
  { href: "/seller/orders", label: "Orders", icon: "shopping-bag" },
  { href: "/seller/insights", label: "Store Insights", icon: "chart-simple" },
  { href: "/seller/feedback", label: "Feedback", icon: "comment-alt" },
  { href: "/seller/wallet", label: "Wallet", icon: "wallet" },
  { href: "/seller/refunds", label: "Refunds", icon: "refund-alt" },
  { href: "/seller/coupons", label: "Coupons", icon: "ticket" },
  { href: "/seller/analytics", label: "Analytics", icon: "chart-line-up" },
  { href: "/seller/shop", label: "Shop operations", icon: "shop" },
  { href: "/seller/report", label: "Report Buyer", icon: "exclamation" },
  { href: "/seller/account-settings", label: "Account settings", icon: "settings" },
]

function SellerLayoutInner({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const searchParams = useSearchParams()
  const [pendingChatId, setPendingChatId] = useState<string | null>(null)
  const { user, logout, refreshSellerProfile } = useAuth()
  const [isStoreApproved, setIsStoreApproved] = useState<boolean | null>(null)
  const [storeStatusLabel, setStoreStatusLabel] = useState<string | null>(null)
  const [notifications, setNotifications] = useState<NotificationItem[]>([])
  const [isNotificationOpen, setIsNotificationOpen] = useState(false)
  const [isLoadingNotifications, setIsLoadingNotifications] = useState(false)

  const unreadNotificationCount = useMemo(
    () => notifications.filter((n) => !n.read).length,
    [notifications],
  )

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        await refreshSellerProfile()
        // Get store status from the updated user in context (already loaded by refreshSellerProfile)
        const status = user?.storeStatus as string | null
        if (status) {
          setStoreStatusLabel(status)
          setIsStoreApproved(status === "ACCEPTED")
        } else {
          setIsStoreApproved(false)
        }
      } catch {
        setIsStoreApproved(false)
      }
    }

    void fetchProfile()
  }, [refreshSellerProfile, user?.storeStatus])

  useEffect(() => {
    if (isStoreApproved === false && isSellerRestrictedPath(pathname)) {
      router.replace("/seller")
    }
  }, [isStoreApproved, pathname, router])

  useEffect(() => {
    const id = searchParams.get("openChat")
    if (id) setPendingChatId(id)
  }, [searchParams])

  // Format relative time
  const formatTime = (dateString: string) => {
    if (!dateString) return ""
    const date = new Date(dateString)
    const now = new Date()
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)
    
    if (diffInSeconds < 60) return "Just now"
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`
    return date.toLocaleDateString()
  }

  const fetchNotifications = useCallback(async () => {
    setIsLoadingNotifications(true)
    try {
      // Fetch all notifications for seller (unified across all pages)
      const response = await notificationsApi.getAll({
        role: "seller",
      })
      const items: NotificationItem[] = (response.data.notifications || []).map(
        (n: NotificationDto): NotificationItem => ({
          id: String(n.id),
          title: n.title,
          description: n.description,
          createdAt: formatTime(n.createdAt ?? ""),
          read: n.read,
        }),
      )
      setNotifications(items)
    } catch {
      setNotifications([])
    } finally {
      setIsLoadingNotifications(false)
    }
  }, [])

  // Initial fetch and polling
  useEffect(() => {
    void fetchNotifications()
    
    // Poll for new notifications every 30 seconds
    const interval = setInterval(() => {
      void fetchNotifications()
    }, 30000)
    
    return () => clearInterval(interval)
  }, [fetchNotifications])

  const displayName = user
    ? [user.givenName, user.surname].filter(Boolean).join(" ") || user.email
    : "Shop Owner"

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

  return (
    <div className="min-h-screen flex bg-muted/30">
      {/* Sidebar */}
      <aside className="w-64 bg-card border-r flex-shrink-0 hidden lg:flex flex-col">
        <div className="p-6 border-b">
          <Link href="/seller" className="flex items-center gap-2">
            <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center">
              <span className="text-primary-foreground font-bold text-lg">Y</span>
            </div>
            <div>
              <span className="font-bold text-lg">Yamada</span>
              <span className="text-xs text-muted-foreground block">Seller Center</span>
            </div>
          </Link>
        </div>

        <nav className="flex-1 p-4 space-y-1">
          {sidebarLinks.map((link) => {
            const isActive = pathname === link.href
            const isRestricted =
              isStoreApproved === false && isSellerRestrictedPath(link.href)

            const baseClasses =
              "flex items-center gap-3 px-4 py-3 rounded-xl transition-colors text-sm font-medium"

            if (isRestricted) {
              return (
                <button
                  key={link.href}
                  type="button"
                  onClick={async () => {
                    await Swal.fire({
                      title: "Store Pending Approval",
                      text: SELLER_PENDING_SWAL_TEXT,
                      icon: "info",
                      confirmButtonText: "OK",
                    })
                  }}
                  className={`${baseClasses} text-muted-foreground/70 hover:bg-muted`}
                >
                  <Icon name={link.icon} />
                  <span>{link.label}</span>
                </button>
              )
            }

            return (
              <Link
                key={link.href}
                href={link.href}
                className={`${baseClasses} ${
                  isActive
                    ? "bg-primary text-primary-foreground"
                    : "hover:bg-muted text-muted-foreground hover:text-foreground"
                }`}
              >
                <Icon name={link.icon} />
                <span>{link.label}</span>
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
        {/* Top Header */}
        <header className="h-16 bg-card border-b flex items-center justify-between px-6">
          <div className="lg:hidden">
            <Link href="/seller" className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                <span className="text-primary-foreground font-bold">Y</span>
              </div>
              <span className="font-bold">Seller Center</span>
            </Link>
          </div>

          <div className="hidden lg:block">
            <h1 className="font-semibold capitalize">
              {pathname === "/seller" ? "Dashboard" : pathname.split("/").pop()?.replace("-", " ")}
            </h1>
          </div>

          <div className="flex items-center gap-4">
            <DarkModeToggle />
            <ChatInboxButton
              className="relative w-10 h-10 rounded-full hover:bg-muted"
              openConversationId={pendingChatId}
              onOpenConversationHandled={() => {
                setPendingChatId(null)
                const params = new URLSearchParams(searchParams.toString())
                params.delete("openChat")
                const q = params.toString()
                router.replace(q ? `${pathname}?${q}` : pathname)
              }}
            />
            <button
              className="relative w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
              onClick={() => {
                void fetchNotifications()
                setIsNotificationOpen(true)
              }}
            >
              <Icon name="bell" />
              {unreadNotificationCount > 0 && (
                <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs font-bold rounded-full flex items-center justify-center">
                  {unreadNotificationCount > 9 ? "9+" : unreadNotificationCount}
                </span>
              )}
            </button>
            <div className="flex items-center gap-3 pl-4 border-l">
              <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                <Icon name="user" className="text-primary" />
              </div>
              <div className="hidden sm:block">
                <p className="text-sm font-medium">{displayName}</p>
                <p className="text-xs text-muted-foreground">Seller</p>
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 p-6 overflow-auto">
          {isStoreApproved === false && (
            <div className="mb-4 p-4 rounded-2xl bg-amber-50 border border-amber-200 text-amber-900 text-sm flex items-start gap-3">
              <Icon name="info-circle" className="mt-0.5" />
              <div>
                <p className="font-semibold">Store pending approval</p>
                <p className="text-xs">
                  Your seller account is active, but your store application is currently
                  {" "}
                  {storeStatusLabel ? storeStatusLabel.toLowerCase() : "pending"}. Use Account and Account
                  settings while waiting for approval.
                </p>
              </div>
            </div>
          )}

          {children}
        </main>
      </div>

      <NotificationModal
        open={isNotificationOpen}
        notifications={notifications}
        onClose={() => setIsNotificationOpen(false)}
        onMarkAllAsRead={async () => {
          setNotifications((prev) => prev.map((n) => ({ ...n, read: true })))
          try {
            // Mark all notifications as read across all pages
            await notificationsApi.markAllAsRead({ role: "seller" })
          } catch {
            // If notifications cannot be marked as read, ignore error
          }
        }}
        onMarkAsRead={async (id: string) => {
          try {
            await notificationsApi.markAsRead(Number(id))
            setNotifications((prev) =>
              prev.map((n) => (n.id === id ? { ...n, read: true } : n))
            )
          } catch {
            // If marking as read fails, ignore error
          }
        }}
      />
    </div>
  )
}

export default function SellerLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute allowedRoles={["seller"]}>
      <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
        <SellerLayoutInner>{children}</SellerLayoutInner>
      </Suspense>
    </ProtectedRoute>
  )
}
