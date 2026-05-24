"use client"

import Link from "next/link"
import { useEffect, useState, useRef } from "react"
import { riderAccountApi, API_BASE_ORIGIN } from "@/lib/api"
import { useAuth } from "@/context/auth-context"
import Image from "next/image"

const kPrimaryPink = "#E891A0"

interface RiderProfile {
  givenName: string
  surname: string
  email: string
  contactNumber: string
  vehicleType?: string
  licenseNumber?: string
  avatarUrl?: string | null
  address: {
    regionName: string
    provinceName: string
    municipalityName: string
    barangayName: string
    streetAddress?: string
    postalCode?: string
  }
  documents: {
    license?: string | null
    orCr?: string | null
  }
}

export default function RiderMobileProfile() {
  const { user, isVerified: isGloballyVerified } = useAuth()
  const [isLoading, setIsLoading] = useState(true)
  const [profile, setProfile] = useState<RiderProfile | null>(null)
  const [isEditing, setIsEditing] = useState(false)
  const [formData, setFormData] = useState({
    firstName: "",
    lastName: "",
    email: "",
    phone: "",
    vehicleType: "",
    licenseNumber: "",
  })
  const fileInputRef = useRef<HTMLInputElement>(null)
  const licenseInputRef = useRef<HTMLInputElement>(null)
  const orCrInputRef = useRef<HTMLInputElement>(null)
  const [uploadingLicense, setUploadingLicense] = useState(false)
  const [uploadingOrCr, setUploadingOrCr] = useState(false)

  useEffect(() => {
    const fetchProfile = async () => {
      setIsLoading(true)
      try {
        const res = await riderAccountApi.getProfile()
        const rider = (res.data as any).profile as any

        const profileData: RiderProfile = {
          givenName: rider.givenName || "",
          surname: rider.surname || "",
          email: rider.email || "",
          contactNumber: rider.contactNumber || "",
          vehicleType: rider.vehicleType || "",
          licenseNumber: rider.licenseNumber || "",
          avatarUrl: rider.avatarUrl || null,
          address: rider.address || {
            regionName: "",
            provinceName: "",
            municipalityName: "",
            barangayName: "",
          },
          documents: {
            license: rider.documents?.license || rider.documents?.licensePath || null,
            orCr: rider.documents?.orCr || rider.documents?.orCrPath || null,
          },
        }

        setProfile(profileData)
        setFormData({
          firstName: profileData.givenName,
          lastName: profileData.surname,
          email: profileData.email,
          phone: profileData.contactNumber,
          vehicleType: profileData.vehicleType || "",
          licenseNumber: profileData.licenseNumber || "",
        })
      } catch {
        // Handle error
      } finally {
        setIsLoading(false)
      }
    }

    void fetchProfile()
  }, [])

  const handleSave = async () => {
    try {
      const payload = {
        givenName: formData.firstName,
        surname: formData.lastName,
        email: formData.email,
        contactNumber: formData.phone,
        vehicleType: formData.vehicleType,
        licenseNumber: formData.licenseNumber,
      }

      await riderAccountApi.updateProfile(payload)
      setProfile((prev) =>
        prev
          ? {
              ...prev,
              givenName: formData.firstName,
              surname: formData.lastName,
              email: formData.email,
              contactNumber: formData.phone,
              vehicleType: formData.vehicleType,
              licenseNumber: formData.licenseNumber,
            }
          : null
      )
      setIsEditing(false)
    } catch {
      // Handle error
    }
  }

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    try {
      const res = await riderAccountApi.uploadAvatar(file)
      const newUrl = (res.data as any).avatarUrl as string | undefined
      if (newUrl) {
        setProfile((prev) => (prev ? { ...prev, avatarUrl: newUrl } : null))
      }
    } catch {
      // Handle error
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
    } catch {
      // Handle error
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
    } catch {
      // Handle error
    } finally {
      setUploadingOrCr(false)
      if (orCrInputRef.current) orCrInputRef.current.value = ""
    }
  }

  const isApproved = isGloballyVerified()

  return (
    <div className="p-4 space-y-4">
      {/* Profile Header */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-6 shadow-sm dark:shadow-gray-900">
        <div className="flex flex-col items-center">
          <div className="relative">
            <div className="w-24 h-24 rounded-full overflow-hidden border-4" style={{ borderColor: `${kPrimaryPink}40` }}>
              <Image
                src={profile?.avatarUrl || "/woman-portrait.png"}
                alt="Profile"
                width={96}
                height={96}
                className="object-cover w-full h-full"
              />
            </div>
            <button
              onClick={() => fileInputRef.current?.click()}
              className="absolute bottom-0 right-0 w-8 h-8 rounded-full flex items-center justify-center text-white shadow-lg"
              style={{ backgroundColor: kPrimaryPink }}
              disabled={!isApproved}
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleAvatarChange}
            />
          </div>
          <h2 className="mt-4 text-xl font-semibold dark:text-white">
            {profile?.givenName || user?.givenName || "Rider"} {profile?.surname || user?.surname}
          </h2>
          <p className="text-sm text-gray-500 dark:text-gray-400">{profile?.email || user?.email}</p>
          <div className="mt-3">
            <span
              className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium ${
                isApproved ? "bg-green-100 text-green-700" : "bg-amber-100 text-amber-700"
              }`}
            >
              {isApproved ? (
                <>
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Verified Rider
                </>
              ) : (
                <>
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Pending verification
                </>
              )}
            </span>
          </div>
        </div>
      </div>

      {/* Not verified notice */}
      {!isApproved && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <p className="font-semibold text-amber-900 mb-1">Account awaiting approval</p>
          <p className="text-xs text-amber-800">
            Your rider account is not yet verified. You can log in, but deliveries and profile changes will be available only after an admin approves your account.
          </p>
        </div>
      )}

      {/* Personal Information */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm dark:shadow-gray-900">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold dark:text-white">Personal Information</h3>
          {!isEditing ? (
            <button
              onClick={() => setIsEditing(true)}
              className="text-sm font-medium"
              style={{ color: kPrimaryPink }}
              disabled={!isApproved}
            >
              Edit
            </button>
          ) : (
            <div className="flex gap-2">
              <button
                onClick={() => setIsEditing(false)}
                className="text-sm text-gray-600"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="text-sm font-medium"
                style={{ color: kPrimaryPink }}
              >
                Save
              </button>
            </div>
          )}
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">First Name</label>
            <input
              type="text"
              value={formData.firstName}
              onChange={(e) => setFormData({ ...formData, firstName: e.target.value })}
              disabled={!isEditing || !isApproved}
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:border-pink-300 disabled:bg-gray-50 dark:disabled:bg-gray-800"
            />
          </div>
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">Last Name</label>
            <input
              type="text"
              value={formData.lastName}
              onChange={(e) => setFormData({ ...formData, lastName: e.target.value })}
              disabled={!isEditing || !isApproved}
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:border-pink-300 disabled:bg-gray-50 dark:disabled:bg-gray-800"
            />
          </div>
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">Email</label>
            <input
              type="email"
              value={formData.email}
              disabled
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-500"
            />
          </div>
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">Phone</label>
            <input
              type="tel"
              value={formData.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              disabled={!isEditing || !isApproved}
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:border-pink-300 disabled:bg-gray-50 dark:disabled:bg-gray-800"
            />
          </div>
        </div>
      </div>

      {/* Vehicle Information */}
      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm dark:shadow-gray-900">
        <h3 className="font-semibold dark:text-white mb-4">Vehicle Information</h3>
        <div className="space-y-4">
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">Vehicle Type</label>
            <input
              type="text"
              value={formData.vehicleType}
              onChange={(e) => setFormData({ ...formData, vehicleType: e.target.value })}
              disabled={!isEditing || !isApproved}
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:border-pink-300 disabled:bg-gray-50 dark:disabled:bg-gray-800"
              placeholder="e.g. Motorcycle"
            />
          </div>
          <div>
            <label className="block text-xs text-gray-500 dark:text-gray-400 mb-1">License Number</label>
            <input
              type="text"
              value={formData.licenseNumber}
              onChange={(e) => setFormData({ ...formData, licenseNumber: e.target.value })}
              disabled={!isEditing || !isApproved}
              className="w-full px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:border-pink-300 disabled:bg-gray-50 dark:disabled:bg-gray-800"
              placeholder="e.g. N01-123456"
            />
          </div>
        </div>
      </div>

      {/* Address */}
      {profile?.address && (
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm dark:shadow-gray-900">
          <h3 className="font-semibold dark:text-white mb-4">Address Information</h3>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">Region</span>
              <span className="dark:text-gray-300">{profile.address.regionName || "-"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">Province</span>
              <span className="dark:text-gray-300">{profile.address.provinceName || "-"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">City/Municipality</span>
              <span className="dark:text-gray-300">{profile.address.municipalityName || "-"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">Barangay</span>
              <span className="dark:text-gray-300">{profile.address.barangayName || "-"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">Street Address</span>
              <span className="dark:text-gray-300">{profile.address.streetAddress || "-"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-500 dark:text-gray-400">Postal Code</span>
              <span className="dark:text-gray-300">{profile.address.postalCode || "-"}</span>
            </div>
          </div>
        </div>
      )}

      {/* Documents */}
      {profile && (
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm dark:shadow-gray-900">
          <h3 className="font-semibold dark:text-white mb-4">Documents</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
              <div className="flex items-center gap-3">
                <div
                  className="w-10 h-10 rounded-lg flex items-center justify-center"
                  style={{ backgroundColor: `${kPrimaryPink}20` }}
                >
                  <svg className="w-5 h-5" style={{ color: kPrimaryPink }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.306 0 2.417.835 2.83 2M9 14a3.001 3.001 0 00-2.83 2M15 11h3m-3 4h2" />
                  </svg>
                </div>
                <div>
                  <p className="font-medium text-sm dark:text-white">Driver&apos;s License</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">Uploaded during registration</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {profile.documents.license ? (
                  <a
                    href={
                      profile.documents.license.startsWith("http")
                        ? profile.documents.license
                        : `${API_BASE_ORIGIN}/${profile.documents.license.replace(/^\//, "")}`
                    }
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm font-medium"
                    style={{ color: kPrimaryPink }}
                  >
                    View
                  </a>
                ) : (
                  <span className="text-xs text-gray-400 dark:text-gray-500">No file</span>
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
                    <button
                      onClick={() => licenseInputRef.current?.click()}
                      className="text-xs px-2 py-1 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300"
                      disabled={uploadingLicense}
                    >
                      {uploadingLicense ? "..." : "Re-up"}
                    </button>
                  </>
                )}
              </div>
            </div>

            <div className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
              <div className="flex items-center gap-3">
                <div
                  className="w-10 h-10 rounded-lg flex items-center justify-center"
                  style={{ backgroundColor: `${kPrimaryPink}20` }}
                >
                  <svg className="w-5 h-5" style={{ color: kPrimaryPink }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div>
                  <p className="font-medium text-sm dark:text-white">OR/CR</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">Vehicle registration document</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {profile.documents.orCr ? (
                  <a
                    href={
                      profile.documents.orCr.startsWith("http")
                        ? profile.documents.orCr
                        : `${API_BASE_ORIGIN}/${profile.documents.orCr.replace(/^\//, "")}`
                    }
                    target="_blank"
                    rel="noreferrer"
                    className="text-sm font-medium"
                    style={{ color: kPrimaryPink }}
                  >
                    View
                  </a>
                ) : (
                  <span className="text-xs text-gray-400 dark:text-gray-500">No file</span>
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
                    <button
                      onClick={() => orCrInputRef.current?.click()}
                      className="text-xs px-2 py-1 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-300"
                      disabled={uploadingOrCr}
                    >
                      {uploadingOrCr ? "..." : "Re-up"}
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Settings Link */}
      <Link
        href="/rider/mobile/settings"
        className="flex items-center gap-4 p-4 bg-white dark:bg-gray-800 rounded-2xl shadow-sm"
      >
        <div className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
          <svg className="w-5 h-5 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        </div>
        <div className="flex-1">
          <p className="font-medium text-sm dark:text-white">Account Settings</p>
          <p className="text-xs text-gray-500 dark:text-gray-400">Password, email, and account management</p>
        </div>
        <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
        </svg>
      </Link>
    </div>
  )
}
