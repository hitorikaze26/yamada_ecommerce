"use client"

import Link from "next/link"
import { usePathname, useRouter } from "next/navigation"
import type React from "react"
import { useEffect } from "react"
import { useAuth } from "@/context/auth-context"
import { ChatInboxButton } from "@/components/chat/chat-inbox-button"
import Swal from "sweetalert2"

const navItems = [
  { href: "/rider/mobile", label: "Home", icon: "home" },
  { href: "/rider/mobile/deliveries", label: "Deliveries", icon: "truck" },
  { href: "/rider/mobile/earnings", label: "Earnings", icon: "wallet" },
  { href: "/rider/mobile/history", label: "History", icon: "history" },
  { href: "/rider/mobile/profile", label: "Profile", icon: "user" },
]

const pendingOnlyHrefs = new Set(["/rider/mobile", "/rider/mobile/profile", "/rider/mobile/settings"])

// Pink color scheme matching Flutter
const kPrimaryPink = "#E891A0"

export default function RiderMobileLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const router = useRouter()
  const { user, logout, isVerified } = useAuth()

  useEffect(() => {
    if (user && !isVerified() && !pendingOnlyHrefs.has(pathname)) {
      router.replace("/rider/mobile")
    }
  }, [user, pathname, router, isVerified])

  const visibleNav = navItems.filter(
    (item) => isVerified() || pendingOnlyHrefs.has(item.href),
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

  return (
    <div className="min-h-screen bg-[#FDF2F2] dark:bg-gray-900 flex flex-col max-w-md mx-auto border-x border-gray-200 dark:border-gray-800">
      {/* Header */}
      <header className="bg-[#FDF2F2] dark:bg-gray-900 px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#E891A0] to-[#F5A5B0] flex items-center justify-center">
            <span className="text-white font-bold text-sm">Y</span>
          </div>
          <span className="font-bold text-lg text-[#E891A0]">Yamada</span>
        </div>
        <div className="flex items-center gap-1">
          <ChatInboxButton className="h-9 w-9" iconSize="sm" />
        {pathname === "/rider/mobile/profile" && (
          <button
            onClick={handleLogout}
            className="p-2 text-red-500 hover:bg-red-50 rounded-full transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" x2="9" y1="12" y2="12" />
            </svg>
          </button>
        )}
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto pb-20">{children}</main>

      {/* Bottom Navigation */}
      <nav className="fixed bottom-0 left-0 right-0 bg-white dark:bg-gray-800 border-t border-gray-100 dark:border-gray-700 max-w-md mx-auto">
        <div className="flex justify-around items-center py-2">
          {visibleNav.map((item) => {
            const isActive = pathname === item.href
            const showLabel = item.label !== "Profile"
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex flex-col items-center gap-1 px-3 py-2 rounded-xl transition-all ${
                  isActive ? "bg-[#E891A0]/10 dark:bg-[#E891A0]/20" : ""
                }`}
              >
                <NavIcon name={item.icon} isActive={isActive} />
                {showLabel && (
                  <span
                    className={`text-xs ${
                      isActive
                        ? "text-[#E891A0] font-medium"
                        : "text-gray-400 dark:text-gray-500"
                    }`}
                  >
                    {item.label}
                  </span>
                )}
              </Link>
            )
          })}
        </div>
      </nav>
    </div>
  )
}

function NavIcon({ name, isActive }: { name: string; isActive: boolean }) {
  const color = isActive ? kPrimaryPink : "#9CA3AF"
  const size = 24

  switch (name) {
    case "home":
      return (
        <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
          <polyline points="9 22 9 12 15 12 15 22" />
        </svg>
      )
    case "truck":
      return (
        <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2" />
          <path d="M15 18H9" />
          <path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14" />
          <circle cx="17" cy="18" r="2" />
          <circle cx="7" cy="18" r="2" />
        </svg>
      )
    case "wallet":
      return (
        <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" />
          <path d="M3 5v14a2 2 0 0 0 2 2h16v-5" />
          <path d="M18 12a2 2 0 0 0 0 4h4v-4Z" />
        </svg>
      )
    case "history":
      return (
        <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
          <path d="M3 3v5h5" />
          <path d="M12 7v5l4 2" />
        </svg>
      )
    case "user":
      return (
        <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" />
          <circle cx="12" cy="7" r="4" />
        </svg>
      )
    default:
      return null
  }
}
