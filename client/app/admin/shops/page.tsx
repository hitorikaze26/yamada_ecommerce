"use client"
import Link from "next/link"
import { Suspense, useEffect, useRef, useState } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"
import { adminApi, resolveImageUrl, resolvePrivateDocUrl } from "@/lib/api"
import { CATEGORIES } from "@/lib/types"
import { getAdminFetchError, unwrapAdminList } from "@/lib/admin-fetch"

interface StoreRegistrationDto {
  [key: string]: unknown
}

function AdminShopsContent() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const highlightedRegistrationId = searchParams.get("registrationId")
  const highlightedRef = useRef<HTMLDivElement | null>(null)
  const [registrations, setRegistrations] = useState<StoreRegistrationDto[]>([])
  const [searchQuery, setSearchQuery] = useState("")
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isActionLoading, setIsActionLoading] = useState(false)
  const [lastApprovedStore, setLastApprovedStore] = useState<{ id: number; name: string; email?: string } | null>(
    null,
  )
  const [statusFilter, setStatusFilter] = useState<"pending" | "accepted">(
    highlightedRegistrationId ? "pending" : "pending",
  )
  const [acceptedStores, setAcceptedStores] = useState<{ id: number; name: string; email?: string; address?: string; sellerName?: string }[]>([])
  const [detailsRegistration, setDetailsRegistration] = useState<StoreRegistrationDto | null>(null)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  useEffect(() => {
    const fetchRegistrations = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await adminApi.getApprovals()
        setRegistrations(unwrapAdminList(res.data, ["StoreRegistrations"]))
      } catch (err: any) {
        console.error("Failed to load store registrations", err)
        const status = err?.response?.status
        if (status === 401) {
          showAlert("Admin session expired. Please log in again.", "error")
          router.push("/auth/admin")
        } else {
          const message = getAdminFetchError(err, "Failed to load store registrations. Please try again.")
          setError(message)
          showAlert(message, "error")
        }
      } finally {
        setIsLoading(false)
      }
    }
    fetchRegistrations()
  }, [])

  useEffect(() => {
    if (statusFilter !== "accepted") return

    const fetchStores = async () => {
      try {
        setIsLoading(true)
        setError(null)
        const res = await adminApi.getStores()
        setAcceptedStores(unwrapAdminList(res.data, ["stores"]))
      } catch (err: any) {
        console.error("Failed to load stores", err)
        const status = err?.response?.status
        if (status === 401) {
          showAlert("Admin session expired. Please log in again.", "error")
          router.push("/auth/admin")
        } else {
          const message = getAdminFetchError(err, "Failed to load stores. Please try again.")
          setError(message)
          showAlert(message, "error")
        }
      } finally {
        setIsLoading(false)
      }
    }

    void fetchStores()
  }, [statusFilter])

  const filteredRegistrations = registrations.filter((reg) => {
    const name = (reg as any)["Store name"] ?? ""
    const seller = (reg as any)["Seller full name"] ?? ""
    const q = searchQuery.toLowerCase()
    return name.toLowerCase().includes(q) || seller.toLowerCase().includes(q)
  })

  const isImagePath = (path: string | undefined): boolean => {
    if (!path) return false
    return /\.(png|jpe?g|webp|gif)$/i.test(path)
  }

  function DocViewer({ label, rawPath, hasDoc, isImage }: { label: string; rawPath?: string; hasDoc: boolean; isImage: boolean }) {
    const [src, setSrc] = useState<string>("")
    const [loading, setLoading] = useState(false)

    useEffect(() => {
      if (!rawPath) return
      setLoading(true)
      const initialUrl = resolveImageUrl(rawPath) || ""
      if (initialUrl.startsWith("http")) {
        const isLikelyPrivate = /^(seller_dti|seller_bir|seller_permits|seller_ids|buyer_ids|rider_docs|report_evidence)\//.test(rawPath.replace(/\\/g, "/"))
        if (isLikelyPrivate) {
          resolvePrivateDocUrl(rawPath).then((signedUrl) => {
            if (signedUrl) setSrc(signedUrl)
            else setSrc(initialUrl)
          }).catch(() => setSrc(initialUrl))
          .finally(() => setLoading(false))
        } else {
          setSrc(initialUrl)
          setLoading(false)
        }
      } else {
        setSrc(initialUrl)
        setLoading(false)
      }
    }, [rawPath])

    if (!hasDoc) return <div key={label} className="space-y-1"><p className="font-medium">{label}</p><p>-</p></div>

    return (
      <div key={label} className="space-y-1">
        <p className="font-medium">{label}</p>
        {loading && <p className="text-xs text-muted-foreground">Loading...</p>}
        {!loading && isImage && (
          <img src={src} alt={label} className="w-32 h-24 rounded-md border object-cover bg-muted" />
        )}
        {!loading && !isImage && (
          <a href={src} target="_blank" rel="noopener noreferrer" className="underline">Open file</a>
        )}
      </div>
    )
  }

  const resolveCategories = (reg: StoreRegistrationDto): string => {
    const raw = (reg as any)["Categories json"] as string | undefined
    if (!raw) return ""
    try {
      const ids = JSON.parse(raw) as string[]
      if (!Array.isArray(ids) || ids.length === 0) return ""
      const byId = new Map<string, string>(CATEGORIES.map((c) => [c.id, c.name]))
      return ids.map((id) => byId.get(id) ?? id).join(", ")
    } catch {
      return ""
    }
  }

  useEffect(() => {
    if (highlightedRegistrationId && highlightedRef.current) {
      highlightedRef.current.scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }, [highlightedRegistrationId])

  const filteredStores = acceptedStores.filter((store) => {
    const name = store.name ?? ""
    const seller = store.sellerName ?? ""
    const q = searchQuery.toLowerCase()
    return name.toLowerCase().includes(q) || seller.toLowerCase().includes(q)
  })

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
        <h1 className="text-3xl font-bold mb-2">Shops</h1>
        <p className="text-muted-foreground">Manage and verify seller shops.</p>
      </div>

      {lastApprovedStore && (
        <div className="bg-emerald-50 border border-emerald-200 text-emerald-900 rounded-2xl p-4 text-sm flex flex-wrap items-center gap-3">
          <Icon name="check-circle" className="text-emerald-600" />
          <span>
            Store <span className="font-semibold">{lastApprovedStore.name}</span> created/confirmed with ID
            <span className="font-mono ml-1">{lastApprovedStore.id}</span>.
          </span>
          <a
            href={`/seller/${lastApprovedStore.id}/products`}
            className="ml-auto text-xs font-medium text-emerald-800 underline hover:text-emerald-900"
          >
            View store products (seller view)
          </a>
        </div>
      )}

      {/* View details modal */}
      {detailsRegistration && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40">
          <div className="bg-card border rounded-2xl max-w-3xl w-full mx-4 my-8 p-6 shadow-xl relative max-h-[80vh] overflow-y-auto">
            <button
              type="button"
              className="absolute top-3 right-3 text-muted-foreground hover:text-foreground text-sm"
              onClick={() => setDetailsRegistration(null)}
            >
              Close
            </button>

            <h2 className="text-xl font-semibold mb-2">
              {(detailsRegistration as any)["Store name"] ?? "Store details"}
            </h2>
            <p className="text-sm text-muted-foreground mb-4">
              Seller: {(detailsRegistration as any)["Seller full name"] ?? ""} ·{" "}
              {(detailsRegistration as any)["Seller email"] ?? ""}
            </p>

            <div className="grid md:grid-cols-2 gap-4 text-sm mb-4">
              <div className="space-y-1">
                <p className="font-semibold text-xs text-muted-foreground">Shop</p>
                <p>
                  <span className="font-medium">Purpose:</span> {(detailsRegistration as any)["Store purpose"] ?? ""}
                </p>
                <p>
                  <span className="font-medium">Tagline:</span> {(detailsRegistration as any)["Store tagline"] ?? ""}
                </p>
                <p>
                  <span className="font-medium">Categories:</span> {resolveCategories(detailsRegistration) || "-"}
                </p>
              </div>
              <div className="space-y-1">
                <p className="font-semibold text-xs text-muted-foreground">Seller Address</p>
                <p>
                  {[
                    (detailsRegistration as any)["Seller street address"],
                    (detailsRegistration as any)["Seller barangay"],
                    (detailsRegistration as any)["Seller municipality"],
                    (detailsRegistration as any)["Seller province"],
                    (detailsRegistration as any)["Seller region"],
                  ]
                    .filter(Boolean)
                    .join(", ") || "-"}
                </p>
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-4 text-sm">
              <div className="space-y-2">
                <p className="font-semibold text-xs text-muted-foreground">Documents</p>
                <div className="space-y-2 text-xs text-muted-foreground">
                  {(["DTI", "BIR TIN", "Business Permit"] as const).map((label) => {
                    const keyMap: Record<string, string> = {
                      DTI: "DTI path",
                      "BIR TIN": "BIR TIN path",
                      "Business Permit": "Business permit path",
                    }
                    const rawPath = (detailsRegistration as any)[keyMap[label]] as string | undefined
                    const hasDoc = !!rawPath
                    const isImage = isImagePath(rawPath)
                    return (
                      <DocViewer key={label} label={label} rawPath={rawPath} hasDoc={hasDoc} isImage={isImage} />
                    )
                  })}
                </div>
              </div>
              <div className="space-y-1 text-xs text-muted-foreground">
                <p>
                  Requested at: {(detailsRegistration as any)["Request date created"] ?? "-"}
                </p>
                <p>
                  Status: {(detailsRegistration as any)["Request status"] ?? "PENDING"}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {isLoading && (
        <div className="bg-card border rounded-2xl p-4">Loading store registrations...</div>
      )}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="bg-card border rounded-2xl p-4 space-y-4">
        <div className="flex items-center gap-2 text-sm">
          <button
            type="button"
            onClick={() => setStatusFilter("pending")}
            className={`px-3 py-1.5 rounded-full border text-xs font-medium ${
              statusFilter === "pending" ? "bg-primary text-primary-foreground border-primary" : "border-border"
            }`}
          >
            Pending
          </button>
          <button
            type="button"
            onClick={() => setStatusFilter("accepted")}
            className={`px-3 py-1.5 rounded-full border text-xs font-medium ${
              statusFilter === "accepted" ? "bg-primary text-primary-foreground border-primary" : "border-border"
            }`}
          >
            Accepted
          </button>
        </div>

        <div className="flex flex-wrap items-center gap-4">
          <div className="flex-1 min-w-[200px]">
            <div className="relative">
              <Icon name="search" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search shops..."
                className="w-full pl-10 pr-4 py-2 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none"
              />
            </div>
          </div>
        </div>
      </div>

      {/* List */}
      {!isLoading && !error && statusFilter === "pending" && (
        <div className="space-y-4">
          {filteredRegistrations.length === 0 ? (
            <p className="text-sm text-muted-foreground">No pending store registrations.</p>
          ) : (
            filteredRegistrations.map((reg, index) => {
              const isHighlighted =
                highlightedRegistrationId && String((reg as any).id) === highlightedRegistrationId
              return (
                <motion.div
                  key={index}
                  layout
                  ref={isHighlighted ? highlightedRef : undefined}
                  className={`bg-card border rounded-2xl p-6 ${
                    isHighlighted ? "border-primary ring-1 ring-primary/40" : ""
                  }`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-4 mb-4">
                    <div className="flex items-center gap-4">
                      <div className="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center">
                        <Icon name="store" className="text-primary" />
                      </div>
                      <div>
                        <h3 className="text-lg font-semibold">
                          {(reg as any)["Store name"] ?? "Store registration"}
                        </h3>
                        <p className="text-sm text-muted-foreground">
                          {(reg as any)["Seller full name"] ?? ""}
                        </p>
                        <p className="text-xs text-muted-foreground mt-1">
                          {(reg as any)["Seller email"] ?? ""}
                        </p>
                      </div>
                    </div>
                    <span className="px-3 py-1 rounded-full text-xs font-medium capitalize bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400">
                      pending
                    </span>
                  </div>

                  {/* Summary section */}
                  <div className="text-sm mb-3 space-y-1">
                    <p>
                      <span className="font-medium">Purpose:</span> {(reg as any)["Store purpose"] ?? ""}
                    </p>
                    <p>
                      <span className="font-medium">Tagline:</span> {(reg as any)["Store tagline"] ?? ""}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      Requested: {(reg as any)["Request date created"] ?? ""}
                    </p>
                  </div>

                  <div className="flex flex-wrap gap-3 justify-between mt-2">
                    <button
                      type="button"
                      className="px-3 py-2 rounded-xl border text-xs font-medium text-muted-foreground hover:bg-muted"
                      onClick={() => setDetailsRegistration(reg)}
                    >
                      View details
                    </button>

                    <div className="flex flex-wrap gap-3 justify-end">
                      <button
                        type="button"
                        disabled={isActionLoading}
                        onClick={async () => {
                          const id = (reg as any).id as number | undefined
                          if (!id) return
                          try {
                            setIsActionLoading(true)
                            const res = await adminApi.approveUser(String(id))
                            const store = (res as any)?.data?.store
                            if (store) {
                              setLastApprovedStore({ id: store.id, name: store.name, email: store.email })
                            }
                            setRegistrations((prev) => prev.filter((r, i) => i !== index))
                            showAlert("Store registration approved.", "success")
                          } catch (err: any) {
                            console.error("Failed to approve store registration", err)
                            const status = err?.response?.status
                            if (status === 401) {
                              showAlert("Admin session expired. Please log in again.", "error")
                              router.push("/auth/admin")
                            } else {
                              setError("Failed to approve store registration.")
                              showAlert("Failed to approve store registration.", "error")
                            }
                          } finally {
                            setIsActionLoading(false)
                          }
                        }}
                        className="px-4 py-2 rounded-xl bg-emerald-600 text-white text-sm font-medium hover:bg-emerald-700 disabled:opacity-60"
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        disabled={isActionLoading}
                        onClick={async () => {
                          const id = (reg as any).id as number | undefined
                          if (!id) return
                          try {
                            setIsActionLoading(true)
                            await adminApi.rejectUser(String(id), "Rejected by admin")
                            setRegistrations((prev) => prev.filter((r, i) => i !== index))
                            showAlert("Store registration rejected.", "warning")
                          } catch (err: any) {
                            console.error("Failed to reject store registration", err)
                            const status = err?.response?.status
                            if (status === 401) {
                              showAlert("Admin session expired. Please log in again.", "error")
                              router.push("/auth/admin")
                            } else {
                              setError("Failed to reject store registration.")
                              showAlert("Failed to reject store registration.", "error")
                            }
                          } finally {
                            setIsActionLoading(false)
                          }
                        }}
                        className="px-4 py-2 rounded-xl border border-destructive text-destructive text-sm font-medium hover:bg-destructive/10 disabled:opacity-60"
                      >
                        Reject
                      </button>
                    </div>
                  </div>
                </motion.div>
              )
            })
          )}
        </div>
      )}

      {!isLoading && !error && statusFilter === "accepted" && (
        <div className="space-y-4">
          {filteredStores.length === 0 ? (
            <p className="text-sm text-muted-foreground">No accepted stores found.</p>
          ) : (
            filteredStores.map((store) => (
              <Link
                key={store.id}
                href={`/admin/shops/${store.id}`}
                className="block bg-card border rounded-2xl p-5 hover:border-primary/60 hover:bg-primary/5 transition-colors"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                      <Icon name="store" className="text-primary" />
                    </div>
                    <div>
                      <h3 className="text-base font-semibold">{store.name}</h3>
                      <p className="text-xs text-muted-foreground">{store.sellerName ?? ""}</p>
                      <p className="text-xs text-muted-foreground">{store.address ?? ""}</p>
                    </div>
                  </div>
                  <Icon name="arrow-right" className="text-muted-foreground" />
                </div>
              </Link>
            ))
          )}
        </div>
      )}
    </div>
  )
}

export default function AdminShopsPage() {
  return (
    <Suspense fallback={<div className="p-8 text-muted-foreground">Loading shops…</div>}>
      <AdminShopsContent />
    </Suspense>
  )
}
