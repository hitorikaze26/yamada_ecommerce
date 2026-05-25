"use client"
import { useEffect, useMemo, useState } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { riderApi, riderAccountApi } from "@/lib/api"
import { riderDeliveryEntityId, riderDeliveryLabel } from "@/lib/rider-delivery"
import { formatPrice } from "@/lib/format"
import { useAuth } from "@/context/auth-context"
import { useChatOpen } from "@/hooks/use-chat-open"
import { ReportLinkButton } from "@/components/report/report-link-button"

const tabs = ["active", "completed", "all"]

interface RiderDeliveryRow {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  deliveryNotes?: string | null
  orderId: number | null
  status: string
  fee: number
  distanceKm: number
  createdAt: string | null
  shippingAddress?: string | null
  municipalityName?: string | null
  store?: {
    id?: number | null
    name?: string | null
  }
  buyer?: {
    id?: number | null
    email?: string | null
    name?: string | null
    initials?: string | null
    contact?: string | null
  }
  items?: { id: number; name?: string | null; quantity: number }[]
  isAutoMatched?: boolean
  proofPhotoUrl?: string | null
  proofNote?: string | null
}

const statusColors: Record<string, { bg: string; text: string }> = {
  pending: { bg: "bg-amber-100 dark:bg-amber-900/30", text: "text-amber-700 dark:text-amber-400" },
  pickup: { bg: "bg-primary/10", text: "text-primary" },
  transit: { bg: "bg-purple-100 dark:bg-purple-900/30", text: "text-purple-700 dark:text-purple-400" },
  delivered: { bg: "bg-green-100 dark:bg-green-900/30", text: "text-green-700 dark:text-green-400" },
}

