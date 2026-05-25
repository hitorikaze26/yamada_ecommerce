import type { UserRole } from "@/lib/types"

const ROUTE_ROLE_MAP: { prefix: string; roles: UserRole[] }[] = [
  { prefix: "/admin", roles: ["admin"] },
  { prefix: "/seller", roles: ["seller"] },
  { prefix: "/rider", roles: ["rider"] },
  { prefix: "/buyer", roles: ["buyer", "seller"] },
  { prefix: "/checkout", roles: ["buyer", "seller"] },
]

export function roleForPathname(pathname: string): UserRole | null {
  if (pathname === "/seller" || pathname.startsWith("/seller/")) return "seller"
  if (pathname === "/rider" || pathname.startsWith("/rider/")) return "rider"
  if (pathname === "/admin" || pathname.startsWith("/admin/")) return "admin"
  if (
    pathname === "/buyer" ||
    pathname.startsWith("/buyer/") ||
    pathname === "/checkout" ||
    pathname.startsWith("/checkout/")
  ) {
    return "buyer"
  }
  return null
}

export function canAccessRoute(role: UserRole | null, pathname: string): boolean {
  if (!role) return false
  const required = ROUTE_ROLE_MAP.find(
    (entry) => pathname === entry.prefix || pathname.startsWith(`${entry.prefix}/`),
  )
  if (!required) return true
  return required.roles.includes(role)
}

export function loginPathForRole(role: UserRole): string {
  return `/auth/login?role=${role}`
}
