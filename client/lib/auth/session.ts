import {
  API_BASE_URL,
  authApi,
  buyerApi,
  riderAccountApi,
  sellerAccountApi,
} from "@/lib/api"
import type { User, UserRole } from "@/lib/types"

export interface AuthSessionDto {
  user_id: number
  email: string
  given_name?: string
  surname?: string
  contact_number?: string
  roles: string[]
  is_verified: boolean
}

const ROLE_PRIORITY: UserRole[] = ["buyer", "seller", "rider", "admin"]

export const ROLE_STORAGE_KEY = "yamada-role"

export type SessionCheckResult = "valid" | "invalid" | "unknown"

/** Tri-state session check: invalid on 401/403; unknown on network errors (keep cached session). */
export async function checkSessionStatus(): Promise<SessionCheckResult> {
  try {
    const sessionRes = await authApi.checkSession()
    const session = parseSessionPayload(sessionRes.data as Record<string, unknown>)
    if (!session.user_id || session.roles.length === 0) return "invalid"
    return "valid"
  } catch (error: unknown) {
    const status = (error as { response?: { status?: number } })?.response?.status
    if (status === 401 || status === 403) return "invalid"
    return "unknown"
  }
}

export function isUserRole(value: string): value is UserRole {
  return ROLE_PRIORITY.includes(value as UserRole)
}

/** Pick portal role: requested if allowed, else first role from server priority. */
export function resolveActiveRole(
  requested: UserRole | null | undefined,
  serverRoles: string[],
): UserRole | null {
  const allowed = serverRoles.filter(isUserRole)
  if (allowed.length === 0) return null
  if (requested && allowed.includes(requested)) return requested
  for (const role of ROLE_PRIORITY) {
    if (allowed.includes(role)) return role
  }
  return allowed[0] as UserRole
}

export function parseSessionPayload(data: Record<string, unknown>): AuthSessionDto {
  const rolesRaw = data.roles
  const roles = Array.isArray(rolesRaw)
    ? rolesRaw.map((r) => String(r).toLowerCase()).filter(isUserRole)
    : []

  return {
    user_id: Number(data.user_id ?? data.userId ?? 0),
    email: String(data.email ?? ""),
    given_name: data.given_name != null ? String(data.given_name) : undefined,
    surname: data.surname != null ? String(data.surname) : undefined,
    contact_number:
      data.contact_number != null ? String(data.contact_number) : undefined,
    roles,
    is_verified: Boolean(data.is_verified ?? data.isVerified ?? false),
  }
}

export async function fetchRoleProfile(role: UserRole): Promise<Record<string, unknown> | null> {
  try {
    if (role === "buyer") {
      const res = await buyerApi.getProfile()
      return (res.data?.profile ?? res.data) as Record<string, unknown>
    }
    if (role === "rider") {
      const res = await riderAccountApi.getProfile()
      return (res.data?.profile ?? res.data) as Record<string, unknown>
    }
    if (role === "seller") {
      const res = await sellerAccountApi.getProfile()
      return (res.data?.profile ?? res.data) as Record<string, unknown>
    }
  } catch {
    return null
  }
  return null
}

export function buildUserFromSession(
  session: AuthSessionDto,
  role: UserRole,
  profile: Record<string, unknown> | null,
  loginVerified?: boolean,
): User {
  const isVerified =
    profile?.isVerified ??
    profile?.is_verified ??
    loginVerified ??
    session.is_verified

  const storeIdRaw = profile?.storeId ?? profile?.store_id
  const storeId =
    storeIdRaw != null && storeIdRaw !== ""
      ? Number(storeIdRaw)
      : null

  return {
    id: String(profile?.id ?? profile?.userId ?? session.user_id ?? "current-user"),
    email: String(profile?.email ?? session.email ?? ""),
    givenName: String(
      profile?.givenName ?? profile?.given_name ?? session.given_name ?? "",
    ),
    surname: String(profile?.surname ?? session.surname ?? ""),
    role,
    contactNumber: String(
      profile?.contactNumber ?? profile?.contact_number ?? session.contact_number ?? "",
    ),
    isVerified: Boolean(isVerified),
    storeId: Number.isFinite(storeId) ? storeId : null,
    storeStatus:
      profile?.storeStatus != null
        ? String(profile.storeStatus)
        : profile?.store_status != null
          ? String(profile.store_status)
          : null,
    shopName:
      profile?.shopName != null
        ? String(profile.shopName)
        : profile?.shop_name != null
          ? String(profile.shop_name)
          : undefined,
    createdAt: String(
      profile?.createdAt ?? profile?.created_at ?? new Date().toISOString(),
    ),
    updatedAt: new Date().toISOString(),
  }
}

export const dashboardRoutes: Record<UserRole, string> = {
  buyer: "/home",
  seller: "/seller",
  rider: "/rider",
  admin: "/admin",
}

export function getLoginErrorMessage(error: unknown): string {
  const axiosErr = error as {
    response?: { data?: { msg?: string }; status?: number }
    code?: string
    message?: string
  }

  const isNetwork =
    !axiosErr.response &&
    (axiosErr.code === "ERR_NETWORK" ||
      axiosErr.code === "ECONNABORTED" ||
      axiosErr.message?.toLowerCase().includes("network"))

  if (isNetwork) {
    const onLocalhost =
      typeof window !== "undefined" &&
      (window.location.hostname === "localhost" ||
        window.location.hostname === "127.0.0.1")
    if (onLocalhost) {
      return `Cannot reach the API at ${API_BASE_URL}. Start the Flask server (python run.py) and check NEXT_PUBLIC_API_BASE_URL in client/.env.local.`
    }
    return (
      `Cannot reach the API at ${API_BASE_URL}. ` +
      "On Railway, set CORS_ORIGINS to your exact Vercel URL (e.g. https://yamada-ecommerce.vercel.app) and redeploy. " +
      "On Vercel, set NEXT_PUBLIC_API_BASE_URL to your Railway URL ending in /api and redeploy."
    )
  }

  if (error instanceof Error && !(error as { response?: unknown }).response) {
    const text = error.message.trim()
    if (text && !text.startsWith("Request failed")) return text
  }

  const msg = axiosErr.response?.data?.msg
  if (msg) return msg

  const status = axiosErr.response?.status
  if (status === 403) {
    return "This account cannot access that portal. Try a different sign-in link."
  }
  if (status === 401) {
    return "Invalid email or password. Please try again."
  }

  return "Sign-in failed. Please try again."
}

/** Resolve role for session restore or login (login may pass roles=[] before server returns roles). */
export function resolveHydrationRole(
  preferredRole: UserRole | null,
  serverRoles: string[],
): UserRole | null {
  if (preferredRole && (serverRoles.length === 0 || serverRoles.includes(preferredRole))) {
    return preferredRole
  }
  return resolveActiveRole(preferredRole, serverRoles)
}
