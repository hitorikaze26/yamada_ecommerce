"use client"

import { useEffect, useState } from "react"
import type React from "react"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"
import { AddressSelector } from "@/components/form/address-selector"
import {
  addressesApi,
  buyerApi,
  type AddressData,
  type SavedAddressDto,
  isAddressComplete,
} from "@/lib/api"

export default function AddressesPage() {
  const [addresses, setAddresses] = useState<SavedAddressDto[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<SavedAddressDto | null>(null)
  const [label, setLabel] = useState("Home")
  const [addressData, setAddressData] = useState<AddressData | null>(null)
  const [saving, setSaving] = useState(false)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const loadAddresses = async () => {
    setIsLoading(true)
    setError(null)
    try {
      const res = await addressesApi.list()
      let list = (res.data.addresses ?? []) as SavedAddressDto[]
      if (list.length === 0) {
        const profileRes = await buyerApi.getProfile()
        const profile = profileRes.data?.profile ?? profileRes.data
        const addr = profile?.address
        if (addr?.regionName) {
          list = [
            {
              id: "profile",
              label: "Home",
              regionCode: addr.regionCode ?? "",
              regionName: addr.regionName ?? "",
              provinceCode: addr.provinceCode,
              provinceName: addr.provinceName,
              municipalityCode: addr.municipalityCode ?? "",
              municipalityName: addr.municipalityName ?? "",
              barangayCode: addr.barangayCode ?? "",
              barangayName: addr.barangayName ?? "",
              streetAddress: addr.streetAddress,
              postalCode: addr.postalCode,
              isDefault: true,
            },
          ]
        }
      }
      setAddresses(list)
    } catch (err) {
      console.error("Failed to load addresses", err)
      setError("Failed to load addresses. Please try again.")
    } finally {
      setIsLoading(false)
    }
  }

  useEffect(() => {
    void loadAddresses()
  }, [])

  const openAdd = () => {
    setEditing(null)
    setLabel("Home")
    setAddressData(null)
    setShowForm(true)
  }

  const openEdit = (addr: SavedAddressDto) => {
    setEditing(addr)
    setLabel(addr.label)
    setAddressData({
      regionCode: addr.regionCode,
      regionName: addr.regionName,
      provinceCode: addr.provinceCode,
      provinceName: addr.provinceName,
      municipalityCode: addr.municipalityCode,
      municipalityName: addr.municipalityName,
      barangayCode: addr.barangayCode,
      barangayName: addr.barangayName,
      streetAddress: addr.streetAddress,
      postalCode: addr.postalCode,
    })
    setShowForm(true)
  }

  const handleDelete = async (id: string) => {
    if (id === "profile") {
      showAlert("This address comes from your profile. Update it under Profile or Settings.", "info")
      return
    }
    try {
      await addressesApi.delete(id)
      await loadAddresses()
      showAlert("Address removed.", "success")
    } catch (err) {
      console.error(err)
      showAlert("Failed to delete address.", "error")
    }
  }

  const handleSetDefault = async (id: string) => {
    if (id === "profile") return
    try {
      await addressesApi.setDefault(id)
      await loadAddresses()
      showAlert("Default address updated.", "success")
    } catch (err) {
      showAlert("Failed to set default address.", "error")
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!addressData || !isAddressComplete(addressData)) {
      showAlert("Please complete the address fields.", "warning")
      return
    }
    setSaving(true)
    try {
      const payload = {
        label,
        ...addressData,
        isDefault: addresses.length === 0,
      }
      if (editing && editing.id !== "profile") {
        await addressesApi.update(editing.id, payload)
        showAlert("Address updated.", "success")
      } else if (!editing || editing.id === "profile") {
        await addressesApi.create(payload as Omit<SavedAddressDto, "id">)
        showAlert("Address added.", "success")
      }
      setShowForm(false)
      await loadAddresses()
    } catch (err) {
      console.error(err)
      showAlert("Failed to save address.", "error")
    } finally {
      setSaving(false)
    }
  }

  const formatLine = (a: SavedAddressDto) => {
    const parts = [
      a.streetAddress,
      a.barangayName,
      a.municipalityName,
      a.provinceName,
      a.regionName,
    ].filter(Boolean)
    return parts.join(", ")
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
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-3xl font-bold mb-2">My Addresses</h1>
          <p className="text-muted-foreground">Manage shipping addresses for checkout.</p>
        </div>
        <button
          type="button"
          onClick={openAdd}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
        >
          <Icon name="plus" />
          Add Address
        </button>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading addresses...</div>}
      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border rounded-2xl p-4 text-sm">{error}</div>
      )}

      {!isLoading && !error && addresses.length === 0 && (
        <div className="bg-card border rounded-2xl p-8 text-center text-muted-foreground">
          No saved addresses yet.
        </div>
      )}

      <div className="grid gap-4">
        {addresses.map((addr) => (
          <div key={addr.id} className="bg-card border rounded-2xl p-5 flex flex-col sm:flex-row sm:items-start gap-4">
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-1">
                <span className="font-semibold">{addr.label}</span>
                {addr.isDefault && (
                  <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary">Default</span>
                )}
              </div>
              <p className="text-sm text-muted-foreground">{formatLine(addr)}</p>
            </div>
            <div className="flex flex-wrap gap-2">
              {!addr.isDefault && addr.id !== "profile" && (
                <button
                  type="button"
                  onClick={() => void handleSetDefault(addr.id)}
                  className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
                >
                  Set default
                </button>
              )}
              <button
                type="button"
                onClick={() => openEdit(addr)}
                className="text-sm px-3 py-1.5 rounded-lg border hover:bg-muted"
              >
                Edit
              </button>
              {addr.id !== "profile" && (
                <button
                  type="button"
                  onClick={() => void handleDelete(addr.id)}
                  className="text-sm px-3 py-1.5 rounded-lg border text-destructive hover:bg-destructive/10"
                >
                  Delete
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      <AnimatePresence>
        {showForm && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
            onClick={() => setShowForm(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              className="bg-background rounded-2xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold">{editing ? "Edit Address" : "Add Address"}</h2>
                <button type="button" onClick={() => setShowForm(false)} className="w-10 h-10 rounded-full hover:bg-muted flex items-center justify-center">
                  <Icon name="times" />
                </button>
              </div>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Label</label>
                  <input
                    type="text"
                    value={label}
                    onChange={(e) => setLabel(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl border bg-background outline-none focus:ring-2 focus:ring-primary"
                    required
                  />
                </div>
                <AddressSelector value={addressData} onChange={setAddressData} />
                <div className="flex gap-3 pt-4">
                  <button type="button" onClick={() => setShowForm(false)} className="flex-1 py-3 border rounded-xl font-medium hover:bg-muted">
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={saving}
                    className="flex-1 py-3 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 disabled:opacity-60"
                  >
                    {saving ? "Saving..." : "Save"}
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
