"use client"

import Link from "next/link"

interface StoreNameLinkProps {
  storeId?: string | number | null
  storeName: string
  className?: string
  /** Use inside primary-colored shop headers (cart, checkout). */
  onPrimary?: boolean
}

function isValidStoreId(storeId?: string | number | null): boolean {
  if (storeId == null || storeId === "") return false
  const id = String(storeId)
  if (id === "unknown") return false
  const n = Number(id)
  return Number.isFinite(n) && n > 0
}

export function StoreNameLink({
  storeId,
  storeName,
  className = "",
  onPrimary = false,
}: StoreNameLinkProps) {
  if (!storeName) return null

  const linkClass = onPrimary
    ? `hover:underline truncate ${className}`
    : `hover:text-primary hover:underline ${className}`

  if (!isValidStoreId(storeId)) {
    return <span className={`truncate ${className}`}>{storeName}</span>
  }

  return (
    <Link
      href={`/store/${storeId}`}
      className={linkClass}
      onClick={(e) => e.stopPropagation()}
    >
      {storeName}
    </Link>
  )
}
