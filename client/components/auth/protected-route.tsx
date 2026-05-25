"use client"

import { useEffect, useRef, type ReactNode } from "react"
import { usePathname, useRouter } from "next/navigation"
import { useAuth } from "@/context/auth-context"
import type { UserRole } from "@/lib/types"
import { dashboardRoutes } from "@/lib/auth/session"
import { canAccessRoute, roleForPathname } from "@/lib/auth/rbac"
import { Icon } from "@/components/ui/icon"

interface ProtectedRouteProps {
  children: ReactNode
  allowedRoles?: UserRole[]
}

export function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading, user } = useAuth()
  const router = useRouter()
  const pathname = usePathname()
  const redirectingRef = useRef(false)

  useEffect(() => {
    if (isLoading) return
    if (redirectingRef.current) return

    if (!isAuthenticated) {
      redirectingRef.current = true
      const pathRole = roleForPathname(pathname)
      const params = new URLSearchParams()
      if (pathRole) params.set("role", pathRole)
      if (pathname) params.set("redirect", pathname)
      const qs = params.toString()
      router.replace(`/auth/login${qs ? `?${qs}` : ""}`)
      return
    }

    if (user) {
      if (allowedRoles && !allowedRoles.includes(user.role)) {
        const target = dashboardRoutes[user.role]
        if (pathname !== target) {
          redirectingRef.current = true
          router.replace(target)
        }
        return
      }
      if (!canAccessRoute(user.role, pathname)) {
        const target = dashboardRoutes[user.role]
        if (pathname !== target) {
          redirectingRef.current = true
          router.replace(target)
        }
      }
    }
  }, [isLoading, isAuthenticated, user, allowedRoles, router, pathname])

  useEffect(() => {
    redirectingRef.current = false
  }, [pathname])

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <Icon name="spinner" className="animate-spin text-primary" size="xl" />
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return null
  }

  if (allowedRoles && user && !allowedRoles.includes(user.role)) {
    return null
  }

  return <>{children}</>
}
