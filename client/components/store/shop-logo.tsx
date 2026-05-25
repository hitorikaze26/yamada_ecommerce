"use client"

import { useEffect, useState, type ReactNode } from "react"
import Image from "next/image"
import { resolveImageUrl } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

const PRIVATE_PATH_PREFIXES = [
  "seller_dti/",
  "seller_bir/",
  "seller_permits/",
  "seller_ids/",
  "buyer_ids/",
  "rider_docs/",
  "report_evidence/",
  "proof_photos/",
  "docs/",
]

function isPrivatePath(path: string): boolean {
  const normalized = path.replace(/\\/g, "/")
  return PRIVATE_PATH_PREFIXES.some(
    (p) => normalized.startsWith(p) || normalized.includes(`/${p}`),
  )
}

interface ShopLogoProps {
  src?: string | null
  alt?: string
  width?: number
  height?: number
  className?: string
  fallback?: ReactNode
  isPrivate?: boolean
  priority?: boolean
  containerClassName?: string
  unoptimized?: boolean
}

export function ShopLogo({
  src,
  alt = "Store logo",
  width = 96,
  height = 96,
  className = "w-full h-full object-cover",
  fallback,
  isPrivate,
  priority = false,
  containerClassName = "",
  unoptimized,
}: ShopLogoProps) {
  const [error, setError] = useState(false)
  const [resolvedUrl, setResolvedUrl] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    const resolveUrl = async () => {
      if (!src) {
        if (!cancelled) setLoading(false)
        return
      }

      if (src.startsWith("http://") || src.startsWith("https://")) {
        if (!cancelled) {
          setResolvedUrl(src)
          setLoading(false)
        }
        return
      }

      const isPriv = isPrivate ?? isPrivatePath(src)

      if (isPriv) {
        try {
          const { resolvePrivateDocUrl } = await import("@/lib/api")
          const signed = await resolvePrivateDocUrl(src)
          if (!cancelled) {
            setResolvedUrl(signed ?? resolveImageUrl(src))
            setLoading(false)
          }
        } catch {
          if (!cancelled) {
            setResolvedUrl(resolveImageUrl(src))
            setLoading(false)
          }
        }
        return
      }

      if (!cancelled) {
        setResolvedUrl(resolveImageUrl(src))
        setLoading(false)
      }
    }

    setError(false)
    setLoading(true)
    setResolvedUrl(null)
    void resolveUrl()

    return () => {
      cancelled = true
    }
  }, [src, isPrivate])

  if (loading) {
    return (
      <div
        className={`overflow-hidden bg-muted animate-pulse ${containerClassName}`}
        style={{ width, height }}
      />
    )
  }

  if (!resolvedUrl || error) {
    return (
      <div
        className={`overflow-hidden ${containerClassName}`}
        style={{ width, height }}
      >
        {fallback ?? (
          <div className="w-full h-full flex items-center justify-center bg-muted">
            <Icon name="store" size="xl" className="text-muted-foreground" />
          </div>
        )}
      </div>
    )
  }

  const isPriv = isPrivate ?? isPrivatePath(src ?? "")

  if (isPriv) {
    return (
      <div
        className={`overflow-hidden ${containerClassName}`}
        style={{ width, height }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={resolvedUrl}
          alt={alt}
          className={className}
          onError={() => setError(true)}
        />
      </div>
    )
  }

  return (
    <div
      className={`overflow-hidden ${containerClassName}`}
      style={{ width, height }}
    >
      <Image
        src={resolvedUrl}
        alt={alt}
        width={width}
        height={height}
        className={className}
        priority={priority}
        unoptimized={unoptimized}
        onError={() => setError(true)}
      />
    </div>
  )
}
