"use client"

import { useEffect, type ReactNode } from "react"
import { usePathname, useRouter } from "next/navigation"
import { useAuth } from "@/context/auth-context"
import type { UserRole } from "@/lib/types"
import { dashboardRoutes } from "@/lib/auth/session"
import { canAccessRoute, loginPathForRole, roleForPathname } from "@/lib/auth/rbac"
import { Icon } from "@/components/ui/icon"

interface ProtectedRouteProps {
  children: ReactNode
  allowedRoles?: UserRole[]
  redirectTo?: string
}

export function ProtectedRoute({ children, allowedRoles, redirectTo = "/auth/login" }: ProtectedRouteProps) {
  const { isAuthenticated, isLoading, user } = useAuth()
  const router = useRouter()
  const pathname = usePathname()

  useEffect(() => {
    if (!isLoading && !isAuthenticated) {
      const pathRole = roleForPathname(pathname)
      const loginTarget =
        pathRole != null
          ? loginPathForRole(pathRole) + (pathname ? `&redirect=${encodeURIComponent(pathname)}` : "")
          : redirectTo
      router.push(loginTarget)
      return
    }

    if (!isLoading && isAuthenticated && user) {
      if (allowedRoles && !allowedRoles.includes(user.role)) {
        router.push(dashboardRoutes[user.role])
        return
      }
      if (!canAccessRoute(user.role, pathname)) {
        router.push(dashboardRoutes[user.role])
      }
    }
  }, [isLoading, isAuthenticated, user, allowedRoles, router, redirectTo, pathname])

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
