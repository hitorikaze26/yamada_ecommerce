import type { AxiosError } from "axios"

/** Read the first matching list field from a typical Flask JSON body. */
export function unwrapApiList<T>(
  data: Record<string, unknown> | unknown[] | null | undefined,
  keys: string[],
): T[] {
  if (!data) return []
  if (Array.isArray(data)) return data as T[]
  if (typeof data !== "object") return []
  const record = data as Record<string, unknown>
  for (const key of keys) {
    const value = record[key]
    if (Array.isArray(value)) return value as T[]
  }
  return []
}

export function getApiFetchError(
  err: unknown,
  fallback: string,
  portal: "admin" | "buyer" = "buyer",
): string {
  const axiosErr = err as AxiosError<{ msg?: string }>
  const msg = axiosErr.response?.data?.msg?.trim()
  if (msg) return msg
  const status = axiosErr.response?.status
  if (status === 401) {
    return portal === "admin"
      ? "Session expired. Please sign in again as admin."
      : "Session expired. Please sign in again."
  }
  if (status === 403) {
    return portal === "admin"
      ? "You do not have permission to view this data."
      : "You do not have permission to perform this action."
  }
  if (status === 404) return "Requested data was not found."
  return fallback
}

export function isAuthError(err: unknown): boolean {
  const status = (err as AxiosError)?.response?.status
  return status === 401 || status === 403
}
