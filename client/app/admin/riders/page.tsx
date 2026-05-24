"use client"

import { Suspense, useEffect, useState } from "react"
import { useSearchParams } from "next/navigation"
import { adminApi, resolveImageUrl } from "@/lib/api"
import { adminUserDisplayName, normalizeAdminUser } from "@/lib/admin-user"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"

interface AdminUser {
  id: number
  email: string
  given_name?: string | null
  surname?: string | null
  "User active": boolean
  "User verified": boolean
  role: string
  user_role: string[]
}

function AdminRidersContent() {
  const searchParams = useSearchParams()
  const [riders, setRiders] = useState<AdminUser[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedRider, setSelectedRider] = useState<AdminUser | null>(null)
  const [detail, setDetail] = useState<any | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState<string | null>(null)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  useEffect(() => {
    const load = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await adminApi.getUsers({ role: "rider" })
        const users = (res.data as { users?: Record<string, unknown>[] })?.users || []
        setRiders(users.map((u) => normalizeAdminUser(u) as AdminUser))
      } catch (e) {
        console.error("Failed to load riders", e)
        setError("Failed to load rider list. Please try again.")
      } finally {
        setIsLoading(false)
      }
    }

    void load()
  }, [])

  useEffect(() => {
    const idParam = searchParams.get("userId")
    if (!idParam) return

    const userId = Number(idParam)
    if (!userId || !Number.isFinite(userId)) return

    if (!riders || riders.length === 0) return

    const match = riders.find((r) => r.id === userId)
    if (match) {
      void handleViewDetails(match)
    }
  }, [searchParams, riders])

  const handleApprove = async (userId: number) => {
    try {
      await adminApi.approveRider(userId)
      setRiders((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, "User verified": true, "User active": true } : u)),
      )
      showAlert("Rider has been approved and activated.", "success")
    } catch (e) {
      console.error("Failed to approve rider", e)
      showAlert("Failed to approve rider. Please try again.", "error")
    }
  }

  const handleApproveInModal = async () => {
    if (!selectedRider) return

    try {
      await adminApi.approveRider(selectedRider.id)
      setRiders((prev) =>
        prev.map((u) =>
          u.id === selectedRider.id ? { ...u, "User verified": true, "User active": true } : u,
        ),
      )
      setDetail((prev: any) =>
        prev
          ? {
              ...prev,
              user: {
                ...prev.user,
                "User verified": true,
                "User active": true,
              },
            }
          : prev,
      )
      showAlert("Rider has been approved and activated.", "success")
    } catch (e) {
      console.error("Failed to approve rider", e)
      showAlert("Failed to approve rider. Please try again.", "error")
    }
  }

  const handleRejectInModal = async () => {
    if (!selectedRider) return

    try {
      await adminApi.rejectRider(selectedRider.id)
      setRiders((prev) =>
        prev.map((u) => (u.id === selectedRider.id ? { ...u, "User active": false } : u)),
      )
      setDetail((prev: any) =>
        prev
          ? {
              ...prev,
              user: {
                ...prev.user,
                "User active": false,
              },
            }
          : prev,
      )
      showAlert("Rider has been rejected and deactivated.", "warning")
    } catch (e) {
      console.error("Failed to reject rider", e)
      showAlert("Failed to reject rider. Please try again.", "error")
    }
  }

  const handleViewDetails = async (rider: AdminUser) => {
    setSelectedRider(rider)
    setDetail(null)
    setDetailError(null)
    setDetailLoading(true)

    try {
      const res = await adminApi.getRiderDetail(rider.id)
      setDetail((res.data as any)?.rider ?? null)
    } catch (e) {
      console.error("Failed to load rider detail", e)
      setDetailError("Failed to load rider details. The backend endpoint may not be available.")
    } finally {
      setDetailLoading(false)
    }
  }

  const handleReject = async (userId: number) => {
    try {
      await adminApi.rejectRider(userId)
      setRiders((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, "User active": false } : u)),
      )
      showAlert("Rider has been rejected and deactivated.", "warning")
    } catch (e) {
      console.error("Failed to reject rider", e)
      showAlert("Failed to reject rider. Please try again.", "error")
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
        <h1 className="text-3xl font-bold mb-2">Verify Riders</h1>
        <p className="text-muted-foreground">
          Review rider accounts and toggle their verification status.
        </p>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-6">Loading riders...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && (
        <div className="bg-card border rounded-2xl p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl font-semibold">Rider Accounts</h2>
            <span className="text-sm text-muted-foreground">{riders.length} riders</span>
          </div>

          {riders.length === 0 ? (
            <p className="text-sm text-muted-foreground">No rider accounts found.</p>
          ) : (
            <div className="space-y-3">
              {riders.map((rider) => {
                const fullName = `${rider.given_name || ""} ${rider.surname || ""}`.trim() || rider.email
                const isVerified = rider["User verified"]
                const isActive = rider["User active"]

                return (
                  <div
                    key={rider.id}
                    className="flex items-center justify-between gap-4 rounded-xl border bg-muted/40 px-4 py-3"
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                        <Icon name="truck" className="text-primary" />
                      </div>
                      <div className="space-y-1">
                        <p className="text-sm font-medium">{fullName}</p>
                        <p className="text-xs text-muted-foreground">{rider.email}</p>
                        <div className="flex items-center gap-2 text-xs">
                          <span
                            className={`px-2 py-0.5 rounded-full border text-[11px] font-medium ${
                              isVerified
                                ? "bg-green-50 border-green-200 text-green-700"
                                : "bg-amber-50 border-amber-200 text-amber-700"
                            }`}
                          >
                            {isVerified ? "Verified" : "Pending"}
                          </span>
                          {!isActive && (
                            <span className="px-2 py-0.5 rounded-full border border-destructive/40 bg-destructive/5 text-destructive text-[11px] font-medium">
                              Deactivated
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => handleViewDetails(rider)}
                        className="px-3 py-1.5 rounded-lg text-xs font-medium bg-muted hover:bg-muted/80 flex items-center gap-1"
                      >
                        <Icon name="eye" size="sm" />
                        <span>View details</span>
                      </button>
                      {!isVerified && (
                        <button
                          type="button"
                          onClick={() => handleApprove(rider.id)}
                          className="px-3 py-1.5 rounded-lg text-xs font-medium bg-green-500 text-white hover:bg-green-600"
                        >
                          Approve
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => handleReject(rider.id)}
                        className="px-3 py-1.5 rounded-lg text-xs font-medium bg-destructive text-destructive-foreground hover:bg-destructive/90"
                      >
                        Reject
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      )}

      {/* Rider detail modal */}
      {selectedRider && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-background border rounded-2xl p-6 w-full max-w-xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="text-lg font-semibold">Rider Details</h2>
                <p className="text-xs text-muted-foreground">
                  Full information provided by the rider during registration.
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  setSelectedRider(null)
                  setDetail(null)
                  setDetailError(null)
                }}
                className="w-8 h-8 rounded-full hover:bg-muted flex items-center justify-center transition-colors"
              >
                <Icon name="times" size="sm" />
              </button>
            </div>

            {detailLoading && <p className="text-sm text-muted-foreground">Loading details...</p>}
            {detailError && !detailLoading && (
              <p className="text-sm text-destructive">{detailError}</p>
            )}

            {!detailLoading && !detailError && detail && (
              <div className="space-y-4 text-sm">
                {(() => {
                  const verified = Boolean(detail.user?.["User verified"])
                  const active = Boolean(detail.user?.["User active"])
                  return (
                    <div className="flex gap-2 text-xs">
                      <span
                        className={`px-2 py-0.5 rounded-full border text-[11px] font-medium ${
                          verified
                            ? "bg-green-50 border-green-200 text-green-700"
                            : "bg-amber-50 border-amber-200 text-amber-700"
                        }`}
                      >
                        {verified ? "Verified" : "Pending"}
                      </span>
                      {!active && (
                        <span className="px-2 py-0.5 rounded-full border border-destructive/40 bg-destructive/5 text-destructive text-[11px] font-medium">
                          Deactivated
                        </span>
                      )}
                    </div>
                  )
                })()}
                <div className="grid sm:grid-cols-2 gap-3">
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Name</span>
                    <span className="font-medium">
                      {detail.user?.given_name || ""} {detail.user?.surname || ""}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Email</span>
                    <span className="font-medium break-all">{detail.user?.["User email"]}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Contact number</span>
                    <span className="font-medium">{detail.user?.contact_number || "(none)"}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Vehicle type</span>
                    <span className="font-medium">{detail.profile?.vehicleType}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">License number</span>
                    <span className="font-medium">{detail.profile?.licenseNumber}</span>
                  </div>
                </div>

                <div className="pt-3 border-t">
                  <p className="text-xs font-medium text-muted-foreground mb-1">Address</p>
                  <div className="text-xs space-y-1">
                    <p>{detail.profile?.address?.streetAddress}</p>
                    <p>
                      {detail.profile?.address?.barangayName}, {" "}
                      {detail.profile?.address?.municipalityName}
                    </p>
                    <p>
                      {detail.profile?.address?.provinceName}, {" "}
                      {detail.profile?.address?.regionName}
                    </p>
                    {detail.profile?.address?.postalCode && (
                      <p>Postal code: {detail.profile.address.postalCode}</p>
                    )}
                  </div>
                </div>

                <div className="pt-3 border-t">
                  <p className="text-xs font-medium text-muted-foreground mb-2">Documents</p>
                  <div className="space-y-3 text-xs">
                    {/* License */}
                    <div className="space-y-1">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-2">
                          <Icon name="id-card" size="sm" className="text-primary" />
                          <span className="font-medium">Driver&apos;s License</span>
                        </div>
                        {detail.profile?.documents?.licensePath ? (
                          <a
                            href={
                              resolveImageUrl(detail.profile.documents.licenseUrl) ||
                              resolveImageUrl(detail.profile.documents.licensePath) ||
                              "#"
                            }
                            target="_blank"
                            rel="noreferrer"
                            className="text-primary underline"
                          >
                            Open
                          </a>
                        ) : (
                          <span className="text-muted-foreground">No file</span>
                        )}
                      </div>
                      {detail.profile?.documents?.licenseUrl &&
                        !detail.profile.documents.licenseUrl.toLowerCase().endsWith(".pdf") && (
                          <img
                            src={
                              resolveImageUrl(detail.profile.documents.licenseUrl) ||
                              "/placeholder.svg"
                            }
                            alt="License preview"
                            className="mt-1 h-32 w-full rounded border object-contain bg-muted"
                          />
                        )}
                    </div>

                    {/* OR/CR */}
                    <div className="space-y-1">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-2">
                          <Icon name="file-alt" size="sm" className="text-primary" />
                          <span className="font-medium">OR/CR</span>
                        </div>
                        {detail.profile?.documents?.orcrPath ? (
                          <a
                            href={
                              resolveImageUrl(detail.profile.documents.orcrUrl) ||
                              resolveImageUrl(detail.profile.documents.orcrPath) ||
                              "#"
                            }
                            target="_blank"
                            rel="noreferrer"
                            className="text-primary underline"
                          >
                            Open
                          </a>
                        ) : (
                          <span className="text-muted-foreground">No file</span>
                        )}
                      </div>
                      {detail.profile?.documents?.orcrUrl &&
                        !detail.profile.documents.orcrUrl.toLowerCase().endsWith(".pdf") && (
                          <img
                            src={
                              resolveImageUrl(detail.profile.documents.orcrUrl) ||
                              "/placeholder.svg"
                            }
                            alt="OR/CR preview"
                            className="mt-1 h-32 w-full rounded border object-contain bg-muted"
                          />
                        )}
                    </div>
                  </div>
                </div>

                <div className="flex justify-between gap-3 pt-4 border-t mt-4">
                  <div className="flex gap-2">
                    {!detail.user?.["User verified"] && (
                      <button
                        type="button"
                        onClick={handleApproveInModal}
                        className="px-4 py-2 rounded-xl bg-green-500 text-white text-sm font-medium hover:bg-green-600 transition-colors"
                      >
                        Approve rider
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={handleRejectInModal}
                      className="px-4 py-2 rounded-xl bg-destructive text-destructive-foreground text-sm font-medium hover:bg-destructive/90 transition-colors"
                    >
                      Reject rider
                    </button>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedRider(null)
                      setDetail(null)
                      setDetailError(null)
                    }}
                    className="px-4 py-2 rounded-xl border text-sm font-medium hover:bg-muted transition-colors"
                  >
                    Close
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

export default function AdminRidersPage() {
  return (
    <Suspense fallback={<div className="p-8 text-muted-foreground">Loading riders…</div>}>
      <AdminRidersContent />
    </Suspense>
  )
}
