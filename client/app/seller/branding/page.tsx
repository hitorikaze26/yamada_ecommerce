"use client"

import { useEffect, useRef, useState } from "react"
import type React from "react"
import Image from "next/image"
import Link from "next/link"
import { toast } from "sonner"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { sellerShopApi, resolveImageUrl } from "@/lib/api"
import { CATEGORIES } from "@/lib/types"
import { cn } from "@/lib/utils"
import { useAuth } from "@/context/auth-context"

export default function SellerBrandingPage() {
  const { refreshSellerProfile } = useAuth()
  const [formData, setFormData] = useState({
    shopName: "",
    tagline: "",
    description: "",
    givenName: "",
    surname: "",
    email: "",
    phone: "",
    categories: [] as string[],
  })
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [isUploading, setIsUploading] = useState(false)
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const [bannerUrl, setBannerUrl] = useState<string | null>(null)
  const [storeStatus, setStoreStatus] = useState<string | null>(null)
  const [isVerified, setIsVerified] = useState(false)
  const [rating, setRating] = useState(0)
  const [totalSales, setTotalSales] = useState(0)
  const [address, setAddress] = useState<Record<string, string> | null>(null)
  const [documents, setDocuments] = useState<Record<string, string | null> | null>(null)
  const [canEdit, setCanEdit] = useState(false)
  const [isEditingProfile, setIsEditingProfile] = useState(false)

  const avatarInputRef = useRef<HTMLInputElement>(null)
  const bannerInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    const load = async () => {
      try {
        setIsLoading(true)
        await refreshSellerProfile()
        const profileRes = await sellerShopApi.getProfile()
        const profile = (profileRes.data as { profile?: Record<string, unknown> })?.profile
        const verified =
          profile?.isVerified === true || profile?.storeStatus === "ACCEPTED"
        const hasStore = profile?.storeId != null && profile.storeId !== 0
        setCanEdit(verified && hasStore)

        setFormData({
          shopName: String(profile?.shopName ?? ""),
          tagline: String(profile?.tagline ?? ""),
          description: String(profile?.description ?? ""),
          givenName: String(profile?.givenName ?? ""),
          surname: String(profile?.surname ?? ""),
          email: String(profile?.email ?? ""),
          phone: String(profile?.contactNumber ?? ""),
          categories: Array.isArray(profile?.categories)
            ? (profile.categories as string[])
            : [],
        })
        const av = profile?.avatarUrl as string | undefined
        const bn = profile?.bannerUrl as string | undefined
        if (av) setAvatarUrl(resolveImageUrl(av))
        if (bn) setBannerUrl(resolveImageUrl(bn))
        setStoreStatus((profile?.storeStatus as string) ?? null)
        setIsVerified(!!verified)
        setRating(Number(profile?.rating ?? 0))
        setTotalSales(Number(profile?.totalSales ?? 0))
        setAddress((profile?.address as Record<string, string>) ?? null)
        setDocuments((profile?.documents as Record<string, string | null>) ?? null)
      } catch (err: unknown) {
        const msg =
          (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
          "Failed to load branding"
        toast.error(msg)
      } finally {
        setIsLoading(false)
      }
    }
    void load()
  }, [refreshSellerProfile])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!canEdit) return
    setIsSaving(true)
    try {
      await sellerShopApi.updateProfile({
        shopName: formData.shopName,
        tagline: formData.tagline,
        description: formData.description,
        givenName: formData.givenName,
        surname: formData.surname,
        email: formData.email,
        contactNumber: formData.phone,
        categories: formData.categories,
      })
      toast.success("Shop branding updated")
      await refreshSellerProfile()
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ||
        "Failed to update"
      toast.error(msg)
    } finally {
      setIsSaving(false)
    }
  }

  const handleAvatarChange = async (file: File) => {
    if (!canEdit) return
    setIsUploading(true)
    try {
      const res = await sellerShopApi.uploadAvatar(file)
      const url = (res.data as { avatarUrl?: string })?.avatarUrl
      if (url) {
        setAvatarUrl(resolveImageUrl(url))
        toast.success("Logo uploaded")
      }
    } catch {
      toast.error("Failed to upload logo")
    } finally {
      setIsUploading(false)
    }
  }

  const handleBannerChange = async (file: File) => {
    if (!canEdit) return
    setIsUploading(true)
    try {
      const res = await sellerShopApi.uploadBanner(file)
      const url = (res.data as { bannerUrl?: string })?.bannerUrl
      if (url) {
        setBannerUrl(resolveImageUrl(url))
        toast.success("Banner uploaded")
      }
    } catch {
      toast.error("Failed to upload banner")
    } finally {
      setIsUploading(false)
    }
  }

  if (isLoading) {
    return <p className="text-sm text-muted-foreground">Loading branding…</p>
  }

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold">My profile</h1>
        <p className="text-sm text-muted-foreground">
          Personal details and shop branding — how buyers see your store.{" "}
          <Link href="/seller/shop" className="text-primary hover:underline">
            Shop operations
          </Link>{" "}
          covers shipping and policies.
        </p>
      </div>

      {!canEdit && (
        <div className="p-4 rounded-2xl bg-amber-50 border border-amber-200 text-amber-900 text-sm flex gap-3">
          <Icon name="info-circle" />
          <p>Branding can be edited after your store is approved.</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <Card className="overflow-hidden">
          <div className="relative h-40 bg-gradient-to-r from-primary/20 to-primary/5">
            {bannerUrl && (
              <Image src={bannerUrl} alt="Banner" fill className="object-cover" />
            )}
            <button
              type="button"
              disabled={!canEdit || isUploading}
              onClick={() => bannerInputRef.current?.click()}
              className="absolute top-3 right-3 px-3 py-1.5 bg-white/90 rounded-lg text-xs font-medium shadow disabled:opacity-50"
            >
              Change banner
              <input
                ref={bannerInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0]
                  if (f) void handleBannerChange(f)
                  e.target.value = ""
                }}
              />
            </button>
          </div>
          <div className="px-6 pb-6">
            <div className="relative -mt-10 w-20 h-20 rounded-xl border-4 border-background overflow-hidden bg-card">
              {avatarUrl ? (
                <Image src={avatarUrl} alt="Logo" fill className="object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-2xl font-bold text-primary">
                  {formData.shopName.charAt(0) || "S"}
                </div>
              )}
              {canEdit && (
                <button
                  type="button"
                  className="absolute inset-0 bg-black/40 opacity-0 hover:opacity-100 flex items-center justify-center text-white text-xs"
                  onClick={() => avatarInputRef.current?.click()}
                >
                  Logo
                  <input
                    ref={avatarInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0]
                      if (f) void handleAvatarChange(f)
                      e.target.value = ""
                    }}
                  />
                </button>
              )}
            </div>
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-4">
          <Card className="p-4">
            <p className="text-2xl font-bold">{rating.toFixed(1)}</p>
            <p className="text-xs text-muted-foreground">Rating</p>
          </Card>
          <Card className="p-4">
            <p className="text-2xl font-bold">{totalSales}</p>
            <p className="text-xs text-muted-foreground">Sales</p>
          </Card>
        </div>

        <Card className="p-6 space-y-4">
          <div className="flex items-center justify-between gap-2">
            <h2 className="font-semibold">Personal information</h2>
            {canEdit && !isEditingProfile && (
              <button
                type="button"
                onClick={() => setIsEditingProfile(true)}
                className="flex items-center gap-1 text-sm text-primary hover:underline"
              >
                <Icon name="edit" size="sm" />
                Edit
              </button>
            )}
          </div>
          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <Label>First name</Label>
              <Input
                value={formData.givenName}
                onChange={(e) => setFormData({ ...formData, givenName: e.target.value })}
                disabled={!canEdit || !isEditingProfile || isSaving}
              />
            </div>
            <div>
              <Label>Last name</Label>
              <Input
                value={formData.surname}
                onChange={(e) => setFormData({ ...formData, surname: e.target.value })}
                disabled={!canEdit || !isEditingProfile || isSaving}
              />
            </div>
            <div>
              <Label>Email</Label>
              <Input value={formData.email} disabled className="opacity-70" />
            </div>
            <div>
              <Label>Phone</Label>
              <Input
                value={formData.phone}
                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                disabled={!canEdit || !isEditingProfile || isSaving}
              />
            </div>
          </div>
          {isEditingProfile && canEdit && (
            <div className="flex gap-2 pt-2">
              <Button type="button" variant="outline" onClick={() => setIsEditingProfile(false)}>
                Cancel
              </Button>
              <Button
                type="button"
                onClick={() => {
                  void handleSubmit({ preventDefault: () => {} } as React.FormEvent)
                  setIsEditingProfile(false)
                }}
                disabled={isSaving}
              >
                Save personal info
              </Button>
            </div>
          )}
        </Card>

        <Card className="p-6 space-y-4">
          <div className="flex items-center gap-2 flex-wrap">
            <h2 className="font-semibold">Shop information</h2>
            {storeStatus && (
              <Badge variant="secondary" className="capitalize">
                {storeStatus}
              </Badge>
            )}
            {isVerified && <Badge variant="outline">Verified</Badge>}
          </div>
          <div>
            <Label>Shop name</Label>
            <Input
              value={formData.shopName}
              onChange={(e) => setFormData({ ...formData, shopName: e.target.value })}
              disabled={!canEdit || isSaving}
              required
            />
          </div>
          <div>
            <Label>Tagline</Label>
            <Input
              value={formData.tagline}
              onChange={(e) => setFormData({ ...formData, tagline: e.target.value })}
              disabled={!canEdit || isSaving}
            />
          </div>
          <div>
            <Label>Description</Label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              rows={4}
              disabled={!canEdit || isSaving}
              className="w-full px-4 py-3 rounded-xl border bg-background resize-none"
            />
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="font-semibold mb-4">Categories</h2>
          <div className="flex flex-wrap gap-2">
            {CATEGORIES.map((cat) => {
              const selected = formData.categories.includes(cat.id)
              return (
                <button
                  key={cat.id}
                  type="button"
                  disabled={!canEdit}
                  onClick={() => {
                    const next = selected
                      ? formData.categories.filter((c) => c !== cat.id)
                      : [...formData.categories, cat.id]
                    setFormData({ ...formData, categories: next })
                  }}
                  className={cn(
                    "px-3 py-1.5 rounded-lg text-sm",
                    selected
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted text-muted-foreground",
                  )}
                >
                  {cat.name}
                </button>
              )
            })}
          </div>
        </Card>

        {address && (
          <Card className="p-6">
            <h2 className="font-semibold mb-2">Shop address</h2>
            <p className="text-sm text-muted-foreground">
              {address.streetAddress}, {address.barangayName}, {address.municipalityName}
            </p>
          </Card>
        )}

        {canEdit && (
          <div className="flex justify-end">
            <Button type="submit" disabled={isSaving}>
              {isSaving ? "Saving…" : "Save branding"}
            </Button>
          </div>
        )}
      </form>
    </div>
  )
}
