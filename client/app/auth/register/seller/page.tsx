"use client"

import type React from "react"

import { useState, useEffect } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import Swal from "sweetalert2"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Checkbox } from "@/components/ui/checkbox"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { AddressSelector } from "@/components/form/address-selector"
import { FileUploader } from "@/components/form/file-uploader"
import { PasswordStrengthIndicator } from "@/components/form/password-strength"
import { GlassAlert } from "@/components/ui/glass-alert"
import { CATEGORIES } from "@/lib/types"
import { authApi, type AddressData } from "@/lib/api"

const STORAGE_KEY = "yamada-seller-registration"

interface SellerFormData {
  // Basic Info
  givenName: string
  surname: string
  email: string
  password: string
  confirmPassword: string
  contactNumber: string
  // Shop Info
  shopName: string
  categories: string[]
  tagline: string
  description: string
  logo: File | null
  // Address
  address: AddressData | null
  // Documents
  dti: File | null
  birTin: File | null
  businessPermit: File | null
  validId: File | null
  // Terms
  acceptTerms: boolean
}

const initialFormData: SellerFormData = {
  givenName: "",
  surname: "",
  email: "",
  password: "",
  confirmPassword: "",
  contactNumber: "",
  shopName: "",
  categories: [],
  tagline: "",
  description: "",
  logo: null,
  address: null,
  dti: null,
  birTin: null,
  businessPermit: null,
  validId: null,
  acceptTerms: false,
}

const sections = [
  { id: "basic", title: "Basic Info", icon: "user" },
  { id: "shop", title: "Shop Info", icon: "shop" },
  { id: "address", title: "Address", icon: "marker" },
  { id: "documents", title: "Documents", icon: "document" },
]

