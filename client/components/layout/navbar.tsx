"use client"

import { Suspense, useCallback, useEffect, useState } from "react"
import Link from "next/link"
import { usePathname, useRouter, useSearchParams } from "next/navigation"
import Swal from "sweetalert2"
import "sweetalert2/dist/sweetalert2.min.css"
import { useAuth } from "@/context/auth-context"
import { useCart } from "@/context/cart-context"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { SearchBox } from "@/components/ui/search-box"
import { CartDrawer } from "@/components/cart/cart-drawer"
import { CATEGORIES } from "@/lib/types"
import { NotificationModal } from "@/components/notifications/notification-modal"
import { ChatInboxButton } from "@/components/chat/chat-inbox-button"
import { useNotifications } from "@/context/notification-context"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu"
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet"

function NavbarFallback() {
  return <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur h-16" />
}

function NavbarContent() {
  const { user, isAuthenticated, logout, getRole } = useAuth()
  const { itemCount } = useCart()
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const sellerShopMode =
    searchParams.get("shop") === "1" ||
    pathname.startsWith("/home") ||
    pathname.startsWith("/search") ||
    pathname.startsWith("/product/") ||
    pathname.startsWith("/cart") ||
    pathname.startsWith("/checkout") ||
    pathname.startsWith("/store/")
  const [isCartOpen, setIsCartOpen] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const [isNotificationOpen, setIsNotificationOpen] = useState(false)
  const [openChatParam, setOpenChatParam] = useState<string | null>(null)
  const { notifications, unreadCount: unreadNotificationCount, markAsRead: handleMarkNotificationAsRead, markAllAsRead: handleMarkAllNotificationsRead } = useNotifications()

  const role = getRole()

  useEffect(() => {
    const openChatId = searchParams.get("openChat")
    if (openChatId) setOpenChatParam(openChatId)
  }, [searchParams])

  const handleOpenChatHandled = useCallback(() => {
    setOpenChatParam(null)
    const params = new URLSearchParams(searchParams.toString())
    params.delete("openChat")
    const q = params.toString()
    router.replace(q ? `${pathname}?${q}` : pathname)
  }, [pathname, router, searchParams])

  const getHomeLink = () => {
    if (!isAuthenticated || !role) return "/landing"

    switch (role) {
      case "seller":
        return sellerShopMode ? "/home?shop=1" : "/seller"
      case "rider":
        return "/rider"
      case "admin":
        return "/admin"
      default:
        return "/home"
    }
  }

  // Notifications are managed by the global NotificationContext.

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

  const getDashboardLink = () => {
    switch (role) {
      case "seller":
        return "/seller"
      case "rider":
        return "/rider"
      case "admin":
        return "/admin"
      default:
        return "/buyer/profile"
    }
  }

  const getProfileMenuLink = () => {
    if (role === "seller") return "/seller/branding"
    return getDashboardLink()
  }

  const getProfileMenuLabel = () => {
    if (role === "seller") return "My profile"
    if (role === "buyer") return "My profile"
    return "Dashboard"
  }

  const getProfileMenuIcon = () => {
    if (role === "seller" || role === "buyer") return "user"
    return "dashboard"
  }

  const getSettingsLink = () => {
    switch (role) {
      case "buyer":
        return "/buyer/settings"
      case "seller":
        return "/seller/settings"
      default:
        return "/settings"
    }
  }

  const getRoleBadge = () => {
    if (!role || role === "buyer") return null
    const colors = {
      seller: "bg-primary text-primary-foreground",
      rider: "bg-accent text-accent-foreground",
      admin: "bg-destructive text-destructive-foreground",
    }
    return (
      <span className={`text-xs px-2 py-0.5 rounded-full ${colors[role]}`}>
        {role.charAt(0).toUpperCase() + role.slice(1)}
      </span>
    )
  }

  return (
    <>
      <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto px-4">
          <div className="flex h-16 items-center justify-between gap-4">
            {/* Logo */}
            <Link href={getHomeLink()} className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center">
                <span className="text-primary-foreground font-bold text-xl">Y</span>
              </div>
              <span className="hidden sm:block text-xl font-semibold text-foreground">Yamada</span>
            </Link>

            {/* Desktop Navigation */}
            <nav className="hidden lg:flex items-center gap-6">
              <Link
                href="/search?sort=newest"
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
              >
                New Arrivals
              </Link>
              <Link
                href="/search?sort=popular"
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
              >
                Best Sellers
              </Link>

              {/* Categories Dropdown */}
              <DropdownMenu>
                <DropdownMenuTrigger className="flex items-center gap-1 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors">
                  Categories
                  <Icon name="angle-small-down" size="sm" />
                </DropdownMenuTrigger>
                <DropdownMenuContent align="start" className="w-56">
                  {CATEGORIES.map((category) => (
                    <DropdownMenuItem key={category.id} asChild>
                      <Link href={`/search?category=${category.id}`} className="flex items-center gap-2">
                        <Icon name={category.icon} />
                        {category.name}
                      </Link>
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>

              <Link
                href="/landing"
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
              >
                Why us
              </Link>

              <Link
                href="/about"
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
              >
                About
              </Link>
            </nav>

            {/* Search Bar */}
            <div className="hidden md:flex flex-1 max-w-md mx-4">
              <SearchBox onSearch={(q) => router.push(`/search?q=${encodeURIComponent(q)}`)} />
            </div>

            {/* Right Actions */}
            <div className="flex items-center gap-2">
              <DarkModeToggle />

              {/* Messages - only show if authenticated */}
              {isAuthenticated && role !== "seller" && role !== "rider" && role !== "admin" && (
                <ChatInboxButton
                  className="hidden sm:flex relative"
                  iconSize="lg"
                  openConversationId={openChatParam}
                  onOpenConversationHandled={handleOpenChatHandled}
                />
              )}

              {/* Notifications - only show if authenticated */}
              {isAuthenticated && (
                <Button
                  variant="ghost"
                  size="icon"
                  className="hidden sm:flex relative"
                  onClick={() => setIsNotificationOpen(true)}
                >
                  <Icon name="bell" size="lg" />
                  {unreadNotificationCount > 0 && (
                    <span className="absolute -top-1 -right-1 w-4 h-4 bg-primary text-primary-foreground text-[10px] rounded-full flex items-center justify-center">
                      {unreadNotificationCount > 9 ? "9+" : unreadNotificationCount}
                    </span>
                  )}
                  <span className="sr-only">Notifications</span>
                </Button>
              )}

              {/* Cart */}
              <Button variant="ghost" size="icon" className="relative" onClick={() => setIsCartOpen(true)}>
                <Icon name="shopping-cart" size="lg" />
                {itemCount > 0 && (
                  <span className="absolute -top-1 -right-1 w-5 h-5 bg-primary text-primary-foreground text-xs rounded-full flex items-center justify-center">
                    {itemCount > 99 ? "99+" : itemCount}
                  </span>
                )}
                <span className="sr-only">Cart</span>
              </Button>

              {/* Profile / Auth */}
              {isAuthenticated ? (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" className="relative">
                      <Icon name="user" size="lg" />
                      <span className="sr-only">Profile menu</span>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-56">
                    <div className="px-2 py-1.5">
                      <p className="text-sm font-medium">
                        {user?.givenName} {user?.surname}
                      </p>
                      <p className="text-xs text-muted-foreground">{user?.email}</p>
                      {getRoleBadge()}
                    </div>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem asChild>
                      <Link href={getProfileMenuLink()}>
                        <Icon name={getProfileMenuIcon()} className="mr-2" />
                        {getProfileMenuLabel()}
                      </Link>
                    </DropdownMenuItem>
                    {role === "seller" && (
                      <DropdownMenuItem asChild>
                        <Link href="/seller">
                          <Icon name="dashboard" className="mr-2" />
                          Seller Center
                        </Link>
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem asChild>
                      <Link href={getSettingsLink()}>
                        <Icon name="settings" className="mr-2" />
                        Settings
                      </Link>
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={handleLogout} className="text-destructive">
                      <Icon name="sign-out-alt" className="mr-2" />
                      Logout
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : (
                <Button
                  variant="default"
                  size="sm"
                  onClick={() => router.push("/auth/login?role=buyer")}
                  className="hidden sm:flex"
                >
                  Sign In
                </Button>
              )}

              {/* Mobile Menu Toggle */}
              <Sheet open={isMobileMenuOpen} onOpenChange={setIsMobileMenuOpen}>
                <SheetTrigger asChild>
                  <Button variant="ghost" size="icon" className="lg:hidden">
                    <Icon name="menu-burger" size="lg" />
                    <span className="sr-only">Menu</span>
                  </Button>
                </SheetTrigger>
                <SheetContent side="right" className="w-80">
                  <div className="flex flex-col gap-6 mt-6">
                    {/* Mobile Search */}
                    <div className="md:hidden">
                      <SearchBox
                        onSearch={(q) => {
                          router.push(`/search?q=${encodeURIComponent(q)}`)
                          setIsMobileMenuOpen(false)
                        }}
                      />
                    </div>

                    {/* Mobile Nav Links */}
                    <nav className="flex flex-col gap-4">
                      <Link
                        href="/search?sort=newest"
                        className="text-lg font-medium"
                        onClick={() => setIsMobileMenuOpen(false)}
                      >
                        New Arrivals
                      </Link>
                      <Link
                        href="/search?sort=popular"
                        className="text-lg font-medium"
                        onClick={() => setIsMobileMenuOpen(false)}
                      >
                        Best Sellers
                      </Link>
                      <div className="border-t pt-4">
                        <p className="text-sm font-semibold text-muted-foreground mb-2">Categories</p>
                        {CATEGORIES.map((category) => (
                          <Link
                            key={category.id}
                            href={`/search?category=${category.id}`}
                            className="flex items-center gap-2 py-2 text-sm"
                            onClick={() => setIsMobileMenuOpen(false)}
                          >
                            <Icon name={category.icon} />
                            {category.name}
                          </Link>
                        ))}
                      </div>
                      <Link
                        href="/landing"
                        className="text-lg font-medium border-t pt-4"
                        onClick={() => setIsMobileMenuOpen(false)}
                      >
                        Why us
                      </Link>
                      <Link
                        href="/about"
                        className="text-lg font-medium border-t pt-4"
                        onClick={() => setIsMobileMenuOpen(false)}
                      >
                        About
                      </Link>
                    </nav>

                    {/* Mobile Auth */}
                    {!isAuthenticated && (
                      <div className="border-t pt-4 flex flex-col gap-2">
                        <Button
                          onClick={() => {
                            router.push("/auth/login?role=buyer")
                            setIsMobileMenuOpen(false)
                          }}
                        >
                          Sign In
                        </Button>
                        <Button
                          variant="outline"
                          onClick={() => {
                            router.push("/auth/register/buyer")
                            setIsMobileMenuOpen(false)
                          }}
                        >
                          Create Account
                        </Button>
                      </div>
                    )}
                  </div>
                </SheetContent>
              </Sheet>
            </div>
          </div>
        </div>
      </header>

      {/* Cart Drawer */}
      <CartDrawer open={isCartOpen} onClose={() => setIsCartOpen(false)} />

      {/* Notifications Modal */}
      {isAuthenticated && (
        <NotificationModal
          open={isNotificationOpen}
          notifications={notifications}
          onClose={() => setIsNotificationOpen(false)}
          onMarkAllAsRead={handleMarkAllNotificationsRead}
          onMarkAsRead={handleMarkNotificationAsRead}
        />
      )}

    </>
  )
}

export function Navbar() {
  return (
    <Suspense fallback={<NavbarFallback />}>
      <NavbarContent />
    </Suspense>
  )
}
