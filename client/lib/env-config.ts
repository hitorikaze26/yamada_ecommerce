/**
 * Centralized environment configuration for enabling/disabling deployment-specific behavior.
 * 
 * This module provides environment-aware toggles that allow temporarily disabling
 * production/deployment behavior while preserving the existing production architecture.
 * 
 * Usage:
 *   import { EnvFlags } from "@/lib/env-config";
 *   
 *   if (EnvFlags.USE_LOCAL_STORAGE) {
 *     // use local storage
 *   } else {
 *     // use Supabase storage (production)
 *   }
 */

// Read environment variables with defaults for development
const APP_ENV = process.env.APP_ENV || "development";
const USE_LOCAL_STORAGE = 
  process.env.USE_LOCAL_STORAGE?.toLowerCase() === "true" || 
  APP_ENV === "development";

const USE_SUPABASE_STORAGE = 
  process.env.USE_SUPABASE_STORAGE?.toLowerCase() === "true" && 
  APP_ENV !== "development";

const USE_PRODUCTION_COOKIES = 
  process.env.USE_PRODUCTION_COOKIES?.toLowerCase() === "true" && 
  APP_ENV === "production";

const USE_PRODUCTION_URLS = 
  process.env.USE_PRODUCTION_URLS?.toLowerCase() === "true" && 
  APP_ENV === "production";

const USE_RAILWAY_DETECTION = 
  process.env.USE_RAILWAY_DETECTION?.toLowerCase() === "true" && 
  APP_ENV === "production";

const USE_VERCEL_DETECTION = 
  process.env.USE_VERCEL_DETECTION?.toLowerCase() === "true" && 
  APP_ENV === "production";

/**
 * Environment flags for controlling deployment-specific behavior.
 * 
 * Set APP_ENV=development to enable localhost development mode:
 *   - Uses local storage instead of Supabase
 *   - Uses development cookies (not secure)
 *   - Uses localhost URLs instead of production URLs
 *   - Disables Railway/Vercel-specific detection
 * 
 * Set APP_ENV=production to enable production mode:
 *   - Uses Supabase storage
 *   - Uses production cookies (secure)
 *   - Uses production URLs
 *   - Enables Railway/Vercel-specific detection
 */
export const EnvFlags = {
  /** Current application environment */
  APP_ENV,
  
  /** Use local filesystem storage instead of Supabase Storage */
  USE_LOCAL_STORAGE,
  
  /** Use Supabase Storage for file uploads */
  USE_SUPABASE_STORAGE,
  
  /** Use production cookie policies (secure, SameSite=None) */
  USE_PRODUCTION_COOKIES,
  
  /** Use production URLs instead of localhost URLs */
  USE_PRODUCTION_URLS,
  
  /** Enable Railway-specific environment detection */
  USE_RAILWAY_DETECTION,
  
  /** Enable Vercel-specific environment detection */
  USE_VERCEL_DETECTION,
  
  /** Is running in development mode */
  IS_DEVELOPMENT: APP_ENV === "development",
  
  /** Is running in production mode */
  IS_PRODUCTION: APP_ENV === "production",
};

function isLocalUrl(url: string): boolean {
  const host = url.replace(/^https?:\/\//, "").split(/[/:]/)[0].toLowerCase()
  return host === "localhost" || host === "127.0.0.1" || host === "0.0.0.0"
}

/**
 * Get the appropriate API base URL based on environment.
 *
 * KEY: Use the Next.js proxy (/api) when in development — this is
 * **same-origin**, so no CORS preflight is needed at all.
 *
 * Resolution order:
 * 1. NEXT_PUBLIC_API_BASE_URL pointing to a remote host → use it (production)
 * 2. NEXT_PUBLIC_API_BASE_URL pointing to localhost → ignore, use proxy (dev)
 * 3. Not set → /api proxy (development default)
 */
export function getApiBaseUrl(): string {
  const configured = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  if (configured) {
    // If it's a remote URL (not localhost), use it directly (production mode)
    if (!isLocalUrl(configured)) {
      return configured.endsWith("/api")
        ? configured.replace(/\/$/, "")
        : `${configured.replace(/\/$/, "")}/api`;
    }
  }
  // Development: use Next.js same-origin proxy — no CORS
  return "/api";
}

/**
 * Get the appropriate API origin (base URL without /api) for image resolution.
 * In development with proxy, returns the Flask server URL directly.
 */
export function getApiOrigin(): string {
  const base = getApiBaseUrl();
  // When using the Next.js proxy (relative URL), resolve to Flask server
  if (base === "/api") {
    return "http://127.0.0.1:5000";
  }
  return base.replace(/\/api(?:\/)?$/, "");
}