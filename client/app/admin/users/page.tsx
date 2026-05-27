"use client"

import { Suspense, useEffect, useState } from "react"
import { useSearchParams } from "next/navigation"
import { motion, AnimatePresence } from "framer-motion"
import { formatPrice } from "@/lib/format"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"
import { adminApi, resolveImageUrl } from "@/lib/api"
import {
  adminUserDisplayName,
  normalizeAdminUser,
  userCanArchive,
  userNeedsApproval,
  type NormalizedAdminUser,
} from "@/lib/admin-user"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"

const tabs = ["all", "active", "inactive"]

const buildStaticUrl = (path: string | null | undefined) => resolveImageUrl(path) || ""

type DetailView = "profile" | "activity" | "orders" | "products" | "deliveries" | null

type AdminUserDto = NormalizedAdminUser

const statusColors: Record<string, string> = {
  active: "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400",
  inactive: "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400",
  archived: "bg-slate-100 text-slate-700 dark:bg-slate-900/30 dark:text-slate-400",
  pending: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300",
}

function AdminUsersContent() {
  const searchParams = useSearchParams()
  const [activeTab, setActiveTab] = useState("all")
  const [searchQuery, setSearchQuery] = useState("")
  const [users, setUsers] = useState<AdminUserDto[]>([])
  const [selectedUser, setSelectedUser] = useState<AdminUserDto | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeDetailView, setActiveDetailView] = useState<DetailView>(null)
  const [detailData, setDetailData] = useState<unknown>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState<string | null>(null)
  const [confirmAction, setConfirmAction] = useState<"approve" | "reject" | "archive" | null>(null)
  const [confirmUser, setConfirmUser] = useState<AdminUserDto | null>(null)
  const [confirmLoading, setConfirmLoading] = useState(false)
  const [rejectReason, setRejectReason] = useState("")
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  useEffect(() => {
    void fetchUsers()
  }, [])

  // Auto-select a user when navigated from admin/orders with ?userId=
  useEffect(() => {
    const idParam = searchParams.get("userId")
    if (!idParam) return

    const userId = Number(idParam)
    if (!userId || !Number.isFinite(userId)) return

    if (!users || users.length === 0) return

    const match = users.find((u) => u.id === userId)
    if (match) {
      setSelectedUser(match)
    }
  }, [searchParams, users])

  const fetchUsers = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await adminApi.getUsers()
      setUsers(
        unwrapAdminList<Record<string, unknown>>(res.data, ["users"]).map((u) =>
          normalizeAdminUser(u),
        ),
      )
    } catch (err) {
      console.error("Failed to load users", err)
      const message = getAdminFetchError(err, "Failed to load users. Please try again.")
      setError(message)
      showAlert(message, "error")
    } finally {
      setIsLoading(false)
    }
  }

  const getRoleLabel = (user: AdminUserDto): string =>
    user.primaryRole || user.roles[0] || ""

  const patchUserLocal = (userId: number, patch: Partial<NormalizedAdminUser>) => {
    setUsers((prev) =>
      prev.map((u) => (u.id === userId ? { ...u, ...patch } : u)),
    )
    setSelectedUser((prev) => (prev?.id === userId ? { ...prev, ...patch } : prev))
  }

  const getDisplayName = (user: AdminUserDto): string => adminUserDisplayName(user)

  const openConfirmDialog = (action: "approve" | "reject" | "archive", user: AdminUserDto) => {
    setConfirmAction(action)
    setConfirmUser(user)
    if (action === "reject") {
      setRejectReason("")
    }
  }

  const closeConfirmDialog = () => {
    setConfirmAction(null)
    setConfirmUser(null)
    setConfirmLoading(false)
    setRejectReason("")
  }

  const handleConfirm = async () => {
    if (!confirmAction || !confirmUser) return
    setConfirmLoading(true)
    try {
      if (confirmAction === "approve") {
        await handleApproveBuyer(confirmUser)
      } else if (confirmAction === "reject") {
        await handleRejectBuyer(confirmUser, rejectReason)
      } else {
        await handleArchiveUser(confirmUser)
      }
      closeConfirmDialog()
    } catch (err) {
      // Error is already handled inside the approve/reject handlers which set the error state
      setConfirmLoading(false)
    }
  }

  const filteredUsers = users.filter((user) => {
    const isActive = user["User active"]
    const matchesTab =
      activeTab === "all" ||
      (activeTab === "active" && isActive) ||
      (activeTab === "inactive" && !isActive)

    const name = getDisplayName(user)
    const email = user["User email"] ?? ""

    const matchesSearch =
      name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      email.toLowerCase().includes(searchQuery.toLowerCase())

    return matchesTab && matchesSearch
  })

  const isAdminUser = (user: AdminUserDto) => {
    const name = (user.Username || "").toLowerCase()
    const email = (user["User email"] || "").toLowerCase()
    return name === "admin" || email === "noeasumbra122602@gmail.com".toLowerCase()
  }



  const handleApproveBuyer = async (user: AdminUserDto) => {
    try {
      await adminApi.approveBuyer(user.id)
      patchUserLocal(user.id, {
        emailVerified: true,
        "User verified": true,
      })
      showAlert("Buyer has been approved.", "success")
    } catch (err) {
      console.error("Failed to approve buyer", err)
      setError("Failed to approve buyer. Please try again.")
      showAlert("Failed to approve buyer. Please try again.", "error")
    }
  }

  const handleRejectBuyer = async (user: AdminUserDto, reason?: string) => {
    try {
      await adminApi.rejectBuyer(user.id, reason)
      patchUserLocal(user.id, {
        active: false,
        "User active": false,
      })
      showAlert("Buyer has been rejected.", "warning")
    } catch (err) {
      console.error("Failed to reject buyer", err)
      setError("Failed to reject buyer. Please try again.")
      showAlert("Failed to reject buyer. Please try again.", "error")
    }
  }

  const handleArchiveUser = async (user: AdminUserDto) => {
    try {
      await adminApi.archiveUser(user.id)
      patchUserLocal(user.id, {
        isArchived: true,
        active: false,
        "User active": false,
      })
      showAlert(
        "User archived. Their data is kept and the account will restore if they sign in again.",
        "success",
      )
    } catch (err) {
      console.error("Failed to archive user", err)
      showAlert("Failed to archive user. Please try again.", "error")
      throw err
    }
  }

  const getAccountStatusKey = (user: AdminUserDto): keyof typeof statusColors => {
    if (user.isArchived) return "archived"
    if (userNeedsApproval(user)) return "pending"
    return user["User active"] ? "active" : "inactive"
  }

  const getAccountStatusLabel = (user: AdminUserDto): string => {
    if (user.isArchived) return "archived"
    if (userNeedsApproval(user)) return "pending approval"
    return user["User active"] ? "active" : "inactive"
  }

  const resetDetailState = () => {
    setActiveDetailView(null)
    setDetailData(null)
    setDetailError(null)
    setDetailLoading(false)
  }

  const handleOpenDetail = async (view: Exclude<DetailView, null>, user: AdminUserDto) => {
    setActiveDetailView(view)
    setDetailError(null)
    setDetailData(null)

    if (view === "profile") {
      setDetailData(user)
      return
    }

    setDetailLoading(true)
    try {
      let response
      if (view === "activity") {
        response = await adminApi.getUserActivityLogs(user.id)
      } else if (view === "orders") {
        response = await adminApi.getBuyerOrders(user.id)
      } else if (view === "products") {
        response = await adminApi.getSellerProducts(user.id)
      } else if (view === "deliveries") {
        response = await adminApi.getRiderDeliveries(user.id)
      }

      const data = response?.data ?? null
      if (view === "activity") {
        setDetailData((data as { logs?: unknown[] })?.logs ?? [])
      } else if (view === "products") {
        setDetailData((data as { products?: unknown[] })?.products ?? [])
      } else if (view === "deliveries") {
        setDetailData((data as { deliveries?: unknown[] })?.deliveries ?? [])
      } else if (view === "orders") {
        setDetailData((data as { orders?: unknown[] })?.orders ?? [])
      } else {
        setDetailData(data)
      }
    } catch (err: any) {
      console.error("Failed to load user detail view", err)
      const status = err?.response?.status
      if (view === "orders" && status === 404) {
        setDetailData([])
        setDetailError(null)
      } else {
        setDetailError(getAdminFetchError(err, "Failed to load details. Please try again."))
      }
    } finally {
      setDetailLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <GlassAlert
        open={alertOpen && !!alertMessage}
        title={
          alertVariant === "success"
            ? "Success"
            : alertVariant === "error"
              ? "Error"
              : alertVariant === "warning"
                ? "Warning"
                : "Notice"
        }
        description={alertMessage ?? undefined}
        variant={alertVariant}
        onClose={() => setAlertOpen(false)}
      />
      <div>
        <h1 className="text-3xl font-bold mb-2">Users</h1>
        <p className="text-muted-foreground">Manage platform users and their status.</p>
      </div>

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4">Loading users...</div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="bg-card border rounded-2xl p-4">
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex-1 min-w-[200px]">
            <div className="relative">
              <Icon name="search" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search users..."
                className="w-full pl-10 pr-4 py-2 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
              />
            </div>
          </div>
          <div className="flex gap-2 overflow-x-auto">
            {tabs.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-colors ${
                  activeTab === tab ? "bg-primary text-primary-foreground" : "bg-muted hover:bg-muted/80"
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Users Table */}
      {!isLoading && !error && (
        <div className="bg-card border rounded-2xl overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b bg-muted/30">
                  <th className="text-left py-4 px-4 font-medium text-muted-foreground">Name</th>
                  <th className="text-left py-4 px-4 font-medium text-muted-foreground">Email</th>
                  <th className="text-left py-4 px-4 font-medium text-muted-foreground">Role</th>
                  <th className="text-left py-4 px-4 font-medium text-muted-foreground">Status</th>
                  <th className="text-right py-4 px-4 font-medium text-muted-foreground">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user, index) => {
                  const name = getDisplayName(user)
                  const email = user["User email"] ?? "(no email)"
                  const isAdmin = isAdminUser(user)
                  const roleLabel = getRoleLabel(user)
                  const pending = userNeedsApproval(user)
                  const showArchive = userCanArchive(user, isAdmin)
                  const statusKey = getAccountStatusKey(user)

                  return (
                    <tr key={`${name}-${index}`} className="border-b last:border-0 hover:bg-muted/20">
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                            <Icon name="user" className="text-primary" />
                          </div>
                          <div>
                            <p className="font-medium">{name}</p>
                          </div>
                        </div>
                      </td>
                      <td className="py-4 px-4 text-sm text-muted-foreground">{email}</td>
                      <td className="py-4 px-4">
                        <span className="px-2 py-1 rounded-full text-xs font-medium capitalize bg-muted">
                          {roleLabel || "unknown"}
                        </span>
                      </td>
                      <td className="py-4 px-4">
                        <span
                          className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${statusColors[statusKey]}`}
                        >
                          {getAccountStatusLabel(user)}
                        </span>
                      </td>
                      <td className="py-4 px-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => setSelectedUser(user)}
                            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-muted hover:bg-muted/80 transition-colors"
                          >
                            <Icon name="user" size="sm" />
                            <span>View</span>
                          </button>
                          {!isAdmin && pending && (
                            <>
                              <button
                                onClick={() => openConfirmDialog("approve", user)}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-green-500 text-white hover:bg-green-600 transition-colors"
                                type="button"
                              >
                                <Icon name="check" size="sm" />
                                <span>Approve</span>
                              </button>
                              <button
                                onClick={() => openConfirmDialog("reject", user)}
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-red-500 text-white hover:bg-red-600 transition-colors"
                                type="button"
                              >
                                <Icon name="ban" size="sm" />
                                <span>Reject</span>
                              </button>
                            </>
                          )}
                          {!isAdmin && showArchive && (
                            <button
                              onClick={() => openConfirmDialog("archive", user)}
                              className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-600 text-white hover:bg-slate-700 transition-colors"
                              type="button"
                            >
                              <Icon name="box" size="sm" />
                              <span>Archive</span>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* User Detail Modal */}
      <AnimatePresence>
        {selectedUser && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
            onClick={() => setSelectedUser(null)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-background rounded-2xl p-6 w-90vh max-w-none max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold">User Details</h2>
                <button
                  onClick={() => setSelectedUser(null)}
                  className="w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
                >
                  <Icon name="times" />
                </button>
              </div>

              <div className="flex items-center gap-4 mb-6">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                  <Icon name="user" size="lg" className="text-primary" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold">{getDisplayName(selectedUser)}</h3>
                  <p className="text-muted-foreground">{selectedUser["User email"]}</p>
                  {getRoleLabel(selectedUser) && (
                    <p className="text-xs mt-1 capitalize text-muted-foreground">
                      Role: {getRoleLabel(selectedUser)}
                    </p>
                  )}
                </div>
              </div>

              <div className="space-y-4">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status</span>
                  <div className="flex items-center gap-2">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${
                        statusColors[getAccountStatusKey(selectedUser)]
                      }`}
                    >
                      {getAccountStatusLabel(selectedUser)}
                    </span>
                  </div>
                </div>

                <div className="pt-4 border-t">
                  <p className="text-sm font-medium mb-3">User actions</p>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <button
                      type="button"
                      onClick={() => handleOpenDetail("profile", selectedUser)}
                      className="flex items-center justify-center gap-2 px-3 py-2 rounded-xl border bg-background hover:bg-muted transition-colors text-sm"
                    >
                      <Icon name="user" size="sm" />
                      <span>View full profile</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleOpenDetail("activity", selectedUser)}
                      className="flex items-center justify-center gap-2 px-3 py-2 rounded-xl border bg-background hover:bg-muted transition-colors text-sm"
                    >
                      <Icon name="activity" size="sm" />
                      <span>View activity logs</span>
                    </button>
                    {getRoleLabel(selectedUser) === "buyer" && (
                      <button
                        type="button"
                        onClick={() => handleOpenDetail("orders", selectedUser)}
                        className="flex items-center justify-center gap-2 px-3 py-2 rounded-xl border bg-background hover:bg-muted transition-colors text-sm"
                      >
                        <Icon name="shopping-bag" size="sm" />
                        <span>View orders (buyer)</span>
                      </button>
                    )}
                    {getRoleLabel(selectedUser) === "seller" && (
                      <button
                        type="button"
                        onClick={() => handleOpenDetail("products", selectedUser)}
                        className="flex items-center justify-center gap-2 px-3 py-2 rounded-xl border bg-background hover:bg-muted transition-colors text-sm"
                      >
                        <Icon name="box" size="sm" />
                        <span>View products (seller)</span>
                      </button>
                    )}
                    {getRoleLabel(selectedUser) === "rider" && (
                      <button
                        type="button"
                        onClick={() => handleOpenDetail("deliveries", selectedUser)}
                        className="flex items-center justify-center gap-2 px-3 py-2 rounded-xl border bg-background hover:bg-muted transition-colors text-sm col-span-1 sm:col-span-2"
                      >
                        <Icon name="truck-side" size="sm" />
                        <span>View delivery history (rider)</span>
                      </button>
                    )}
                  </div>
                </div>

                {activeDetailView && (
                  <div className="mt-4 p-4 rounded-xl bg-muted/40 border space-y-3">
                    <div className="flex items-center justify-between gap-2">
                      <p className="text-sm font-medium capitalize flex items-center gap-2">
                        <Icon name="info-circle" size="sm" />
                        {activeDetailView === "profile"
                          ? "Full profile"
                          : activeDetailView === "activity"
                            ? "Activity logs"
                            : activeDetailView === "orders"
                              ? "Buyer orders"
                              : activeDetailView === "products"
                                ? "Seller products"
                                : "Rider delivery history"}
                      </p>
                      <button
                        type="button"
                        onClick={resetDetailState}
                        className="w-8 h-8 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
                      >
                        <Icon name="times" size="sm" />
                      </button>
                    </div>

                    {detailLoading && (
                      <p className="text-xs text-muted-foreground">Loading details...</p>
                    )}

                    {detailError && !detailLoading && (
                      <p className="text-xs text-destructive">{detailError}</p>
                    )}

                    {!detailLoading && !detailError && activeDetailView === "profile" && selectedUser && (
                      <div className="space-y-3 text-sm">
                        {getRoleLabel(selectedUser) === "buyer" ? (
                          <>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Name</span>
                              <span className="font-medium">{getDisplayName(selectedUser)}</span>
                            </div>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Email</span>
                              <span className="font-medium break-all">
                                {selectedUser["User email"] || "(no email)"}
                              </span>
                            </div>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Contact number</span>
                              <span className="font-medium">
                                {selectedUser.contact_number || "(no contact number)"}
                              </span>
                            </div>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Date created</span>
                              <span className="font-medium text-xs">
                                {selectedUser.created_at
                                  ? new Date(selectedUser.created_at).toLocaleString()
                                  : "(unknown)"}
                              </span>
                            </div>

                            {selectedUser.buyer_profile && (
                              <div className="mt-3 rounded-lg bg-background/60 border px-3 py-2 text-xs space-y-2">
                                <div className="space-y-1">
                                  <p className="font-medium text-muted-foreground">Address</p>
                                  <p>{selectedUser.buyer_profile.street_address || ""}</p>
                                  <p>
                                    {selectedUser.buyer_profile.barangay_name}, {" "}
                                    {selectedUser.buyer_profile.municipality_name}
                                  </p>
                                  <p>
                                    {selectedUser.buyer_profile.province_name}, {" "}
                                    {selectedUser.buyer_profile.region_name}
                                  </p>
                                  {selectedUser.buyer_profile.postal_code && (
                                    <p>Postal code: {selectedUser.buyer_profile.postal_code}</p>
                                  )}
                                </div>

                                {selectedUser.buyer_profile.valid_id_path && (
                                  <div className="pt-2 border-t space-y-2 w-full">
                                    <p className="font-medium text-muted-foreground">Preview documents</p>

                                    {(() => {
                                      const path = selectedUser.buyer_profile?.valid_id_path || ""
                                      const lower = path.toLowerCase()
                                      const isPdf = lower.endsWith(".pdf")
                                      const url = buildStaticUrl(path)

                                      return (
                                        <div className="space-y-1 w-full">
                                          <a
                                            href={url}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="block text-primary underline truncate"
                                          >
                                            {isPdf ? "Open valid ID (PDF)" : "View valid ID"}
                                          </a>
                                          {!isPdf && (
                                            <a
                                              href={url}
                                              target="_blank"
                                              rel="noreferrer"
                                              className="block w-full"
                                            >
                                              <img
                                                src={url}
                                                alt="Buyer valid ID preview"
                                                className="mt-1 h-24 w-full rounded border object-contain bg-muted"
                                              />
                                            </a>
                                          )}
                                        </div>
                                      )
                                    })()}
                                  </div>
                                )}
                              </div>
                            )}
                          </>
                        ) : (
                          <>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Name</span>
                              <span className="font-medium">{getDisplayName(selectedUser)}</span>
                            </div>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Email</span>
                              <span className="font-medium break-all">
                                {selectedUser["User email"] || "(no email)"}
                              </span>
                            </div>
                            <div className="flex items-center justify-between">
                              <span className="text-muted-foreground">Status</span>
                              <span
                                className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${
                                  statusColors[selectedUser["User active"] ? "active" : "inactive"]
                                }`}
                              >
                                {selectedUser["User active"] ? "active" : "inactive"}
                              </span>
                            </div>
                          </>
                        )}
                      </div>
                    )}

                    {!detailLoading && !detailError && activeDetailView === "orders" && (
                      <div className="space-y-3 text-xs">
                        {(() => {
                          const raw = detailData as any
                          const orders: any[] = Array.isArray(raw)
                            ? raw
                            : Array.isArray(raw?.orders)
                              ? raw.orders
                              : []

                          if (orders.length === 0) {
                            return (
                              <p className="text-muted-foreground">
                                No orders found for this buyer or the backend endpoint is not returning data.
                              </p>
                            )
                          }

                          return (
                            <div className="space-y-2 max-h-64 overflow-auto">
                              {orders.map((order: any) => {
                                const orderId = order.id ?? "?"
                                const orderStatus = String(order.status ?? "").toLowerCase()
                                const storeName = order.store?.name || "Unknown shop"
                                const items: any[] = Array.isArray(order.items) ? order.items : []

                                return (
                                  <div
                                    key={orderId}
                                    className="rounded-lg border bg-background/80 px-3 py-2 space-y-1"
                                  >
                                    <div className="flex items-center justify-between gap-2">
                                      <p className="font-medium text-[13px]">Order #{orderId}</p>
                                      <span
                                        className={`inline-flex px-2 py-0.5 rounded-full text-[10px] font-medium capitalize ${
                                          orderStatus === "delivered" || orderStatus === "completed"
                                            ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
                                            : orderStatus === "pending" || orderStatus === "processing"
                                              ? "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                                              : orderStatus === "cancelled" || orderStatus === "returned"
                                                ? "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
                                                : "bg-muted text-muted-foreground"
                                        }`}
                                      >
                                        {orderStatus || "unknown"}
                                      </span>
                                    </div>

                                    <div className="space-y-1">
                                      {items.length === 0 ? (
                                        <p className="text-[11px] text-muted-foreground italic">No items</p>
                                      ) : (
                                        items.map((item: any, idx: number) => {
                                          const productId = item.productId ?? item.product_id
                                          const product = item.product || {}
                                          const name = product.name || `Product #${productId ?? "?"}`
                                          const code = product.sku || `Code: ${productId ?? "?"}`
                                          const unitPrice = Number(item.unitPrice ?? item.unit_price ?? product.price ?? 0)

                                          return (
                                            <div key={item.id ?? productId ?? idx} className="flex items-start justify-between gap-3">
                                              <div className="space-y-0.5 min-w-0">
                                                <p className="font-medium text-[12px]">{name}</p>
                                                <p className="text-[10px] text-muted-foreground">{code}</p>
                                                <p className="text-[10px] text-muted-foreground">
                                                  Shop: <span className="font-medium">{storeName}</span>
                                                </p>
                                              </div>
                                              <p className="text-[12px] font-semibold flex-shrink-0">{formatPrice(unitPrice)}</p>
                                            </div>
                                          )
                                        })
                                      )}
                                    </div>

                                    {order.rate != null && (
                                      <p className="text-[11px] text-muted-foreground pt-1 border-t border-border/50">
                                        Rate: {"★".repeat(Math.round(order.rate))}{"☆".repeat(5 - Math.round(order.rate))} ({order.rate}/5)
                                      </p>
                                    )}
                                    {order.feedback && (
                                      <p className="text-[11px] text-muted-foreground">
                                        Feedback: {order.feedback}
                                      </p>
                                    )}
                                  </div>
                                )
                              })}
                            </div>
                          )
                        })()}
                      </div>
                    )}

                    {!detailLoading && !detailError && activeDetailView === "activity" && (
                      <div className="space-y-2 text-xs max-h-64 overflow-auto">
                        {(() => {
                          const raw = detailData as any
                          const logs: any[] = Array.isArray(raw) ? raw : []
                          if (logs.length === 0) {
                            return (
                              <p className="text-muted-foreground">
                                No activity logs found for this user.
                              </p>
                            )
                          }
                          return logs.map((log: any) => (
                            <div
                              key={log.id}
                              className="rounded-lg border bg-background/80 px-3 py-2 space-y-1"
                            >
                              <div className="flex items-start justify-between gap-2">
                                <p className="font-medium text-[13px]">
                                  {log.title || "No title"}
                                </p>
                                <span
                                  className={`inline-flex px-1.5 py-0.5 rounded text-[10px] font-medium capitalize ${
                                    log.read
                                      ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
                                      : "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                                  }`}
                                >
                                  {log.read ? "read" : "unread"}
                                </span>
                              </div>
                              {log.description && (
                                <p className="text-[11px] text-muted-foreground">
                                  {log.description}
                                </p>
                              )}
                              <div className="flex items-center gap-2 text-[10px] text-muted-foreground">
                                {log.role && (
                                  <span className="capitalize">{log.role}</span>
                                )}
                                {log.createdAt && (
                                  <span>
                                    {new Date(log.createdAt).toLocaleString()}
                                  </span>
                                )}
                              </div>
                            </div>
                          ))
                        })()}
                      </div>
                    )}

                    {!detailLoading && !detailError && activeDetailView === "products" && (
                      <div className="space-y-2 text-xs max-h-64 overflow-auto">
                        {(() => {
                          const raw = detailData as any
                          const products: any[] = Array.isArray(raw) ? raw : []
                          if (products.length === 0) {
                            return (
                              <p className="text-muted-foreground">
                                No products found for this seller.
                              </p>
                            )
                          }
                          return products.map((p: any) => (
                            <div
                              key={p.id}
                              className="flex items-start justify-between gap-3 rounded-lg border bg-background/80 px-3 py-2"
                            >
                              <div className="space-y-0.5 min-w-0">
                                <p className="font-medium text-[13px] truncate">
                                  {p.name || `Product #${p.id}`}
                                </p>
                                {p.storeName && (
                                  <p className="text-[11px] text-muted-foreground">
                                    Store: {p.storeName}
                                  </p>
                                )}
                              </div>
                              <div className="text-right space-y-1 flex-shrink-0">
                                <p className="text-[13px] font-semibold">
                                  {formatPrice(p.price ?? 0)}
                                </p>
                                <span
                                  className={`inline-flex px-1.5 py-0.5 rounded text-[10px] font-medium capitalize ${
                                    p.isLive
                                      ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
                                      : "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
                                  }`}
                                >
                                  {p.status || (p.isLive ? "live" : "inactive")}
                                </span>
                              </div>
                            </div>
                          ))
                        })()}
                      </div>
                    )}

                    {!detailLoading && !detailError && activeDetailView === "deliveries" && (
                      <div className="space-y-2 text-xs max-h-64 overflow-auto">
                        {(() => {
                          const raw = detailData as any
                          const deliveries: any[] = Array.isArray(raw) ? raw : []
                          if (deliveries.length === 0) {
                            return (
                              <p className="text-muted-foreground">
                                No delivery history found for this rider.
                              </p>
                            )
                          }
                          return deliveries.map((d: any) => (
                            <div
                              key={d.id}
                              className="rounded-lg border bg-background/80 px-3 py-2 space-y-1"
                            >
                              <div className="flex items-start justify-between gap-2">
                                <p className="font-medium text-[13px]">
                                  Order #{d.orderId}
                                </p>
                                <span
                                  className={`inline-flex px-1.5 py-0.5 rounded text-[10px] font-medium capitalize ${
                                    d.status === "completed" || d.status === "delivered"
                                      ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
                                      : d.status === "pending" || d.status === "assigned"
                                        ? "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
                                        : d.status === "cancelled" || d.status === "failed"
                                          ? "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
                                          : "bg-muted text-muted-foreground"
                                  }`}
                                >
                                  {d.status || "unknown"}
                                </span>
                              </div>
                              <div className="flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-muted-foreground">
                                {d.fee != null && <span>Fee: {formatPrice(d.fee)}</span>}
                                {d.distanceKm != null && (
                                  <span>Distance: {d.distanceKm} km</span>
                                )}
                                {d.orderTotal != null && (
                                  <span>Order total: {formatPrice(d.orderTotal)}</span>
                                )}
                              </div>
                              {d.rate != null && (
                                <p className="text-[11px] text-muted-foreground">
                                  Rate: {"★".repeat(Math.round(d.rate))}{"☆".repeat(5 - Math.round(d.rate))} ({d.rate}/5)
                                </p>
                              )}
                              {d.feedback && (
                                <p className="text-[11px] text-muted-foreground">
                                  Feedback: {d.feedback}
                                </p>
                              )}
                              {d.createdAt && (
                                <p className="text-[10px] text-muted-foreground">
                                  {new Date(d.createdAt).toLocaleString()}
                                </p>
                              )}
                            </div>
                          ))
                        })()}
                      </div>
                    )}
                  </div>
                )}
              </div>

              <div className="flex gap-3 mt-6 pt-6 border-t">
                <button
                  onClick={() => setSelectedUser(null)}
                  className="flex-1 py-3 px-4 border rounded-xl font-medium hover:bg-muted transition-colors"
                >
                  Close
                </button>
                <button className="flex-1 py-3 px-4 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors">
                  Done
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Approve / Reject / Archive confirmation */}
      <AnimatePresence>
        {confirmAction && confirmUser && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
            onClick={closeConfirmDialog}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-background rounded-2xl p-6 w-full max-w-sm"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div
                    className={`w-10 h-10 rounded-full flex items-center justify-center ${
                      confirmAction === "approve"
                        ? "bg-green-500/10 text-green-600 dark:text-green-400"
                        : confirmAction === "reject"
                          ? "bg-red-500/10 text-red-600 dark:text-red-400"
                          : "bg-slate-500/10 text-slate-600 dark:text-slate-400"
                    }`}
                  >
                    <Icon
                      name={
                        confirmAction === "approve"
                          ? "check"
                          : confirmAction === "reject"
                            ? "ban"
                            : "box"
                      }
                    />
                  </div>
                  <div>
                    <h2 className="text-lg font-semibold">
                      {confirmAction === "approve"
                        ? "Approve buyer"
                        : confirmAction === "reject"
                          ? "Reject buyer"
                          : "Archive account"}
                    </h2>
                    <p className="text-xs text-muted-foreground">
                      {confirmAction === "approve"
                        ? "This will allow the buyer to use their account on the platform."
                        : confirmAction === "reject"
                          ? "This will deactivate the account. Use only for new registrations you are declining."
                          : "Soft-archive keeps their data. If they sign in again, the account is restored automatically."}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={closeConfirmDialog}
                  className="w-8 h-8 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
                >
                  <Icon name="times" size="sm" />
                </button>
              </div>

              <div className="mb-4 space-y-1 text-sm">
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Name</span>
                  <span className="font-medium">{getDisplayName(confirmUser as AdminUserDto)}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">Email</span>
                  <span className="font-medium break-all">
                    {confirmUser!["User email"] || "(no email)"}
                  </span>
                </div>
                {confirmAction === "reject" && (
                  <div className="pt-3">
                    <label className="block text-xs font-medium text-muted-foreground mb-1" htmlFor="reject-reason">
                      Rejection reason (optional)
                    </label>
                    <textarea
                      id="reject-reason"
                      value={rejectReason}
                      onChange={(e) => setRejectReason(e.target.value)}
                      rows={3}
                      className="w-full rounded-xl border bg-background px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none"
                      placeholder="Add a short explanation that will be logged with this action."
                    />
                  </div>
                )}
              </div>

              <div className="flex gap-3 mt-4">
                <button
                  type="button"
                  onClick={closeConfirmDialog}
                  className="flex-1 py-2 px-4 border rounded-xl text-sm font-medium hover:bg-muted transition-colors"
                  disabled={confirmLoading}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleConfirm}
                  className={`flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white transition-colors ${
                    confirmAction === "approve"
                      ? "bg-green-600 hover:bg-green-700"
                      : confirmAction === "reject"
                        ? "bg-red-600 hover:bg-red-700"
                        : "bg-slate-600 hover:bg-slate-700"
                  }`}
                  disabled={confirmLoading}
                >
                  {confirmLoading
                    ? confirmAction === "approve"
                      ? "Approving..."
                      : confirmAction === "reject"
                        ? "Rejecting..."
                        : "Archiving..."
                    : confirmAction === "approve"
                      ? "Confirm approve"
                      : confirmAction === "reject"
                        ? "Confirm reject"
                        : "Confirm archive"}
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export default function AdminUsersPage() {
  return (
    <Suspense fallback={<div className="p-8 text-muted-foreground">Loading users…</div>}>
      <AdminUsersContent />
    </Suspense>
  )
}
