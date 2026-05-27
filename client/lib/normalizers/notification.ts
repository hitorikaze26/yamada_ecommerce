import type { NotificationDto } from "@/lib/api"

function str(raw: Record<string, unknown>, ...keys: string[]): string {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return String(v)
  }
  return ""
}

function num(raw: Record<string, unknown>, ...keys: string[]): number {
  for (const k of keys) {
    const v = raw[k]
    if (typeof v === "number") return v
  }
  return Number(_read(raw, keys) ?? 0)
}

function bool(raw: Record<string, unknown>, ...keys: string[]): boolean {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return Boolean(v)
  }
  return false
}

function _read(raw: Record<string, unknown>, keys: string[]): unknown {
  for (const k of keys) {
    const v = raw[k]
    if (v !== undefined && v !== null) return v
  }
  return undefined
}

export function normalizeNotification(raw: Record<string, unknown>): NotificationDto {
  return {
    id: num(raw, "id"),
    title: str(raw, "title"),
    description: str(raw, "description", "body", "message"),
    createdAt: (raw.createdAt as string) ?? (raw.created_at as string) ?? null,
    read: bool(raw, "read", "isRead", "is_read"),
    role: (raw.role as string) ?? null,
    page: (raw.page as string) ?? null,
  }
}

export function normalizeNotificationList(rawList: unknown[]): NotificationDto[] {
  return rawList.map(item => normalizeNotification(item as Record<string, unknown>))
}
