"use client"
import { useEffect, useRef, useState } from "react"
import type React from "react"

import Image from "next/image"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert" 
import { useAuth } from "@/context/auth-context"
import { riderAccountApi, API_BASE_ORIGIN } from "@/lib/api"
import { Button } from "@/components/ui/button"

interface RiderProfileDto {
  givenName: string
  surname: string
  email: string
  contactNumber: string
  isVerified: boolean
  avatarUrl?: string | null
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
  documents: {
    license?: string | null
    orCr?: string | null
  }
}

export default function RiderProfilePage() {
  const { user, isVerified: isGloballyVerified } = useAuth()
  const [isEditing, setIsEditing] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [profile, setProfile] = useState<RiderProfileDto | null>(null)
  const [formData, setFormData] = useState({
    firstName: "",
    lastName: "",
    email: user?.email || "",
    phone: "",
    vehicleType: "",
    licenseNumber: "",
  })
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const licenseInputRef = useRef<HTMLInputElement | null>(null)
  const orCrInputRef = useRef<HTMLInputElement | null>(null)
  const [uploadingLicense, setUploadingLicense] = useState(false)
  const [uploadingOrCr, setUploadingOrCr] = useState(false)

  useEffect(() => {
    const fetchProfile = async () => {
      setIsLoading(true)
      setError(null)
      try {
        const res = await riderAccountApi.getProfile()
        const rider = (res.data as any).profile as any

        const riderProfile: RiderProfileDto = {
          givenName: rider.givenName,
          surname: rider.surname,
          email: rider.email,
          contactNumber: rider.contactNumber,
          isVerified: true,
          avatarUrl: rider.avatarUrl || null,
          address: rider.address,
          documents: {
            license: rider.documents?.license || rider.documents?.licensePath || null,
            orCr: rider.documents?.orCr || rider.documents?.orCrPath || null,
          },
        }

        setProfile(riderProfile)
        setFormData({
          firstName: riderProfile.givenName,
          lastName: riderProfile.surname,
          email: riderProfile.email,
          phone: riderProfile.contactNumber,
          vehicleType: rider.vehicleType || "",
          licenseNumber: rider.licenseNumber || "",
        })
      } catch (err) {
        console.error("Failed to load rider profile", err)
        setError("Failed to load rider profile. Please try again.")
      } finally {
        setIsLoading(false)
      }
    }

    void fetchProfile()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!isApproved) {
      return
    }

    try {
      const payload = {
        givenName: formData.firstName,
        surname: formData.lastName,
        email: formData.email,
        contactNumber: formData.phone,
        vehicleType: formData.vehicleType,
        licenseNumber: formData.licenseNumber,
      }

      const res = await riderAccountApi.updateProfile(payload)
      const updated = (res.data as any).profile as any

      const updatedProfile: RiderProfileDto = {
        givenName: updated.givenName,
        surname: updated.surname,
        email: updated.email,
        contactNumber: updated.contactNumber,
        isVerified: !!updated.isVerified,
        avatarUrl: updated.avatarUrl || profile?.avatarUrl || null,
        address: updated.address,
        documents: {
          license: updated.documents?.license || null,
          orCr: updated.documents?.orCr || null,
        },
      }

      setProfile(updatedProfile)
      setFormData({
        firstName: updatedProfile.givenName,
        lastName: updatedProfile.surname,
        email: updatedProfile.email,
        phone: updatedProfile.contactNumber,
        vehicleType: updated.vehicleType || "",
        licenseNumber: updated.licenseNumber || "",
      })

      setIsEditing(false)
      setAlertMessage("Profile changes saved.")
      setAlertVariant("success")
      setAlertOpen(true)
    } catch (err) {
      console.error("Failed to update rider profile", err)
      setAlertMessage("Failed to save profile changes. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    }
  }

  const handleLicenseUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setUploadingLicense(true)
    try {
      await riderAccountApi.uploadRiderDocuments({ license: file })
      const res = await riderAccountApi.getProfile()
      const rider = (res.data as any).profile as any
      if (profile) {
        setProfile({
          ...profile,
          documents: {
            license: rider.documents?.license || rider.documents?.licensePath || profile.documents.license,
            orCr: rider.documents?.orCr || rider.documents?.orCrPath || profile.documents.orCr,
          },
        })
      }
      setAlertMessage("License updated successfully.")
      setAlertVariant("success")
      setAlertOpen(true)
    } catch {
      setAlertMessage("Failed to upload license. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    } finally {
      setUploadingLicense(false)
      if (licenseInputRef.current) licenseInputRef.current.value = ""
    }
  }

  const handleOrCrUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setUploadingOrCr(true)
    try {
      await riderAccountApi.uploadRiderDocuments({ orCr: file })
      const res = await riderAccountApi.getProfile()
      const rider = (res.data as any).profile as any
      if (profile) {
        setProfile({
          ...profile,
          documents: {
            license: rider.documents?.license || rider.documents?.licensePath || profile.documents.license,
            orCr: rider.documents?.orCr || rider.documents?.orCrPath || profile.documents.orCr,
          },
        })
      }
      setAlertMessage("OR/CR updated successfully.")
      setAlertVariant("success")
      setAlertOpen(true)
    } catch {
      setAlertMessage("Failed to upload OR/CR. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    } finally {
      setUploadingOrCr(false)
      if (orCrInputRef.current) orCrInputRef.current.value = ""
    }
  }

  const isApproved = isGloballyVerified()

  const handleAvatarClick = () => {
    fileInputRef.current?.click()
  }

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    try {
      const res = await riderAccountApi.uploadAvatar(file)
      const newUrl = (res.data as any).avatarUrl as string | undefined
      if (newUrl && profile) {
        setProfile({
          ...profile,
          avatarUrl: newUrl,
        })
        setAlertMessage("Profile photo updated.")
        setAlertVariant("success")
        setAlertOpen(true)
      }
    } catch (err) {
      console.error("Failed to upload rider avatar", err)
      setAlertMessage("Failed to upload profile photo. Please try again.")
      setAlertVariant("error")
      setAlertOpen(true)
    } finally {
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
        <p className="text-muted-foreground">Manage your rider account information.</p>
      </div>

      {!isApproved && (
        <div className="bg-amber-50 border border-amber-200 text-amber-900 rounded-2xl p-4 text-sm">
          <p className="font-semibold mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. You can log in, but deliveries and profile changes will be
            available only after an admin approves your account.
          </p>
        </div>
      )}

      <div className="bg-card border rounded-2xl p-6">
        {isLoading && <div className="mb-4 text-sm text-muted-foreground">Loading profile...</div>}
        {error && !isLoading && (
          <div className="mb-4 p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
            <Icon name="exclamation-circle" />
            {error}
          </div>
        )}

        {/* Profile header */}
        <div className="flex flex-col sm:flex-row items-center gap-6 mb-8 pb-8 border-b">
          <div className="relative">
            <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center overflow-hidden">
              <Image
                src={profile?.avatarUrl || "/woman-portrait.png"}
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
              disabled={!isApproved}
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
              {formData.firstName || "Rider"} {formData.lastName}
            </h2>
            <p className="text-muted-foreground">{formData.email}</p>
            <div className="mt-2 inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium border">
              <span
                className={
                  isApproved ? "text-green-600 dark:text-green-400" : "text-amber-600 dark:text-amber-400"
                }
              >
                {isApproved ? "Verified rider" : "Pending admin verification"}
              </span>
            </div>
          </div>
        </div>

        {/* Profile form (read-only for now) */}
        <form onSubmit={handleSubmit}>
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold">Personal Information</h3>
            {!isEditing && (
              <button
                type="button"
                onClick={() => setIsEditing(true)}
                className="flex items-center gap-2 text-primary hover:underline"
                disabled={!isApproved}
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
                disabled={!isEditing || !isApproved}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Last Name</label>
              <input
                type="text"
                value={formData.lastName}
                onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
                disabled={!isEditing || !isApproved}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Email</label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                disabled
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Phone</label>
              <input
                type="tel"
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                disabled={!isEditing || !isApproved}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              />
            </div>
          </div>

          <h3 className="text-lg font-semibold mt-8 mb-4">Vehicle Information</h3>

          <div className="grid sm:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium mb-2">Vehicle Type</label>
              <select
                value={formData.vehicleType}
                onChange={(e) => setFormData({ ...formData, vehicleType: e.target.value })}
                disabled={!isEditing || !isApproved}
                className="w-full px-4 py-3 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none disabled:opacity-60 disabled:cursor-not-allowed"
              >
                <option value="">Select vehicle type</option>
                <option value="bicycle">Bicycle</option>
                <option value="motorcycle">Motorcycle</option>
                <option value="car">Car</option>
                <option value="suv">SUV</option>
                <option value="truck">Truck</option>
                <option value="van">Van</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">License Number</label>
              <input
                type="text"
                value={formData.licenseNumber}
                onChange={(e) => setFormData({ ...formData, licenseNumber: e.target.value })}
                disabled={!isEditing || !isApproved}
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
                disabled={!isApproved}
              >
                Save Changes
              </button>
            </motion.div>
          )}
        </form>
      </div>

      {/* Address */}
      {profile?.address && (
        <div className="bg-card border rounded-2xl p-6">
          <h3 className="text-lg font-semibold mb-6">Address Information</h3>
          <div className="grid sm:grid-cols-2 gap-6">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Region</p>
              <p className="text-sm">{profile.address.regionName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Province</p>
              <p className="text-sm">{profile.address.provinceName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">City / Municipality</p>
              <p className="text-sm">{profile.address.municipalityName}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Barangay</p>
              <p className="text-sm">{profile.address.barangayName}</p>
            </div>
            <div className="sm:col-span-2">
              <p className="text-sm font-medium text-muted-foreground">Street Address</p>
              <p className="text-sm">{profile.address.streetAddress || "Not provided"}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Postal Code</p>
              <p className="text-sm">{profile.address.postalCode || "Not provided"}</p>
            </div>
          </div>
        </div>
      )}

      {/* Documents */}
      {profile && (
        <div className="bg-card border rounded-2xl p-6">
          <h3 className="text-lg font-semibold mb-4">Documents</h3>
          <div className="space-y-4 text-sm">
            <div className="flex items-center justify-between py-3 border-b">
              <div className="flex items-center gap-3">
                <Icon name="id-card" className="text-primary" />
                <div>
                  <p className="font-medium">Driver&apos;s License</p>
                  <p className="text-xs text-muted-foreground">Uploaded during registration</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {profile.documents.license ? (
                  <a
                    href={profile.documents.license.startsWith("http")
                      ? profile.documents.license
                      : `${API_BASE_ORIGIN}/${profile.documents.license.replace(/^\//, "")}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-primary underline text-xs font-medium"
                  >
                    View
                  </a>
                ) : (
                  <span className="text-xs text-muted-foreground">No file</span>
                )}
                {isApproved && (
                  <>
                    <input
                      ref={licenseInputRef}
                      type="file"
                      accept="image/*,.pdf"
                      className="hidden"
                      onChange={handleLicenseUpload}
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => licenseInputRef.current?.click()}
                      disabled={uploadingLicense}
                    >
                      {uploadingLicense ? "Uploading..." : "Re-upload"}
                    </Button>
                  </>
                )}
              </div>
            </div>

            <div className="flex items-center justify-between py-3">
              <div className="flex items-center gap-3">
                <Icon name="file-alt" className="text-primary" />
                <div>
                  <p className="font-medium">OR/CR</p>
                  <p className="text-xs text-muted-foreground">Vehicle registration document</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {profile.documents.orCr ? (
                  <a
                    href={profile.documents.orCr.startsWith("http")
                      ? profile.documents.orCr
                      : `${API_BASE_ORIGIN}/${profile.documents.orCr.replace(/^\//, "")}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-primary underline text-xs font-medium"
                  >
                    View
                  </a>
                ) : (
                  <span className="text-xs text-muted-foreground">No file</span>
                )}
                {isApproved && (
                  <>
                    <input
                      ref={orCrInputRef}
                      type="file"
                      accept="image/*,.pdf"
                      className="hidden"
                      onChange={handleOrCrUpload}
                    />
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => orCrInputRef.current?.click()}
                      disabled={uploadingOrCr}
                    >
                      {uploadingOrCr ? "Uploading..." : "Re-upload"}
                    </Button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
