"use client"

import type React from "react"

import { useState, useEffect, useCallback } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import Swal from "sweetalert2"
import { motion, AnimatePresence } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { AddressSelector } from "@/components/form/address-selector"
import { FileUploader } from "@/components/form/file-uploader"
import { PasswordStrengthIndicator } from "@/components/form/password-strength"
import { EmailVerification } from "@/components/form/email-verification"
import { GlassAlert } from "@/components/ui/glass-alert"
import { authApi, type AddressData } from "@/lib/api"

const STORAGE_KEY = "yamada-buyer-registration"

interface Step1Data {
  givenName: string
  surname: string
  email: string
  password: string
  confirmPassword: string
  contactNumber: string
  acceptTerms: boolean
}

interface Step2Data {
  address: AddressData | null
  validId: File | null
}

export default function BuyerRegistrationPage() {
  const router = useRouter()
  const [step, setStep] = useState(1)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState("")
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")
  const [registeredEmail, setRegisteredEmail] = useState<string | null>(null)
  const [emailVerified, setEmailVerified] = useState(false)

  // Step 1 data
  const [step1Data, setStep1Data] = useState<Step1Data>({
    givenName: "",
    surname: "",
    email: "",
    password: "",
    confirmPassword: "",
    contactNumber: "",
    acceptTerms: false,
  })

  // Step 2 data
  const [step2Data, setStep2Data] = useState<Step2Data>({
    address: null,
    validId: null,
  })

  const showAlert = (message: string, variant: "success" | "error" | "info" | "warning" = "info") => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const handleAddressChange = useCallback(
    (address: AddressData) => {
      setStep2Data((prev) => ({ ...prev, address }))
    },
    [],
  )

  const [showPassword, setShowPassword] = useState(false)

  // Load saved progress from localStorage
  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY)
    if (saved) {
      try {
        const parsed = JSON.parse(saved)
        if (parsed.step1) setStep1Data(parsed.step1)
        if (parsed.step2?.address) setStep2Data((prev) => ({ ...prev, address: parsed.step2.address }))
        if (parsed.step) setStep(parsed.step)
      } catch (e) {
        console.error("Failed to load saved registration data")
      }
    }
  }, [])

  // Save progress to localStorage
  useEffect(() => {
    if (registeredEmail) return // Don't overwrite saved data during verification
    const dataToSave = {
      step1: { ...step1Data, password: "", confirmPassword: "" }, // Don't save passwords
      step2: { address: step2Data.address }, // Don't save file
      step,
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(dataToSave))
  }, [step1Data, step2Data.address, step, registeredEmail])

  const validateStep1 = (): string | null => {
    if (!step1Data.givenName.trim()) return "Given name is required"
    if (!step1Data.surname.trim()) return "Surname is required"
    if (!step1Data.email.trim()) return "Email is required"
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(step1Data.email)) return "Invalid email format"
    if (step1Data.password.length < 8) return "Password must be at least 8 characters"
    if (step1Data.password !== step1Data.confirmPassword) return "Passwords do not match"
    if (!step1Data.contactNumber.trim()) return "Contact number is required"
    if (!step1Data.acceptTerms) return "You must accept the terms and conditions"
    return null
  }

  const validateStep2 = (): string | null => {
    if (!step2Data.address) return "Please select your address"
    if (!step2Data.validId) return "Please upload a valid ID"
    return null
  }

  const handleStep1Submit = (e: React.FormEvent) => {
    e.preventDefault()
    const validationError = validateStep1()
    if (validationError) {
      setError(validationError)
      return
    }
    setError("")
    setStep(2)
  }

  const handleStep2Submit = async (e: React.FormEvent) => {
    e.preventDefault()
    const validationError = validateStep2()
    if (validationError) {
      setError(validationError)
      return
    }

    setError("")
    setIsLoading(true)

    try {
      const res = await authApi.registerBuyer({
        givenName: step1Data.givenName,
        surname: step1Data.surname,
        email: step1Data.email,
        password: step1Data.password,
        contactNumber: step1Data.contactNumber,
        address: step2Data.address!,
        validId: step2Data.validId ?? "",
      })

      const registeredEmail = res.data?.email || step1Data.email
      setRegisteredEmail(registeredEmail)
      setStep(3)

      localStorage.removeItem(STORAGE_KEY)
    } catch (err: any) {
      const msg = err?.response?.data?.msg || "Registration failed. Please try again."
      setError(msg)
      showAlert(msg, "error")
    } finally {
      setIsLoading(false)
    }
  }

  const handleEmailVerified = () => {
    setEmailVerified(true)
  }

  const handleGoToLogin = () => {
    router.push("/auth/login?role=buyer")
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
      <div className="hidden lg:flex lg:w-1/2 bg-primary relative overflow-hidden lg:sticky lg:top-0 lg:h-screen">
        <div className="absolute inset-0 bg-gradient-to-br from-transparent to-black/20" />
        <div className="relative z-10 flex flex-col justify-between p-12 text-white">
          <Link href="/" className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center">
              <span className="text-2xl font-bold">Y</span>
            </div>
            <span className="text-2xl font-semibold">Yamada</span>
          </Link>

          <div>
            <h1 className="text-4xl font-bold mb-4">Join Yamada</h1>
            <p className="text-lg opacity-90">Create an account to start shopping the latest women&apos;s fashion</p>
          </div>

          {/* Step Indicator */}
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${step >= 1 ? "bg-white text-primary" : "bg-white/20"}`}
              >
                {step > 2 ? <Icon name="check" /> : "1"}
              </div>
              <span className={step >= 1 ? "font-medium" : "opacity-70"}>Basic Info</span>
            </div>
            <div className="w-12 h-0.5 bg-white/30" />
            <div className="flex items-center gap-2">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${step >= 2 ? "bg-white text-primary" : "bg-white/20"}`}
              >
                {step > 2 ? <Icon name="check" /> : "2"}
              </div>
              <span className={step >= 2 ? "font-medium" : "opacity-70"}>Address & ID</span>
            </div>
            <div className="w-12 h-0.5 bg-white/30" />
            <div className="flex items-center gap-2">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center ${step >= 3 ? "bg-white text-primary" : "bg-white/20"}`}
              >
                3
              </div>
              <span className={step >= 3 ? "font-medium" : "opacity-70"}>Verify</span>
            </div>
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

        {/* Mobile Step Indicator */}
        <div className="flex items-center justify-center gap-2 px-6 pb-4 lg:hidden">
          <div className={`h-2 rounded-full transition-all ${step >= 1 ? "bg-primary w-8" : "bg-muted w-2"}`} />
          <div className={`h-2 rounded-full transition-all ${step >= 2 ? "bg-primary w-8" : "bg-muted w-2"}`} />
          <div className={`h-2 rounded-full transition-all ${step >= 3 ? "bg-primary w-8" : "bg-muted w-2"}`} />
        </div>

        <div className="flex-1 flex items-start justify-center p-6 overflow-y-auto">
          <div className="w-full max-w-md space-y-6">
            <div className="text-center lg:text-left">
              <h2 className="text-3xl font-bold mb-2">
                {step === 1 ? "Create Account" : step === 2 ? "Complete Your Profile" : "Verify Your Email"}
              </h2>
              <p className="text-muted-foreground">
                {step === 1 ? "Enter your details to get started" : step === 2 ? "Add your address and verification documents" : "Check your email for the verification code"}
              </p>
            </div>

            {error && step !== 3 && (
              <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                <Icon name="exclamation-circle" />
                {error}
              </div>
            )}

            <AnimatePresence mode="wait">
              {step === 1 && (
                <motion.form
                  key="step1"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  onSubmit={handleStep1Submit}
                  className="space-y-4"
                >
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="givenName">Given Name</Label>
                      <Input
                        id="givenName"
                        placeholder="Jane"
                        value={step1Data.givenName}
                        onChange={(e) => setStep1Data({ ...step1Data, givenName: e.target.value })}
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="surname">Surname</Label>
                      <Input
                        id="surname"
                        placeholder="Doe"
                        value={step1Data.surname}
                        onChange={(e) => setStep1Data({ ...step1Data, surname: e.target.value })}
                        required
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="email">Email</Label>
                    <div className="relative">
                      <Icon
                        name="envelope"
                        className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                      />
                      <Input
                        id="email"
                        type="email"
                        placeholder="you@example.com"
                        value={step1Data.email}
                        onChange={(e) => setStep1Data({ ...step1Data, email: e.target.value })}
                        className="pl-10"
                        required
                      />
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="password">Password</Label>
                    <div className="relative">
                      <Icon name="lock" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                      <Input
                        id="password"
                        type={showPassword ? "text" : "password"}
                        placeholder="Create a strong password"
                        value={step1Data.password}
                        onChange={(e) => setStep1Data({ ...step1Data, password: e.target.value })}
                        className="pl-10 pr-10"
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
                    <PasswordStrengthIndicator password={step1Data.password} />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="confirmPassword">Confirm Password</Label>
                    <Input
                      id="confirmPassword"
                      type="password"
                      placeholder="Confirm your password"
                      value={step1Data.confirmPassword}
                      onChange={(e) => setStep1Data({ ...step1Data, confirmPassword: e.target.value })}
                      required
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="contactNumber">Contact Number</Label>
                    <div className="relative">
                      <Icon
                        name="phone-call"
                        className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                      />
                      <Input
                        id="contactNumber"
                        type="tel"
                        placeholder="+63 912 345 6789"
                        value={step1Data.contactNumber}
                        onChange={(e) => setStep1Data({ ...step1Data, contactNumber: e.target.value })}
                        className="pl-10"
                        required
                      />
                    </div>
                  </div>

                  <div className="flex items-start gap-2">
                    <Checkbox
                      id="terms"
                      checked={step1Data.acceptTerms}
                      onCheckedChange={(checked) => setStep1Data({ ...step1Data, acceptTerms: checked as boolean })}
                    />
                    <label htmlFor="terms" className="text-sm text-muted-foreground leading-tight">
                      I agree to the{" "}
                      <Link href="/terms" className="text-primary hover:underline">
                        Terms of Service
                      </Link>{" "}
                      and{" "}
                      <Link href="/privacy" className="text-primary hover:underline">
                        Privacy Policy
                      </Link>
                    </label>
                  </div>

                  <Button type="submit" className="w-full" size="lg">
                    Continue
                    <Icon name="arrow-right" className="ml-2" />
                  </Button>
                </motion.form>
              )}

              {step === 2 && (
                <motion.form
                  key="step2"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  onSubmit={handleStep2Submit}
                  className="space-y-6"
                >
                  <div className="space-y-4">
                    <Label>Shipping Address</Label>
                    <AddressSelector
                      value={step2Data.address}
                      onChange={handleAddressChange}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label>Valid ID</Label>
                    <p className="text-sm text-muted-foreground mb-2">
                      Upload a clear photo of your government-issued ID for verification
                    </p>
                    <FileUploader
                      accept="image/*,.pdf"
                      onUpload={(file) => setStep2Data({ ...step2Data, validId: file })}
                      value={step2Data.validId}
                    />
                  </div>

                  <div className="flex gap-3">
                    <Button
                      type="button"
                      variant="outline"
                      className="flex-1 bg-transparent"
                      onClick={() => setStep(1)}
                    >
                      <Icon name="arrow-left" className="mr-2" />
                      Back
                    </Button>
                    <Button type="submit" className="flex-1" disabled={isLoading}>
                      {isLoading ? (
                        <>
                          <Icon name="spinner" className="mr-2 animate-spin" />
                          Creating...
                        </>
                      ) : (
                        "Create Account"
                      )}
                    </Button>
                  </div>
                </motion.form>
              )}

              {step === 3 && registeredEmail && (
                <motion.div
                  key="step3"
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="space-y-6"
                >
                  <div className="flex items-center gap-3 p-4 rounded-lg bg-muted/50">
                    <Icon name="envelope" className="text-primary" />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium truncate">{registeredEmail}</p>
                    </div>
                    {emailVerified && (
                      <Icon name="check-circle" className="text-green-500 shrink-0" />
                    )}
                  </div>

                  <EmailVerification
                    email={registeredEmail}
                    onVerified={handleEmailVerified}
                  />

                  {emailVerified && (
                    <Button className="w-full" size="lg" onClick={handleGoToLogin}>
                      Go to Login
                    </Button>
                  )}
                </motion.div>
              )}
            </AnimatePresence>

            {step < 3 && (
              <p className="text-center text-sm text-muted-foreground">
                Already have an account?{" "}
                <Link href="/auth/login?role=buyer" className="text-primary hover:underline font-medium">
                  Sign in
                </Link>
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