export default function SellerRegistrationPage() {
  const router = useRouter()
  const [currentSection, setCurrentSection] = useState(0)
  const [formData, setFormData] = useState<SellerFormData>(initialFormData)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [hasTriedDocumentsSubmit, setHasTriedDocumentsSubmit] = useState(false)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  // Load saved progress
  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved) {
      try {
        const parsed = JSON.parse(saved)
        setFormData((prev) => ({
          ...prev,
          ...parsed,
          password: "",
          confirmPassword: "",
          logo: null,
          dti: null,
          birTin: null,
          businessPermit: null,
          validId: null,
        }))
        if (parsed.currentSection) setCurrentSection(parsed.currentSection)
      } catch (e) {
        console.error("Failed to load saved data")
      }
    }
  }, [])

  // Save progress
  useEffect(() => {
    const dataToSave = {
      ...formData,
      password: "",
      confirmPassword: "",
      logo: null,
      dti: null,
      birTin: null,
      businessPermit: null,
      validId: null,
      currentSection,
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(dataToSave))
  }, [formData, currentSection])

  const updateFormData = (updates: Partial<SellerFormData>) => {
    setFormData((prev) => ({ ...prev, ...updates }))
  }

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const toggleCategory = (categoryId: string) => {
    setFormData((prev) => ({
      ...prev,
      categories: prev.categories.includes(categoryId)
        ? prev.categories.filter((c) => c !== categoryId)
        : [...prev.categories, categoryId],
    }))
  }

  const validateSection = (section: number): string | null => {
    switch (section) {
      case 0: // Basic Info
        if (!formData.givenName.trim()) return "Given name is required"
        if (!formData.surname.trim()) return "Surname is required"
        if (!formData.email.trim()) return "Email is required"
        if (formData.password.length < 8) return "Password must be at least 8 characters"
        if (formData.password !== formData.confirmPassword) return "Passwords do not match"
        if (!formData.contactNumber.trim()) return "Contact number is required"
        return null
      case 1: // Shop Info
        if (!formData.shopName.trim()) return "Shop name is required"
        if (formData.categories.length === 0) return "Select at least one category"
        return null
      case 2: // Address
        if (!formData.address) return "Please select your shop address"
        return null
      case 3: // Documents
        if (!formData.dti) return "DTI registration is required"
        if (!formData.birTin) return "BIR TIN is required"
        if (!formData.businessPermit) return "Business permit is required"
        if (!formData.validId) return "Valid ID is required"
        if (!formData.acceptTerms) return "You must accept the terms and conditions"
        return null
      default:
        return null
    }
  }

  const handleNext = () => {
    const validationError = validateSection(currentSection)
    if (validationError) {
      setError(validationError)
      return
    }
    setError("")
    setHasTriedDocumentsSubmit(false)
    setCurrentSection((prev) => Math.min(prev + 1, sections.length - 1))
  }

  const handleBack = () => {
    setError("")
    setHasTriedDocumentsSubmit(false)
    setCurrentSection((prev) => Math.max(prev - 1, 0))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setHasTriedDocumentsSubmit(true)
    const validationError = validateSection(currentSection)
    if (validationError) {
      setError(validationError)
      return
    }

    setError("")
    setIsLoading(true)

    try {
      if (!formData.address) {
        setError("Please select your shop address")
        setIsLoading(false)
        return
      }

      await authApi.registerSeller({
        givenName: formData.givenName,
        surname: formData.surname,
        email: formData.email.trim().toLowerCase(),
        password: formData.password,
        contactNumber: formData.contactNumber,
        shopName: formData.shopName,
        categories: formData.categories,
        logo: formData.logo ?? "",
        tagline: formData.tagline,
        description: formData.description,
        address: formData.address,
        documents: {
          dti: formData.dti ?? "",
          birTin: formData.birTin ?? "",
          businessPermit: formData.businessPermit ?? "",
          validId: formData.validId ?? "",
        },
      })

      localStorage.removeItem(STORAGE_KEY)
      showAlert("Seller registration successful.", "success")
      setIsLoading(false)

      const result = await Swal.fire({
        title: "Registration Successful",
        text: "Your seller account has been created. You can now log in.",
        icon: "success",
        confirmButtonText: "Go to Login",
      })

      if (result.isConfirmed || result.isDismissed) {
        router.push("/auth/login?role=seller&registered=true")
      }
      return
    } catch (err: any) {
      const msg = err?.response?.data?.msg || "Registration failed. Please try again."
      setError(msg)
      showAlert("Seller registration failed. Please try again.", "error")
    } finally {
      setIsLoading(false)
    }
  }

  const renderSection = () => {
    switch (currentSection) {
      case 0:
        return (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="givenName">Given Name</Label>
                <Input
                  id="givenName"
                  placeholder="Jane"
                  value={formData.givenName}
                  onChange={(e) => updateFormData({ givenName: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="surname">Surname</Label>
                <Input
                  id="surname"
                  placeholder="Doe"
                  value={formData.surname}
                  onChange={(e) => updateFormData({ surname: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="you@example.com"
                value={formData.email}
                onChange={(e) => updateFormData({ email: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="Create a strong password"
                  value={formData.password}
                  onChange={(e) => updateFormData({ password: e.target.value })}
                  className="pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                >
                  <Icon name={showPassword ? "eye-crossed" : "eye"} />
                </button>
              </div>
              <PasswordStrengthIndicator password={formData.password} />
            </div>

            <div className="space-y-2">
              <Label htmlFor="confirmPassword">Confirm Password</Label>
              <Input
                id="confirmPassword"
                type="password"
                placeholder="Confirm your password"
                value={formData.confirmPassword}
                onChange={(e) => updateFormData({ confirmPassword: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="contactNumber">Contact Number</Label>
              <Input
                id="contactNumber"
                type="tel"
                placeholder="+63 912 345 6789"
                value={formData.contactNumber}
                onChange={(e) => updateFormData({ contactNumber: e.target.value })}
                required
              />
            </div>
          </div>
        )

      case 1:
        return (
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="shopName">Shop Name</Label>
              <Input
                id="shopName"
                placeholder="My Awesome Shop"
                value={formData.shopName}
                onChange={(e) => updateFormData({ shopName: e.target.value })}
                required
              />
            </div>

            <div className="space-y-2">
              <Label>Categories</Label>
              <p className="text-sm text-muted-foreground">Select the categories your shop will sell</p>
              <div className="grid grid-cols-2 gap-2 mt-2">
                {CATEGORIES.map((category) => (
                  <button
                    key={category.id}
                    type="button"
                    onClick={() => toggleCategory(category.id)}
                    className={`p-3 rounded-lg border text-left text-sm transition-all ${
                      formData.categories.includes(category.id)
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border hover:border-primary/50"
                    }`}
                  >
                    <Icon name={category.icon} className="mr-2" />
                    {category.name}
                  </button>
                ))}
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="tagline">Tagline (Optional)</Label>
              <Input
                id="tagline"
                placeholder="Your shop's catchy tagline"
                value={formData.tagline}
                onChange={(e) => updateFormData({ tagline: e.target.value })}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description (Optional)</Label>
              <Textarea
                id="description"
                placeholder="Tell customers about your shop..."
                value={formData.description}
                onChange={(e) => updateFormData({ description: e.target.value })}
                rows={3}
              />
            </div>

            <div className="space-y-2">
              <Label>Shop Logo (Optional)</Label>
              <FileUploader
                accept="image/*"
                onUpload={(file) => updateFormData({ logo: file })}
                value={formData.logo}
              />
            </div>
          </div>
        )

      case 2:
        return (
          <div className="space-y-4">
            <Label>Shop Address</Label>
            <p className="text-sm text-muted-foreground">Select the address where your shop is located</p>
            <AddressSelector value={formData.address} onChange={(address) => updateFormData({ address })} />
          </div>
        )

      case 3:
        return (
          <div className="space-y-4">
            <p className="text-sm text-muted-foreground">
              Upload the required documents for verification. All documents must be clear and readable.
            </p>

            <div className="space-y-2">
              <Label>DTI Registration</Label>
              <FileUploader
                accept="image/*,.pdf"
                onUpload={(file) => updateFormData({ dti: file })}
                value={formData.dti}
              />
            </div>

            <div className="space-y-2">
              <Label>BIR TIN</Label>
              <FileUploader
                accept="image/*,.pdf"
                onUpload={(file) => updateFormData({ birTin: file })}
                value={formData.birTin}
              />
            </div>

            <div className="space-y-2">
              <Label>Business Permit</Label>
              <FileUploader
                accept="image/*,.pdf"
                onUpload={(file) => updateFormData({ businessPermit: file })}
                value={formData.businessPermit}
              />
            </div>

            <div className="space-y-2">
              <Label>Valid ID</Label>
              <FileUploader
                accept="image/*,.pdf"
                onUpload={(file) => updateFormData({ validId: file })}
                value={formData.validId}
              />
            </div>

            <div className="flex items-start gap-2 pt-4">
              <Checkbox
                id="terms"
                checked={formData.acceptTerms}
                onCheckedChange={(checked) => updateFormData({ acceptTerms: checked as boolean })}
              />
              <label htmlFor="terms" className="text-sm text-muted-foreground leading-tight">
                I agree to the{" "}
                <Link href="/terms" className="text-primary hover:underline">
                  Terms of Service
                </Link>
                ,{" "}
                <Link href="/privacy" className="text-primary hover:underline">
                  Privacy Policy
                </Link>
                , and Seller Agreement
              </label>
            </div>
          </div>
        )

      default:
        return null
    }
  }

  return (
    <div className="min-h-screen flex">
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
      {/* Left Panel - Branding (sticky on large screens) */}
      <div className="hidden lg:flex lg:w-1/2 bg-secondary relative overflow-hidden lg:sticky lg:top-0 lg:h-screen">
        <div className="absolute inset-0 bg-gradient-to-br from-transparent to-black/20" />
        <div className="relative z-10 flex flex-col justify-between p-12 text-white">
          <Link href="/" className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center">
              <span className="text-2xl font-bold">Y</span>
            </div>
            <span className="text-2xl font-semibold">Yamada</span>
          </Link>

          <div>
            <h1 className="text-4xl font-bold mb-4">Become a Seller</h1>
            <p className="text-lg opacity-90">Join thousands of sellers and reach millions of customers</p>
          </div>

          {/* Section Progress */}
          <div className="space-y-3">
            {sections.map((section, index) => (
              <button
                key={section.id}
                onClick={() => index <= currentSection && setCurrentSection(index)}
                disabled={index > currentSection}
                className={`flex items-center gap-3 w-full text-left transition-all ${
                  index === currentSection
                    ? "opacity-100"
                    : index < currentSection
                      ? "opacity-70 hover:opacity-100"
                      : "opacity-40 cursor-not-allowed"
                }`}
              >
                <div
                  className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    index < currentSection
                      ? "bg-white text-secondary"
                      : index === currentSection
                        ? "bg-white/30 ring-2 ring-white"
                        : "bg-white/20"
                  }`}
                >
                  {index < currentSection ? <Icon name="check" /> : <Icon name={section.icon} />}
                </div>
                <span className="font-medium">{section.title}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Right Panel - Form */}
      <div className="flex-1 flex flex-col">
        <div className="flex justify-between items-center p-6">
          <Link href="/" className="lg:hidden flex items-center gap-2">
            <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center">
              <span className="text-primary-foreground font-bold text-xl">Y</span>
            </div>
            <span className="text-xl font-semibold">Yamada</span>
          </Link>
          <DarkModeToggle />
        </div>

        {/* Mobile Section Progress */}
        <div className="flex items-center justify-center gap-2 px-6 pb-4 lg:hidden">
          {sections.map((_, index) => (
            <div
              key={index}
              className={`h-2 rounded-full transition-all ${
                index <= currentSection ? "bg-primary w-8" : "bg-muted w-2"
              }`}
            />
          ))}
        </div>

        <div className="flex-1 flex items-start justify-center p-6 overflow-y-auto">
          <div className="w-full max-w-md space-y-6">
            <div className="text-center lg:text-left">
              <h2 className="text-3xl font-bold mb-2">{sections[currentSection].title}</h2>
              <p className="text-muted-foreground">
                Step {currentSection + 1} of {sections.length}
              </p>
            </div>

            {error && (currentSection !== 3 || hasTriedDocumentsSubmit) && (
              <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                <Icon name="exclamation-circle" />
                {error}
              </div>
            )}

            <form onSubmit={currentSection === sections.length - 1 ? handleSubmit : (e) => e.preventDefault()}>
              <AnimatePresence mode="wait">
                <motion.div
                  key={currentSection}
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                >
                  {renderSection()}
                </motion.div>
              </AnimatePresence>

              <div className="flex gap-3 mt-6">
                {currentSection > 0 && (
                  <Button type="button" variant="outline" className="flex-1 bg-transparent" onClick={handleBack}>
                    <Icon name="arrow-left" className="mr-2" />
                    Back
                  </Button>
                )}
                {currentSection < sections.length - 1 ? (
                  <Button type="button" className="flex-1" onClick={handleNext}>
                    Continue
                    <Icon name="arrow-right" className="ml-2" />
                  </Button>
                ) : (
                  <Button type="submit" className="flex-1" disabled={isLoading}>
                    {isLoading ? (
                      <>
                        <Icon name="spinner" className="mr-2 animate-spin" />
                        Submitting...
                      </>
                    ) : (
                      "Submit Application"
                    )}
                  </Button>
                )}
              </div>
            </form>

            <p className="text-center text-sm text-muted-foreground">
              Already have a seller account?{" "}
              <Link href="/auth/login?role=seller" className="text-primary hover:underline font-medium">
                Sign in
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
