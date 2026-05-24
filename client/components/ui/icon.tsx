"use client"

interface IconProps {
  name: string
  className?: string
  size?: "sm" | "md" | "lg" | "xl"
}

const sizeMap = {
  sm: "text-sm",
  md: "text-base",
  lg: "text-xl",
  xl: "text-2xl",
}

/**
 * Reusable Icon component using Flaticon CDN (regular-rounded)
 * @param name - Flaticon icon name (e.g., 'home', 'search', 'user')
 * @param className - Additional CSS classes
 * @param size - Icon size variant
 */
export function Icon({ name, className = "", size = "md" }: IconProps) {
  return <i className={`fi fi-rr-${name} ${sizeMap[size]} ${className}`} aria-hidden="true" />
}
