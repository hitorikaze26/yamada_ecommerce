import { getApiFetchError, isAuthError, unwrapApiList } from "@/lib/portal-fetch"

/** @deprecated Use unwrapApiList from portal-fetch */
export function unwrapAdminList<T>(
  data: Record<string, unknown> | unknown[] | null | undefined,
  keys: string[],
): T[] {
  return unwrapApiList<T>(data, keys)
}

export function getAdminFetchError(err: unknown, fallback: string): string {
  return getApiFetchError(err, fallback, "admin")
}

export function isAdminAuthError(err: unknown): boolean {
  return isAuthError(err)
}
