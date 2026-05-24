import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

const PROTECTED_PREFIXES = ["/admin", "/checkout", "/buyer", "/seller", "/rider"]

function requiresAuth(pathname: string): boolean {
  return PROTECTED_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  )
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  if (!requiresAuth(pathname)) {
    return NextResponse.next()
  }

  const hasSessionCookie =
    request.cookies.has("access_token_cookie") ||
    request.cookies.has("csrf_access_token")

  if (!hasSessionCookie) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = "/auth/login"
    loginUrl.searchParams.set("redirect", pathname)
    if (pathname.startsWith("/admin")) {
      loginUrl.searchParams.set("role", "admin")
    }
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
