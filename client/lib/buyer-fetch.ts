import { getApiFetchError, isAuthError, unwrapApiList } from "@/lib/portal-fetch"

export { unwrapApiList, isAuthError as isBuyerAuthError }

export function unwrapBuyerList<T>(
  data: Record<string, unknown> | unknown[] | null | undefined,
  keys: string[],
): T[] {
  return unwrapApiList<T>(data, keys)
}

export function getBuyerFetchError(err: unknown, fallback: string): string {
  return getApiFetchError(err, fallback, "buyer")
}
