import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

export function proxy(request: NextRequest) {
  // IMPORTANT: Vercel + Railway cross-origin deployment:
  // Flask sets cookies on the Railway domain. Next.js middleware on the Vercel
  // domain cannot see those cookies. Therefore middleware CANNOT enforce auth.
  // All route protection is handled client-side by ProtectedRoute.
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
