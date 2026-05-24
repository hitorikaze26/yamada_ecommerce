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
import { Checkbox } from "@/components/ui/checkbox"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { AddressSelector } from "@/components/form/address-selector"
import { FileUploader } from "@/components/form/file-uploader"
import { PasswordStrengthIndicator } from "@/components/form/password-strength"
import { GlassAlert } from "@/components/ui/glass-alert"
import { authApi, type AddressData } from "@/lib/api"

const STORAGE_KEY = "yamada-rider-registration"

interface RiderFormData {
  givenName: string
  surname: string
  email: string
  password: string
  confirmPassword: string
  contactNumber: string
  vehicleType: string
  licenseNumber: string
  address: AddressData | null
  license: File | null
  orCr: File | null
  acceptTerms: boolean
}

const vehicleTypes = [
  { value: "motorcycle", label: "Motorcycle" },
  { value: "bicycle", label: "Bicycle" },
  { value: "car", label: "Car" },
  { value: "van", label: "Van" },
]

export default function RiderRegistrationPage() {
  const router = useRouter()
  const [currentSection, setCurrentSection] = useState(0)
  const [formData, setFormData] = useState<RiderFormData>({
    givenName: "",
    surname: "",
    email: "",
    password: "",
    confirmPassword: "",
    contactNumber: "",
    vehicleType: "",
    licenseNumber: "",
    address: null,
    license: null,
    orCr: null,
    acceptTerms: false,
  })
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const sections = [
    { id: "personal", title: "Personal Info", icon: "user" },
    { id: "address", title: "Address", icon: "marker" },
    { id: "vehicle-documents", title: "Vehicle & Documents", icon: "car" },
  ]

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  useEffect(() => {
    const saved = typeof window !== "undefined" ? localStorage.getItem(STORAGE_KEY) : null
    if (saved) {
      try {
        const parsed = JSON.parse(saved)
        setFormData((prev) => ({
          ...prev,
          ...parsed,
          password: "",
          confirmPassword: "",
          license: null,
          orCr: null,
        }))
        if (typeof parsed.currentSection === "number") {
          setCurrentSection(parsed.currentSection)
        }
      } catch (e) {
        console.error("Failed to load saved rider registration data")
      }
    }
  }, [])

  useEffect(() => {
    const dataToSave = {
      ...formData,
      password: "",
      confirmPassword: "",
      license: null,
      orCr: null,
      currentSection,
    }
    if (typeof window !== "undefined") {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(dataToSave))
    }
  }, [formData, currentSection])

  const updateFormData = (updates: Partial<RiderFormData>) => {
    setFormData((prev) => ({ ...prev, ...updates }))
  }

  const validateSection = (section: number): string | null => {
    switch (section) {
      case 0:
        if (!formData.givenName.trim()) return "Given name is required"
        if (!formData.surname.trim()) return "Surname is required"
        if (!formData.email.trim()) return "Email is required"
        if (formData.password.length < 8) return "Password must be at least 8 characters"
        if (formData.password !== formData.confirmPassword) return "Passwords do not match"
        if (!formData.contactNumber.trim()) return "Contact number is required"
        return null
      case 1:
        if (!formData.address) return "Please select your address"
        return null
      case 2:
        if (!formData.vehicleType) return "Vehicle type is required"
        if (!formData.licenseNumber.trim()) return "License number is required"
        if (!formData.license) return "Please upload your driver's license"
        if (!formData.orCr) return "Please upload your OR/CR"
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
    setCurrentSection((prev) => Math.min(prev + 1, sections.length - 1))
  }

  const handleBack = () => {
    setError("")
    setCurrentSection((prev) => Math.max(prev - 1, 0))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const validationError = validateSection(currentSection)
    if (validationError) {
      setError(validationError)
      return
    }

    setError("")
    setIsLoading(true)

    try {
      if (!formData.address) {
        setError("Please select your address")
        setIsLoading(false)
        return
      }

      await authApi.registerRider({
        givenName: formData.givenName,
        surname: formData.surname,
        email: formData.email,
        password: formData.password,
        contactNumber: formData.contactNumber,
        vehicleType: formData.vehicleType,
        licenseNumber: formData.licenseNumber,
        address: formData.address,
        license: formData.license ?? "",
        orCr: formData.orCr ?? "",
      })
      showAlert("Rider registration successful.", "success")

      await Swal.fire({
        title: "Registration Successful",
        text: "Your rider account has been created. You can now log in.",
        icon: "success",
        confirmButtonText: "Go to Login",
      })

      if (typeof window !== "undefined") {
        localStorage.removeItem(STORAGE_KEY)
      }
      router.push("/auth/login?role=rider&registered=true")
    } catch (err) {
      setError("Registration failed. Please try again.")
      showAlert("Rider registration failed. Please try again.", "error")
    } finally {
      setIsLoading(false)
    }
  }

  const renderSection = () => {
    switch (currentSection) {
      case 0:
        return (
          <div className="space-y-4">
            <h3 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">Personal Info</h3>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="givenName">Given Name</Label>
                <Input
                  id="givenName"
                  placeholder="Juan"
                  value={formData.givenName}
                  onChange={(e) => updateFormData({ givenName: e.target.value })}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="surname">Surname</Label>
                <Input
                  id="surname"
                  placeholder="Dela Cruz"
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
            <h3 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">Address</h3>
            <AddressSelector value={formData.address} onChange={(address) => updateFormData({ address })} />
          </div>
        )

      case 2:
        return (
          <div className="space-y-4">
            <h3 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">
              Vehicle Information & Documents
            </h3>

            <div className="space-y-2">
              <Label htmlFor="vehicleType">Vehicle Type</Label>
              <Select value={formData.vehicleType} onValueChange={(value) => updateFormData({ vehicleType: value })}>
                <SelectTrigger>
                  <SelectValue placeholder="Select vehicle type" />
                </SelectTrigger>
                <SelectContent>
                  {vehicleTypes.map((type) => (
                    <SelectItem key={type.value} value={type.value}>
                      {type.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="licenseNumber">License Number</Label>
              <Input
                id="licenseNumber"
                placeholder="N01-23-456789"
                value={formData.licenseNumber}
                onChange={(e) => updateFormData({ licenseNumber: e.target.value })}
                required
              />
            </div>

            <div className="space-y-4 pt-2">
              <h3 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">Documents</h3>

              <div className="space-y-2">
                <Label>Driver&apos;s License</Label>
                <FileUploader
                  accept="image/*,.pdf"
                  onUpload={(file) => updateFormData({ license: file })}
                  value={formData.license}
                />
              </div>

              <div className="space-y-2">
                <Label>OR/CR (Official Receipt / Certificate of Registration)</Label>
                <FileUploader
                  accept="image/*,.pdf"
                  onUpload={(file) => updateFormData({ orCr: file })}
                  value={formData.orCr}
                />
              </div>
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
                , and Rider Agreement
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
      {/* Left Panel - Branding (match seller theme, sticky on large screens) */}
      <div className="hidden lg:flex lg:w-1/2 bg-secondary relative overflow-hidden lg:sticky lg:top-0 lg:h-screen">
        <div className="absolute inset-0 bg-gradient-to-br from-transparent to-black/20" />
        <div className="relative z-10 flex flex-col justify-between p-12 text-white">
          <Link href="/" className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-black/20 backdrop-blur-sm flex items-center justify-center">
              <span className="text-2xl font-bold">Y</span>
            </div>
            <span className="text-2xl font-semibold">Yamada</span>
          </Link>

          <div>
            <h1 className="text-4xl font-bold mb-4">Become a Rider</h1>
            <p className="text-lg opacity-90">Deliver happiness and earn on your own schedule</p>

            <div className="mt-8 grid grid-cols-2 gap-4">
              <div className="bg-black/10 backdrop-blur-sm rounded-xl p-4">
                <Icon name="money-bill-simple-wave" size="xl" className="mb-2" />
                <h3 className="font-semibold mb-1">Competitive Pay</h3>
                <p className="text-sm opacity-80">Earn competitive rates per delivery</p>
              </div>
              <div className="bg-black/10 backdrop-blur-sm rounded-xl p-4">
                <Icon name="clock" size="xl" className="mb-2" />
                <h3 className="font-semibold mb-1">Flexible Hours</h3>
                <p className="text-sm opacity-80">Work when you want</p>
              </div>
            </div>
          </div>

          <div className="text-sm opacity-70">Join our growing team of delivery partners</div>
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

        <div className="flex-1 flex items-start justify-center p-6 overflow-y-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="w-full max-w-md space-y-6"
          >
            <div className="text-center lg:text-left">
              <h2 className="text-3xl font-bold mb-2">{sections[currentSection].title}</h2>
              <p className="text-muted-foreground">
                Step {currentSection + 1} of {sections.length}
              </p>
            </div>

            <div className="flex items-center justify-center gap-2 lg:hidden">
              {sections.map((_, index) => (
                <div
                  key={index}
                  className={`h-2 rounded-full transition-all ${
                    index <= currentSection ? "bg-primary w-8" : "bg-muted w-2"
                  }`}
                />
              ))}
            </div>

            {error && (
              <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                <Icon name="exclamation-circle" />
                {error}
              </div>
            )}

            <form
              onSubmit={currentSection === sections.length - 1 ? handleSubmit : (e) => e.preventDefault()}
              className="space-y-4"
            >
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

              <div className="flex gap-3 pt-4">
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
                  <Button type="submit" className="flex-1" size="lg" disabled={isLoading}>
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
              Already a rider?{" "}
              <Link href="/auth/login?role=rider" className="text-primary hover:underline font-medium">
                Sign in
              </Link>
            </p>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
