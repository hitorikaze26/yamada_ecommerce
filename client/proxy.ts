import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

const COOKIE_PROTECTED_PREFIXES = ["/checkout", "/buyer", "/seller", "/rider"]

function requiresCookieGate(pathname: string): boolean {
  return COOKIE_PROTECTED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  )
}

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Admin pages are guarded in-app by ProtectedRoute + backend @admin_required().
  // Do not gate /admin here because API-domain auth cookies are not readable
  // on the frontend domain when deployed cross-origin (Vercel + Railway).
  if (pathname === "/admin" || pathname.startsWith("/admin/")) {
    return NextResponse.next()
  }

  if (!requiresCookieGate(pathname)) {
    return NextResponse.next()
  }

  const hasSessionCookie =
    request.cookies.has("access_token_cookie") ||
    request.cookies.has("csrf_access_token")

  if (!hasSessionCookie) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = "/auth/login"
    loginUrl.searchParams.set("redirect", pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: [
    "/admin/:path*",
    "/checkout",
    "/buyer/:path*",
    "/seller/:path*",
    "/rider/:path*",
  ],
}
