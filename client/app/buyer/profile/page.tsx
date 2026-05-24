"use client"
import { useEffect, useRef, useState } from "react"
import type React from "react"

import Image from "next/image"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"
import { useAuth } from "@/context/auth-context"
import { buyerApi } from "@/lib/api"

interface BuyerProfileDto {
  givenName: string
  surname: string
  email: string
  contactNumber: string
  isVerified: boolean
  avatarUrl?: string
  address: {
    regionCode: string
    regionName: string
    provinceCode: string
    provinceName: string
    municipalityCode: string
    municipalityName: string
    barangayCode: string
    barangayName: string
    streetAddress?: string
    postalCode?: string
  }
}

export default function ProfilePage() {
  const { user } = useAuth()
  const [isEditing, setIsEditing] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const [isVerified, setIsVerified] = useState(false)
  const [address, setAddress] = useState<BuyerProfileDto["address"] | null>(null)
  const [formData, setFormData] = useState({
    firstName: "",
    lastName: "",
    email: user?.email || "",
    phone: "",
  })
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  useEffect(() => {
    const fetchProfile = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await buyerApi.getProfile()
        const profile = res.data.profile as BuyerProfileDto

        setFormData({
          firstName: profile.givenName,
          lastName: profile.surname,
          email: profile.email,
          phone: profile.contactNumber,
        })
        setIsVerified(profile.isVerified)
        setAddress(profile.address)
        setAvatarUrl(profile.avatarUrl ?? null)
      } catch (err) {
        console.error("Failed to load profile", err)
        setError("Failed to load profile. Please try again.")
      } finally {
        setIsLoading(false)
      }
    }

    void fetchProfile()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsEditing(false)
    try {
      await buyerApi.updateProfile({
        givenName: formData.firstName,
        surname: formData.lastName,
        contactNumber: formData.phone,
      })
      setAlertMessage("Profile changes saved.")
      setAlertVariant("success")
      setAlertOpen(true)
    } catch (err) {
      console.error("Failed to save profile", err)
      setAlertMessage("Failed to save profile. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    }
  }

  const handleAvatarClick = () => {
    fileInputRef.current?.click()
  }

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    try {
      const res = await buyerApi.uploadAvatar(file)
      const newUrl = (res.data as any).avatarUrl as string | undefined
      if (newUrl) {
        setAvatarUrl(newUrl)
        setAlertMessage("Profile photo updated.")
        setAlertVariant("success")
        setAlertOpen(true)
      }
    } catch (err) {
      console.error("Failed to upload avatar", err)
      setError("Failed to upload profile photo. Please try again.")
      setAlertMessage("Failed to upload profile photo. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    } finally {
      // reset input so same file can be chosen again
      if (fileInputRef.current) {
        fileInputRef.current.value = ""
      }
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
        <h1 className="text-3xl font-bold mb-2">My Profile</h1>
        <p className="text-muted-foreground">Manage your personal information.</p>
      </div>

      <div className="bg-card border rounded-2xl p-6">
        {isLoading && <div className="mb-4 text-sm text-muted-foreground">Loading profile...</div>}
        {error && !isLoading && (
          <div className="mb-4 p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
            <Icon name="exclamation-circle" />
            {error}
          </div>
        )}
        {/* Profile Photo */}
        <div className="flex flex-col sm:flex-row items-center gap-6 mb-8 pb-8 border-b">
          <div className="relative">
            <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center overflow-hidden">
              <Image
                src={avatarUrl || "/woman-portrait.png"}
                alt="Profile"
                width={96}
                height={96}
                className="object-cover"
              />
            </div>
            <button
              type="button"
              onClick={handleAvatarClick}
              className="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center shadow-lg cursor-pointer"
            >
              <Icon name="camera" size="sm" />
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleAvatarChange}
            />
          </div>
          <div className="text-center sm:text-left">
            <h2 className="text-xl font-semibold">
              {formData.firstName} {formData.lastName}
            </h2>
            <p className="text-muted-foreground">{formData.email}</p>
            <div className="mt-2 inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium border">
              <span
                className={
                  isVerified
                    ? "text-green-600 dark:text-green-400"
                    : "text-amber-600 dark:text-amber-400"
                }
              >
                {isVerified ? "Verified account" : "Pending admin verification"}
              </span>
            </div>
          </div>
        </div>

        {/* Profile Form */}
        <form onSubmit={handleSubmit}>
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold">Personal Information</h3>
            {!isEditing && (
              <button
                type="button"
                onClick={() => setIsEditing(true)}
                className="flex items-center gap-2 text-primary hover:underline"
              >
                <Icon name="edit" size="sm" />
                Edit
              </button>
            )}
          </div>

          <div className="grid sm:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium mb-2">First Name</label>
              <input
                type="text"
                value={formData.firstName}
                onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
                disabled={!isEditing}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Last Name</label>
              <input
                type="text"
                value={formData.lastName}
                onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                disabled={!isEditing}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Email</label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                disabled={!isEditing}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Phone</label>
              <input
                type="tel"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                disabled={!isEditing}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
          </div>

          {isEditing && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex gap-3 mt-6 pt-6 border-t"
            >
              <button
                type="button"
                onClick={() => setIsEditing(false)}
                className="flex-1 py-3 px-4 border rounded-xl font-medium hover:bg-muted transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="flex-1 py-3 px-4 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 transition-colors"
              >
                Save Changes
              </button>
            </motion.div>
          )}
        </form>
      </div>

      {/* Address Information */}
      {address && (
        <div className="bg-card border rounded-2xl p-6">
          <h3 className="text-lg font-semibold mb-6">Address Information</h3>
          <div className="grid sm:grid-cols-2 gap-6">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Region</p>
              <p className="text-sm">{address.regionName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Province</p>
              <p className="text-sm">{address.provinceName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">City / Municipality</p>
              <p className="text-sm">{address.municipalityName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Barangay</p>
              <p className="text-sm">{address.barangayName}</p>
            </div>
            <div className="sm:col-span-2">
              <p className="text-sm font-medium text-muted-foreground">Street Address</p>
              <p className="text-sm">{address.streetAddress || "Not provided"}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Postal Code</p>
              <p className="text-sm">{address.postalCode || "Not provided"}</p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
