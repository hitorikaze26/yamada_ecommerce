/**
 * Centralized environment configuration for the Next.js frontend.
 *
 * Single source of truth for:
 * - Environment detection (local / production / test)
 * - API base URL resolution
 * - Image URL resolution
 * - Auth cookie domain awareness
 *
 * DESIGN
 * ------
 * - NEXT_PUBLIC_API_BASE_URL is the single env var that controls the environment.
 * - When unset in dev, defaults to http://127.0.0.1:5000/api.
 * - In production (Vercel), it MUST be set to the Railway API URL.
 * - All consumers read from this module, never directly from process.env.
 * 
 * NOTE: Environment flags from @/lib/env-config are used for deployment-specific behavior.
 */

import { getApiBaseUrl, getApiOrigin } from "@/lib/env-config"

// Compute these once at module load time
const apiBaseUrl = getApiBaseUrl()
const apiBaseOrigin = getApiOrigin()

function isLocalUrl(url: string): boolean {
  const host = url.replace(/^https?:\/\//, "").split(/[/:]/)[0].toLowerCase()
  return host === "localhost" || host === "127.0.0.1" || host === "0.0.0.0"
}

function detectEnvironment(): "local" | "production" | "test" {
  if (typeof window === "undefined" && process.env.NODE_ENV === "test") {
    return "test"
  }
  const configured = process.env.NEXT_PUBLIC_API_BASE_URL?.trim()
  if (configured) {
    return isLocalUrl(configured) ? "local" : "production"
  }
  return "local"
}

export const Env = {
  /** The current runtime environment. */
  current: detectEnvironment(),

  /** True when running on localhost/127.0.0.1 in development. */
  isLocal: detectEnvironment() === "local",

  /** True when deployed (NEXT_PUBLIC_API_BASE_URL is set). */
  isProduction: detectEnvironment() === "production",

  /** Full API base URL (always ends with /api, no trailing slash). */
  API_BASE_URL: apiBaseUrl,

  /** API origin (base URL without /api suffix) — used for image resolution. */
  API_BASE_ORIGIN: apiBaseOrigin,

  /**
   * Resolve a stored file path to a usable absolute URL.
   *
   * Resolution order:
   * 1. null/undefined/empty to null
   * 2. Full HTTPS URL to pass through unchanged (Supabase, signed URLs)
   * 3. `/static/...` path to prepend Flask origin (local dev)
   * 4. Relative path to prepend Flask origin (local dev fallback)
   *
   * In production, the backend resolves URLs to absolute HTTPS via Supabase
   * before returning them. This function handles the local-dev fallback.
   */
  resolveImageUrl(url?: string | null): string | null {
    if (!url) return null

    const value = String(url).replace(/\\/g, "/").trim()
    if (!value) return null

    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value
    }

    // Use the precomputed apiBaseOrigin
    const origin = apiBaseOrigin.replace(/\/static$/, "")

    if (value.startsWith("/static/")) {
      return `${origin}${value}`
    }

    const trimmed = value.replace(/^\/+/, "")
    if (trimmed.startsWith("static/")) {
      return `${origin}/${trimmed}`
    }

    return `${origin}/static/${trimmed}`
  },

  /**
   * Check if the current browser is on localhost (for user-facing messages).
   */
  isBrowserOnLocalhost(): boolean {
    if (typeof window === "undefined") return false
    const hostname = window.location.hostname
    return hostname === "localhost" || hostname === "127.0.0.1"
  },
}