export default function RiderDeliveriesPage() {
  const { isVerified } = useAuth()
  const { isBusy, openRiderToSeller } = useChatOpen()
  const [activeTab, setActiveTab] = useState("active")
  const [deliveries, setDeliveries] = useState<RiderDeliveryRow[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [selectedMunicipality, setSelectedMunicipality] = useState<string>("all")
  const [riderMunicipality, setRiderMunicipality] = useState<string | null>(null)
  const [riderPickupLabel, setRiderPickupLabel] = useState<string | null>(null)
  const [selectedDelivery, setSelectedDelivery] = useState<RiderDeliveryRow | null>(null)
  const [toastMessage, setToastMessage] = useState<string | null>(null)
  const [deliveryToMarkDelivered, setDeliveryToMarkDelivered] = useState<RiderDeliveryRow | null>(null)
  const [proofNote, setProofNote] = useState<string>("")
  const [proofPhoto, setProofPhoto] = useState<File | null>(null)
  const [isSubmittingProof, setIsSubmittingProof] = useState(false)
  const [deliveriesForbidden, setDeliveriesForbidden] = useState(false)

  useEffect(() => {
    const load = async () => {
      setIsLoading(true)
      setDeliveriesForbidden(false)
      try {
        const res = await riderApi.getDeliveries()
        const data = (res.data as any)?.deliveries as RiderDeliveryRow[] | undefined
        setDeliveries(data || [])
      } catch (e: unknown) {
        const status = (e as { response?: { status?: number } })?.response?.status
        if (status === 403) {
          setDeliveriesForbidden(true)
        }
        setDeliveries([])
      } finally {
        setIsLoading(false)
      }
    }

    void load()
  }, [])

  useEffect(() => {
    const loadProfileMunicipality = async () => {
      try {
        const res = await riderAccountApi.getProfile()
        const profile = (res.data as any)?.profile ?? res.data
        const municipality: string | undefined = profile?.address?.municipalityName
        const province: string | undefined = profile?.address?.provinceName

        if (municipality) {
          setRiderMunicipality(municipality)
          setSelectedMunicipality(municipality)
          const label = province ? `${municipality}, ${province}` : municipality
          setRiderPickupLabel(label)
        }
      } catch {
        // If profile cannot be loaded, keep the default "all" filter
      }
    }

    void loadProfileMunicipality()
  }, [])

  useEffect(() => {
    if (!toastMessage) return

    const id = setTimeout(() => {
      setToastMessage(null)
    }, 3000)

    return () => clearTimeout(id)
  }, [toastMessage])

  const municipalities = useMemo(() => {
    const names = new Set<string>()
    deliveries.forEach((d) => {
      if (d.municipalityName) {
        names.add(d.municipalityName)
      }
    })

    // Always ensure the rider's own municipality is present in the options,
    // even if there are no current deliveries there or the filter is set to "all".
    if (riderMunicipality) {
      names.add(riderMunicipality)
    }

    return Array.from(names).sort((a, b) => a.localeCompare(b))
  }, [deliveries, riderMunicipality])

  const filteredDeliveries = deliveries.filter((d) => {
    if (activeTab === "active" && !(d.status === "pickup" || d.status === "transit" || d.status === "pending"))
      return false
    if (activeTab === "completed" && d.status !== "delivered") return false

    if (selectedMunicipality !== "all") {
      return d.municipalityName === selectedMunicipality
    }

    return true
  })

  const updateStatus = (id: number, newStatus: string) => {
    setDeliveries((prev) => prev.map((d) => (d.id === id ? { ...d, status: newStatus } : d)))
  }

  const handleUpdateStatus = async (delivery: RiderDeliveryRow, newStatus: "pickup" | "transit" | "delivered") => {
    // Only real RiderDelivery rows (not auto-matched orders) can be updated
    if (delivery.isAutoMatched) return

    try {
      const id = riderDeliveryEntityId(delivery)
      await riderApi.updateDeliveryStatus(id, newStatus)
      updateStatus(delivery.id, newStatus)
    } catch {
      setToastMessage("Error updating delivery status. Please try again.")
    }
  }

  const handleAcceptDelivery = async (delivery: RiderDeliveryRow) => {
    if (!delivery.isAutoMatched || !delivery.orderId) return

    try {
      await riderApi.acceptDelivery(delivery.orderId)

      // After acceptance, refresh the deliveries list so the newly created
      // RiderDelivery row (now assigned to this rider) appears immediately
      // in the UI instead of disappearing until the rider navigates away.
      try {
        const res = await riderApi.getDeliveries()
        const data = (res.data as any)?.deliveries as RiderDeliveryRow[] | undefined
        setDeliveries(data || [])
      } catch {
        // If refresh fails, keep the previous list; the next full reload
        // will still pick up the updated deliveries.
      }

      setToastMessage("Delivery accepted, now in your active list.")
    } catch {
      // TODO: add toast; for now, ignore errors on accept
    }
  }

  const formatDropoffAddress = (shippingAddress?: string | null, municipalityName?: string | null) => {
    if (!shippingAddress && !municipalityName) return "Customer address"

    // Try to parse structured address JSON/dict first
    let parts: string[] = []
    try {
      if (shippingAddress && shippingAddress.trim().startsWith("{")) {
        // Shipping address may be a JSON/dict-like string (Python style with single quotes)
        let cleaned = shippingAddress.trim()

        // Handle case where the entire string is wrapped in quotes
        if ((cleaned.startsWith('"') && cleaned.endsWith('"')) || (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
          cleaned = cleaned.slice(1, -1)
        }

        // Convert Python-style to JSON
        // 1. Replace single-quoted keys with double-quoted keys
        cleaned = cleaned.replace(/'([^']+)':/g, '"$1":')
        // 2. Replace single-quoted string values with double-quoted values
        cleaned = cleaned.replace(/: '([^']*)'/g, ': "$1"')
        // 3. Replace single quotes after commas
        cleaned = cleaned.replace(/, '([^']*)'/g, ', "$1"')
        // 4. Handle single quotes at the end of the string (closing brace)
        cleaned = cleaned.replace(/'}/g, '"}')
        // 5. Handle single quotes before commas
        cleaned = cleaned.replace(/',/g, '",')
        // 6. Replace Python None with JSON null
        cleaned = cleaned.replace(/: None/g, ': null')
        cleaned = cleaned.replace(/: None,/g, ': null,')
        cleaned = cleaned.replace(/, None}/g, ', null}')

        const obj = JSON.parse(cleaned)

        // Build address from components in order of specificity
        if (obj.streetAddress && obj.streetAddress !== "None" && obj.streetAddress !== null) parts.push(String(obj.streetAddress))
        if (obj.barangayName && obj.barangayName !== "None" && obj.barangayName !== null) parts.push(String(obj.barangayName))
        if (obj.municipalityName && obj.municipalityName !== "None" && obj.municipalityName !== null) parts.push(String(obj.municipalityName))
        if (obj.provinceName && obj.provinceName !== "None" && obj.provinceName !== null) parts.push(String(obj.provinceName))
        if (obj.postalCode && obj.postalCode !== "None" && obj.postalCode !== null) parts.push(String(obj.postalCode))
      }
    } catch {
      // Fall back to raw string below
    }

    if (parts.length > 0) {
      return parts.join(", ")
    }

    // Fallback: prepend municipality when available, otherwise use raw string
    if (municipalityName && shippingAddress) return `${municipalityName} — ${shippingAddress}`
    if (municipalityName) return municipalityName
    if (shippingAddress) return shippingAddress

    return "Customer address"
  }

  const handleOpenProofModal = (delivery: RiderDeliveryRow) => {
    setDeliveryToMarkDelivered(delivery)
    setProofNote("")
    setProofPhoto(null)
  }

  const handleCloseProofModal = () => {
    setDeliveryToMarkDelivered(null)
    setProofNote("")
    setProofPhoto(null)
    setIsSubmittingProof(false)
  }

  const reloadDeliveries = async () => {
    try {
      const res = await riderApi.getDeliveries()
      const data = (res.data as any)?.deliveries as RiderDeliveryRow[] | undefined
      setDeliveries(data || [])
    } catch {
      setDeliveries([])
    }
  }

  const handleSaveProof = async () => {
    if (!deliveryToMarkDelivered) return
    if (!proofPhoto) {
      setToastMessage("Please attach a delivery photo as proof before saving.")
      return
    }
    try {
      setIsSubmittingProof(true)

      await riderApi.uploadDeliveryProof(riderDeliveryEntityId(deliveryToMarkDelivered), {
        note: proofNote,
        photo: proofPhoto,
      })

      await reloadDeliveries()
      handleCloseProofModal()
      setToastMessage("Delivery completed successfully.")
    } catch {
      setToastMessage("Error saving proof of delivery. Please try again.")
    } finally {
      setIsSubmittingProof(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Deliveries</h1>
        <p className="text-muted-foreground">
          Manage your delivery assignments. New deliveries in your area will appear here automatically.
        </p>
      </div>

      {(deliveriesForbidden || !isVerified()) && (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 dark:bg-amber-950/30 p-4 text-sm text-amber-900 dark:text-amber-200">
          Your rider account is awaiting admin approval. Deliveries will appear here once you are verified.
        </div>
      )}

      {/* Tabs + Municipality Filter */}
      <div className="flex flex-wrap items-center gap-4 justify-between">
        <div className="flex gap-2">
          {tabs.map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`px-4 py-2 rounded-xl text-sm font-medium capitalize transition-colors ${
                activeTab === tab
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted hover:bg-muted/80 text-muted-foreground hover:text-foreground"
              }`}
            >
              {tab}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs text-muted-foreground">Filter by area:</span>
          <select
            className="text-sm px-3 py-2 rounded-xl border bg-background"
            value={selectedMunicipality}
            onChange={(e) => setSelectedMunicipality(e.target.value)}
          >
            <option value="all">All areas</option>
            {municipalities.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Deliveries List */}
      <AnimatePresence mode="wait">
        <motion.div key={activeTab} initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
          {filteredDeliveries.length === 0 ? (
            <div className="bg-card border rounded-2xl p-12 text-center">
              <Icon name="truck" size="xl" className="mx-auto text-muted-foreground mb-4" />
              <h3 className="text-lg font-semibold mb-2">No deliveries</h3>
              <p className="text-muted-foreground">No {activeTab} deliveries at the moment.</p>
            </div>
          ) : (
            filteredDeliveries.map((delivery) => (
              <motion.div
                key={delivery.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="bg-card border rounded-2xl p-6"
              >
                <div className="flex flex-wrap items-start justify-between gap-4 mb-4">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <p className="font-semibold text-lg">{riderDeliveryLabel(delivery)}</p>
                      <span
                        className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${statusColors[delivery.status].bg} ${statusColors[delivery.status].text}`}
                      >
                        {delivery.status === "pickup"
                          ? "Ready for Pickup"
                          : delivery.status === "transit"
                            ? "In Transit"
                            : delivery.status === "pending"
                              ? "Shipped"
                              : delivery.status}
                      </span>
                      {delivery.isAutoMatched && (
                        <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 uppercase tracking-wide">
                          New in your area
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-muted-foreground">Order #{delivery.orderId}</p>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-xl text-primary">{formatPrice(delivery.fee)}</p>
                    {delivery.distanceKm ? (
                      <p className="text-sm text-muted-foreground">
                        {delivery.distanceKm.toFixed(1)} km
                      </p>
                    ) : (
                      <p className="text-sm text-muted-foreground">Delivery Fee</p>
                    )}
                  </div>
                </div>

                <div className="grid md:grid-cols-2 gap-4 mb-4">
                  <div className="flex items-start gap-3 p-3 bg-muted/50 rounded-xl">
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                      <Icon name="land-layer-location" className="text-primary" />
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">Pickup Location</p>
                      <p className="font-medium">
                        {riderPickupLabel || riderMunicipality || "Your area"}
                      </p>
                      <p className="text-xs text-muted-foreground mt-1">
                        Rider will pick up from their area and proceed to the dropoff location.
                      </p>
                    </div>
                  </div>
                  <div
                    className={`flex items-start gap-3 p-3 rounded-xl ${
                      delivery.status === "delivered"
                        ? "bg-green-50 dark:bg-green-900/20 border border-green-200/60 dark:border-green-800/40"
                        : "bg-purple-50 dark:bg-purple-900/20 border border-purple-200/60 dark:border-purple-800/40"
                    }`}
                  >
                    <div
                      className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                        delivery.status === "delivered"
                          ? "bg-green-100 dark:bg-green-900/30"
                          : "bg-purple-100 dark:bg-purple-900/30"
                      }`}
                    >
                      <Icon
                        name="map-pin"
                        className={delivery.status === "delivered" ? "text-green-500" : "text-purple-600 dark:text-purple-400"}
                      />
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground mb-1">Dropoff Location</p>
                      <p className="font-medium">
                        {formatDropoffAddress(delivery.shippingAddress, delivery.municipalityName)}
                      </p>
                      {delivery.buyer && (
                        <p className="text-xs text-muted-foreground mt-1">
                          <span className="font-semibold">Buyer:</span>{" "}
                          {delivery.buyer.name || delivery.buyer.email}
                          {delivery.buyer.contact && ` • ${delivery.buyer.contact}`}
                        </p>
                      )}
                    </div>
                  </div>
                </div>

                {delivery.store?.id != null && (
                  <button
                    type="button"
                    disabled={isBusy(`rider-delivery-${delivery.id}`)}
                    onClick={() =>
                      void openRiderToSeller(
                        `rider-delivery-${delivery.id}`,
                        Number(delivery.store?.id),
                        delivery.orderId ?? undefined,
                      )
                    }
                    className="mt-2 w-full text-xs px-3 py-2 rounded-xl border hover:bg-muted transition-colors disabled:opacity-60 disabled:pointer-events-none inline-flex items-center justify-center gap-1.5"
                  >
                    {isBusy(`rider-delivery-${delivery.id}`) ? (
                      <>
                        <span className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
                        Opening chat…
                      </>
                    ) : (
                      <>
                        <Icon name="comments" size="sm" />
                        Message seller
                      </>
                    )}
                  </button>
                )}

                <div className="flex justify-between items-center mt-2 gap-2 flex-wrap">
                  <div className="flex gap-2">
                    {delivery.isAutoMatched && (
                      <button
                        type="button"
                        onClick={() => handleAcceptDelivery(delivery)}
                        className="text-xs px-3 py-1 rounded-full bg-amber-600 text-white hover:bg-amber-700 transition-colors"
                      >
                        Accept delivery
                      </button>
                    )}
                    {!delivery.isAutoMatched && delivery.status === "pending" && (
                      <button
                        type="button"
                        onClick={() => handleUpdateStatus(delivery, "pickup")}
                        className="text-xs px-3 py-1 rounded-full bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
                      >
                        Start pickup
                      </button>
                    )}
                    {!delivery.isAutoMatched && delivery.status === "pickup" && (
                      <button
                        type="button"
                        onClick={() => handleUpdateStatus(delivery, "transit")}
                        className="text-xs px-3 py-1 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                      >
                        On the way
                      </button>
                    )}
                    {!delivery.isAutoMatched && delivery.status === "transit" && (
                      <>
                        {delivery.buyer?.contact && (
                          <button
                            type="button"
                            onClick={() => window.open(`tel:${delivery.buyer?.contact}`, "_self")}
                            className="text-xs px-3 py-1 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                          >
                            Call
                          </button>
                        )}
                        <button
                          type="button"
                          onClick={() => handleOpenProofModal(delivery)}
                          className="text-xs px-3 py-1 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                        >
                          Upload proof of delivery
                        </button>
                      </>
                    )}
                  </div>

                  <button
                    type="button"
                    onClick={() => setSelectedDelivery(delivery)}
                    className="text-xs px-3 py-1 rounded-full border text-muted-foreground hover:bg-muted transition-colors"
                  >
                    View details
                  </button>
                </div>
              </motion.div>
            ))
          )}
        </motion.div>
      </AnimatePresence>

      {/* Details Modal */}
      {selectedDelivery && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-card border rounded-2xl max-w-lg w-full mx-4 p-6 shadow-lg">
            <div className="flex items-start justify-between mb-4">
              <div>
                <p className="text-xs text-muted-foreground uppercase tracking-wide mb-1">Delivery Details</p>
                <h2 className="font-semibold text-lg">{riderDeliveryLabel(selectedDelivery)}</h2>
                <p className="text-xs text-muted-foreground">Order #{selectedDelivery.orderId}</p>
              </div>
              <button
                type="button"
                className="text-xs text-muted-foreground hover:text-foreground"
                onClick={() => setSelectedDelivery(null)}
              >
                Close
              </button>
            </div>

            {(selectedDelivery.buyer || selectedDelivery.store) && (
              <div className="mb-4 text-sm flex items-start justify-between gap-3">
                <div>
                  {selectedDelivery.buyer && (
                    <>
                      <p className="font-medium">Buyer</p>
                      <p>{selectedDelivery.buyer.name || selectedDelivery.buyer.email}</p>
                      {selectedDelivery.buyer.contact && (
                        <p className="text-muted-foreground text-xs">Contact: {selectedDelivery.buyer.contact}</p>
                      )}
                    </>
                  )}
                  <p className="text-muted-foreground text-xs mt-1">
                    <span className="font-medium">Shop:</span> {selectedDelivery.store?.name || "Unknown shop"}
                  </p>
                </div>
                <div className="flex flex-col gap-2 shrink-0">
                  {selectedDelivery.store?.id != null && (
                    <button
                      type="button"
                      disabled={isBusy(`rider-delivery-${selectedDelivery.id}`)}
                      onClick={async () => {
                        const storeId = Number(selectedDelivery.store?.id)
                        const ok = await openRiderToSeller(
                          `rider-delivery-${selectedDelivery.id}`,
                          storeId,
                          selectedDelivery.orderId ?? undefined,
                        )
                        if (ok) setSelectedDelivery(null)
                      }}
                      className="text-xs px-3 py-1 rounded-full border hover:bg-muted transition-colors disabled:opacity-60 disabled:pointer-events-none inline-flex items-center gap-1.5"
                    >
                      {isBusy(`rider-delivery-${selectedDelivery.id}`) ? (
                        <>
                          <span className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
                          Opening…
                        </>
                      ) : (
                        "Message seller"
                      )}
                    </button>
                  )}
                  {selectedDelivery.buyer?.contact && (
                    <button
                      type="button"
                      onClick={() => window.open(`tel:${selectedDelivery.buyer?.contact}`, "_self")}
                      className="text-xs px-3 py-1 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                    >
                      Call
                    </button>
                  )}
                  {selectedDelivery.store?.id != null && selectedDelivery.orderId != null && (
                    <ReportLinkButton
                      reporterRole="rider"
                      params={{
                        targetRole: "seller",
                        storeId: selectedDelivery.store.id,
                        orderId: selectedDelivery.orderId,
                        label: selectedDelivery.store.name ?? undefined,
                      }}
                    >
                      Report seller
                    </ReportLinkButton>
                  )}
                  {selectedDelivery.buyer?.id != null && selectedDelivery.orderId != null && (
                    <ReportLinkButton
                      reporterRole="rider"
                      params={{
                        targetRole: "buyer",
                        targetUserId: selectedDelivery.buyer.id,
                        orderId: selectedDelivery.orderId,
                        label: selectedDelivery.buyer.name ?? undefined,
                      }}
                    >
                      Report buyer
                    </ReportLinkButton>
                  )}
                </div>
              </div>
            )}

            <div className="mb-4">
              <p className="font-medium text-sm mb-1">Items</p>
              {selectedDelivery.items && selectedDelivery.items.length > 0 ? (
                <ul className="space-y-1 text-sm max-h-40 overflow-auto">
                  {selectedDelivery.items.map((item) => (
                    <li key={item.id} className="flex justify-between">
                      <span>{item.name || "Item"}</span>
                      <span className="text-muted-foreground">x{item.quantity}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-xs text-muted-foreground">No item details available.</p>
              )}
            </div>

            <div>
              <p className="font-medium text-sm mb-1">Notes</p>
              <p className="text-xs text-muted-foreground">
                {selectedDelivery.deliveryNotes?.trim()
                  ? selectedDelivery.deliveryNotes
                  : "Pickup from seller store and deliver to the dropoff location shown on the card."}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Proof of Delivery / Confirm Delivered Modal */}
      {deliveryToMarkDelivered && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-card border rounded-2xl max-w-md w-full mx-4 p-6 shadow-lg">
            <div className="mb-4">
              <p className="text-xs text-muted-foreground uppercase tracking-wide mb-1">Proof of delivery</p>
              <h2 className="font-semibold text-lg">Upload proof of delivery</h2>
            </div>

            <div className="text-sm text-muted-foreground mb-4 space-y-2">
              <p>
                Attach a clear photo as proof of delivery for
                <span className="font-medium"> {riderDeliveryLabel(deliveryToMarkDelivered)}</span>.
                Take a new photo or upload one saved on your device (helpful when signal is weak).
              </p>
              <p>
                Submitting proof will mark this delivery as completed.
              </p>
            </div>

            <div className="space-y-3 mb-4">
              <div>
                <p className="text-xs font-medium mb-1">Photo (required)</p>
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => {
                    const file = e.target.files?.[0] ?? null
                    setProofPhoto(file)
                  }}
                  className="block w-full text-xs file:mr-3 file:py-1.5 file:px-3 file:rounded-full file:border-0 file:text-xs file:font-medium file:bg-primary file:text-primary-foreground hover:file:bg-primary/90"
                />
                {proofPhoto ? (
                  <p className="mt-1 text-[10px] text-green-700 font-medium">Photo selected: {proofPhoto.name}</p>
                ) : (
                  <p className="mt-1 text-[10px] text-red-500">A clear delivery photo is required.</p>
                )}
              </div>
              <div>
                <p className="text-xs font-medium mb-1">Notes (optional)</p>
                <textarea
                  value={proofNote}
                  onChange={(e) => setProofNote(e.target.value)}
                  rows={3}
                  className="w-full text-xs rounded-xl border bg-background px-3 py-2 resize-none focus:outline-none focus:ring-1 focus:ring-primary/60"
                  placeholder="Example: Received by guard at lobby, ID checked."
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 mt-4">
              <button
                type="button"
                className="text-xs px-3 py-1 rounded-full border text-muted-foreground hover:bg-muted transition-colors"
                onClick={handleCloseProofModal}
              >
                Cancel
              </button>
              <button
                type="button"
                className="text-xs px-3 py-1 rounded-full bg-green-600 text-white hover:bg-green-700 transition-colors disabled:opacity-70 disabled:cursor-not-allowed"
                onClick={handleSaveProof}
                disabled={isSubmittingProof}
              >
                {isSubmittingProof ? "Saving..." : "Save proof"}
              </button>
            </div>
          </div>
        </div>
      )}

      {toastMessage && (
        <div className="fixed bottom-4 right-4 z-50">
          <div className="px-3 py-2 rounded-lg bg-emerald-600 text-xs text-white shadow-lg flex items-center gap-2">
            <Icon name="check" size="sm" />
            <span>{toastMessage}</span>
            <button
              type="button"
              onClick={() => setToastMessage(null)}
              className="ml-1 text-white/80 hover:text-white"
            >
              ×
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
