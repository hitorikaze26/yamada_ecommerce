/** Normalize admin user payloads (supports legacy and camelCase API keys). */

export const INACTIVE_ARCHIVE_MS = 90 * 24 * 60 * 60 * 1000 // 3 months

export interface NormalizedAdminUser {
  id: number
  email: string
  username: string
  givenName: string | null
  surname: string | null
  contactNumber: string | null
  active: boolean
  emailVerified: boolean
  isArchived: boolean
  lastActiveAt: string | null
  updatedAt: string | null
  roles: string[]
  primaryRole: string
  createdAt: string | null
  buyerProfile: Record<string, unknown> | null
  // Legacy aliases for templates that still reference them
  "User email": string
  "User active": boolean
  "User verified": boolean
  Username: string
  given_name: string | null
  contact_number: string | null
  created_at: string | null
  user_role: string[]
  buyer_profile: Record<string, unknown> | null
}

export function normalizeAdminUser(raw: Record<string, unknown>): NormalizedAdminUser {
  const roles = Array.isArray(raw.user_role)
    ? (raw.user_role as string[])
    : Array.isArray(raw.userRole)
      ? (raw.userRole as string[])
      : raw.role
        ? [String(raw.role)]
        : []

  const email = String(raw["User email"] ?? raw.email ?? "")
  const username = String(raw.Username ?? raw.username ?? "")
  const givenName = (raw.given_name ?? raw.givenName ?? null) as string | null
  const surname = (raw.surname ?? null) as string | null
  const contactNumber = (raw.contact_number ?? raw.contactNumber ?? null) as string | null
  const active = Boolean(raw["User active"] ?? raw.active ?? false)
  const emailVerified = Boolean(raw["User verified"] ?? raw.emailVerified ?? false)
  const createdAt = (raw.created_at ?? raw.createdAt ?? null) as string | null
  const updatedAt = (raw.updated_at ?? raw.updatedAt ?? null) as string | null
  const lastActiveAt = (raw.last_active_at ?? raw.lastActiveAt ?? updatedAt ?? createdAt) as string | null
  const isArchived = Boolean(raw.is_archived ?? raw.isArchived ?? false)
  const buyerProfile = (raw.buyer_profile ?? raw.buyerProfile ?? null) as Record<string, unknown> | null

  return {
    id: Number(raw.id),
    email,
    username,
    givenName,
    surname,
    contactNumber,
    active,
    emailVerified,
    isArchived,
    lastActiveAt,
    updatedAt,
    roles,
    primaryRole: roles[0] ?? String(raw.role ?? "unknown"),
    createdAt,
    buyerProfile,
    "User email": email,
    "User active": active,
    "User verified": emailVerified,
    Username: username,
    given_name: givenName,
    surname,
    contact_number: contactNumber,
    created_at: createdAt,
    user_role: roles,
    buyer_profile: buyerProfile,
  }
}

export function userNeedsApproval(user: NormalizedAdminUser): boolean {
  const role = user.primaryRole || user.roles[0] || ""
  return role === "buyer" && user.active && !user.emailVerified && !user.isArchived
}

export function userLastActiveMs(user: NormalizedAdminUser): number {
  const raw = user.lastActiveAt || user.updatedAt || user.createdAt
  if (!raw) return 0
  const t = new Date(raw).getTime()
  return Number.isFinite(t) ? t : 0
}

/** Eligible for soft archive: not pending approval, dormant 3+ months, not already archived. */
export function userCanArchive(user: NormalizedAdminUser, isAdmin = false): boolean {
  if (isAdmin || user.isArchived || userNeedsApproval(user)) return false
  const lastMs = userLastActiveMs(user)
  if (!lastMs) return false
  return Date.now() - lastMs >= INACTIVE_ARCHIVE_MS
}

export function adminUserDisplayName(user: NormalizedAdminUser | Record<string, unknown>): string {
  const u = "User email" in user ? (user as NormalizedAdminUser) : normalizeAdminUser(user as Record<string, unknown>)
  const given = u.given_name?.trim()
  const surname = u.surname?.trim()
  if (given || surname) return `${given ?? ""} ${surname ?? ""}`.trim()
  if (u.Username && u.Username !== u["User email"]) return u.Username
  const email = u["User email"]
  if (email) {
    const local = email.split("@")[0]
    return local || email
  }
  return "(no name)"
}
