export function formatPrice(
  amount: number,
  options?: { minimumFractionDigits?: number },
): string {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    ...(options?.minimumFractionDigits != null
      ? { minimumFractionDigits: options.minimumFractionDigits }
      : {}),
  }).format(amount)
}

export function formatNumber(num: number): string {
  return new Intl.NumberFormat("en-PH").format(num)
}

export function formatDate(iso: string | number | Date, options?: Intl.DateTimeFormatOptions): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ""
  return d.toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    ...options,
  })
}

export function formatDateTime(iso: string | number | Date): string {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ""
  return d.toLocaleString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  })
}
