type StatusStyle = string

const STRING_STATUS_COLORS: Record<string, StatusStyle> = {
  pending: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  processing: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  shipped: "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/30 dark:text-indigo-400",
  delivered: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
  completed: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
  cancelled: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
  returned: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400",
  refunded: "bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400",
  active: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
  inactive: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400",
  draft: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400",
  to_ship: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  to_receive: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400",
  accepted: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400",
  rejected: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
  under_review: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400",
  hidden: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400",
  removed: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
  restricted: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
  out_of_stock: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400",
  archived: "bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400",
}

export function statusBadge(status: string): string {
  return STRING_STATUS_COLORS[status.toLowerCase()] || "bg-muted text-muted-foreground"
}

export const STATUS_COLORS = STRING_STATUS_COLORS
