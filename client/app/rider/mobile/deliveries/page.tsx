"use client"

import { useEffect, useState, useMemo } from "react"
import { riderApi } from "@/lib/api"
import { riderDeliveryEntityId, riderDeliveryLabel } from "@/lib/rider-delivery"
import { useAuth } from "@/context/auth-context"

const kPrimaryPink = "#E891A0"
const tabs = ["active", "completed", "all"]

interface RiderDelivery {
  id: number
  deliveryId?: number | null
  displayLabel?: string | null
  orderId: number | null
  status: string
  fee: number
  distanceKm: number
  shippingAddress?: string | null
  municipalityName?: string | null
  store?: { name?: string | null }
  buyer?: { name?: string | null; email?: string | null; contact?: string | null }
  isAutoMatched?: boolean
  proofPhotoUrl?: string | null
  proofNote?: string | null
}

export default function RiderMobileDeliveries() {
  const { isVerified } = useAuth()
  const [activeTab, setActiveTab] = useState("active")
  const [deliveries, setDeliveries] = useState<RiderDelivery[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [deliveryForProof, setDeliveryForProof] = useState<RiderDelivery | null>(null)
  const [proofNote, setProofNote] = useState("")
  const [proofPhoto, setProofPhoto] = useState<File | null>(null)
  const [isSubmittingProof, setIsSubmittingProof] = useState(false)
  const [deliveriesForbidden, setDeliveriesForbidden] = useState(false)

  const reloadDeliveries = async () => {
    setIsLoading(true)
    setDeliveriesForbidden(false)
    try {
      const res = await riderApi.getDeliveries()
      const data = (res.data as any)?.deliveries as RiderDelivery[] | undefined
      setDeliveries(data || [])
    } catch (e: unknown) {
      const status = (e as { response?: { status?: number } })?.response?.status
      if (status === 403) setDeliveriesForbidden(true)
      setDeliveries([])
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void reloadDeliveries()
  }, [])

  const filteredDeliveries = useMemo(() => {
    return deliveries.filter((d) => {
      if (activeTab === "active" && !["pickup", "transit", "pending"].includes(d.status)) return false
      if (activeTab === "completed" && d.status !== "delivered") return false
      return true
    })
  }, [deliveries, activeTab])

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat("en-PH", { style: "currency", currency: "PHP" }).format(price)
  }

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "pending":
        return "bg-amber-100 text-amber-700"
      case "pickup":
        return "bg-blue-100 text-blue-700"
      case "transit":
        return "bg-purple-100 text-purple-700"
      case "delivered":
        return "bg-green-100 text-green-700"
      default:
        return "bg-gray-100 text-gray-700"
    }
  }

  const getStatusLabel = (status: string) => {
    switch (status.toLowerCase()) {
      case "pickup":
        return "Ready for Pickup"
      case "transit":
        return "In Transit"
      case "pending":
        return "Shipped"
      case "delivered":
        return "Delivered"
      default:
        return status
    }
  }

  const formatAddress = (shippingAddress?: string | null, municipalityName?: string | null) => {
    if (!shippingAddress && !municipalityName) return "Customer address"
    if (municipalityName && shippingAddress) return `${municipalityName} — ${shippingAddress}`
    return municipalityName || shippingAddress || "Customer address"
  }

  const handleAcceptDelivery = async (delivery: RiderDelivery) => {
    if (!delivery.isAutoMatched || !delivery.orderId) return
    try {
      await riderApi.acceptDelivery(delivery.orderId)
      await reloadDeliveries()
    } catch {
      // Handle error
    }
  }

  const handleUpdateStatus = async (delivery: RiderDelivery, newStatus: string) => {
    if (delivery.isAutoMatched) return
    try {
      await riderApi.updateDeliveryStatus(riderDeliveryEntityId(delivery), newStatus)
      setDeliveries((prev) => prev.map((d) => (d.id === delivery.id ? { ...d, status: newStatus } : d)))
    } catch {
      // Handle error
    }
  }

  const handleCloseProofModal = () => {
    setDeliveryForProof(null)
    setProofNote("")
    setProofPhoto(null)
    setIsSubmittingProof(false)
  }

  const handleSaveProof = async () => {
    if (!deliveryForProof) return
    if (!proofPhoto) return
    try {
      setIsSubmittingProof(true)
      await riderApi.uploadDeliveryProof(riderDeliveryEntityId(deliveryForProof), {
        note: proofNote,
        photo: proofPhoto,
      })
      await reloadDeliveries()
      handleCloseProofModal()
    } catch {
      // ignore
    } finally {
      setIsSubmittingProof(false)
    }
  }

  return (
    <div className="p-4 space-y-4">
      {(deliveriesForbidden || !isVerified()) && (
        <div className="rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-900">
          Your rider account is awaiting approval. Deliveries will appear once you are verified.
        </div>
      )}

      <div>
        <h1 className="text-xl font-bold">Deliveries</h1>
        <p className="text-sm text-gray-500">Manage your delivery assignments</p>
      </div>

      {!isVerified() && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="font-semibold text-amber-900 mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. Deliveries will appear here once an admin approves your account.
          </p>
        </div>
      )}

      <div className="flex gap-2">
        {tabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2 px-4 rounded-xl text-sm font-medium capitalize transition-colors ${
              activeTab === tab
                ? "text-white"
                : "bg-gray-100 text-gray-600 hover:bg-gray-200"
            }`}
            style={{ backgroundColor: activeTab === tab ? kPrimaryPink : undefined }}
          >
            {tab}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-8">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2" style={{ borderColor: kPrimaryPink }} />
        </div>
      ) : filteredDeliveries.length === 0 ? (
        <div className="bg-white rounded-xl p-8 text-center shadow-sm">
          <svg className="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0" />
          </svg>
          <h3 className="font-semibold mb-2">No deliveries</h3>
          <p className="text-sm text-gray-500">No {activeTab} deliveries at the moment.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredDeliveries.map((delivery) => {
            const dropoffComplete = delivery.status === "delivered"
            return (
              <div key={delivery.id} className="bg-white rounded-xl p-4 shadow-sm">
                <div className="flex items-start justify-between mb-3">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-semibold">{riderDeliveryLabel(delivery)}</span>
                      <span className={`text-xs px-2 py-1 rounded-full ${getStatusColor(delivery.status)}`}>
                        {getStatusLabel(delivery.status)}
                      </span>
                    </div>
                    <p className="text-xs text-gray-500">Order #{delivery.orderId}</p>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-lg" style={{ color: kPrimaryPink }}>
                      {formatPrice(delivery.fee)}
                    </p>
                    {delivery.distanceKm > 0 && (
                      <p className="text-xs text-gray-500">{delivery.distanceKm.toFixed(1)} km</p>
                    )}
                  </div>
                </div>

                <div className="space-y-3 mb-4">
                  <div className="flex items-start gap-3">
                    <div
                      className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0"
                      style={{ backgroundColor: `${kPrimaryPink}20` }}
                    >
                      <svg className="w-5 h-5" style={{ color: kPrimaryPink }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                      </svg>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Pickup</p>
                      <p className="text-sm font-medium">{delivery.store?.name || "Store location"}</p>
                    </div>
                  </div>
                  <div
                    className={`flex items-start gap-3 p-2 rounded-lg ${
                      dropoffComplete ? "bg-green-50" : "bg-purple-50"
                    }`}
                  >
                    <div
                      className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
                        dropoffComplete ? "bg-green-100" : "bg-purple-100"
                      }`}
                    >
                      <svg
                        className={`w-5 h-5 ${dropoffComplete ? "text-green-600" : "text-purple-600"}`}
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Dropoff</p>
                      <p className="text-sm font-medium">{formatAddress(delivery.shippingAddress, delivery.municipalityName)}</p>
                      {delivery.buyer?.contact && (
                        <p className="text-xs text-gray-500 mt-1">Contact: {delivery.buyer.contact}</p>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex flex-wrap gap-2">
                  {delivery.isAutoMatched && (
                    <button
                      onClick={() => handleAcceptDelivery(delivery)}
                      className="flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white"
                      style={{ backgroundColor: "#d97706" }}
                    >
                      Accept delivery
                    </button>
                  )}
                  {!delivery.isAutoMatched && delivery.status === "pending" && (
                    <button
                      onClick={() => handleUpdateStatus(delivery, "pickup")}
                      className="flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white"
                      style={{ backgroundColor: kPrimaryPink }}
                    >
                      Start pickup
                    </button>
                  )}
                  {!delivery.isAutoMatched && delivery.status === "pickup" && (
                    <button
                      onClick={() => handleUpdateStatus(delivery, "transit")}
                      className="flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white bg-blue-500"
                    >
                      On the way
                    </button>
                  )}
                  {!delivery.isAutoMatched && delivery.status === "transit" && (
                    <>
                      {delivery.buyer?.contact && (
                        <a
                          href={`tel:${delivery.buyer.contact}`}
                          className="flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white bg-blue-500 text-center"
                        >
                          Call
                        </a>
                      )}
                      <button
                        onClick={() => {
                          setDeliveryForProof(delivery)
                          setProofNote("")
                          setProofPhoto(null)
                        }}
                        className="flex-1 py-2 px-4 rounded-xl text-sm font-medium text-white bg-blue-600"
                      >
                        Upload proof of delivery
                      </button>
                    </>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {deliveryForProof && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md p-5 shadow-lg">
            <h2 className="font-semibold text-lg mb-1">Upload proof of delivery</h2>
            <p className="text-xs text-gray-500 mb-4">
              Take a new photo or choose one from your device. Submitting proof will complete this delivery.
            </p>
            <input
              type="file"
              accept="image/*"
              onChange={(e) => setProofPhoto(e.target.files?.[0] ?? null)}
              className="block w-full text-xs mb-1"
            />
            <p className="text-[10px] text-gray-400 mb-3">
              On your phone, you can pick Camera or Photos/Gallery from the file chooser.
            </p>
            {proofPhoto && (
              <p className="text-xs text-green-700 mb-3 font-medium">Photo selected: {proofPhoto.name}</p>
            )}
            <textarea
              value={proofNote}
              onChange={(e) => setProofNote(e.target.value)}
              rows={2}
              placeholder="Optional note"
              className="w-full text-sm border rounded-xl px-3 py-2 mb-4"
            />
            <div className="flex gap-2">
              <button
                type="button"
                onClick={handleCloseProofModal}
                className="flex-1 py-2 rounded-xl border text-sm"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveProof}
                disabled={!proofPhoto || isSubmittingProof}
                className="flex-1 py-2 rounded-xl text-sm font-medium text-white bg-green-600 disabled:opacity-50"
              >
                {isSubmittingProof ? "Saving..." : "Save proof"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
