"use client"

import type React from "react"

import { useState, Suspense } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { PinInput } from "@/components/form/pin-input"
import { PasswordStrengthIndicator } from "@/components/form/password-strength"
import { YamadaLogo } from "@/components/brand/yamada-logo"
import { authApi } from "@/lib/api"

function ResetPinContent() {
  const searchParams = useSearchParams()
  const email = searchParams.get("email") || ""
  const router = useRouter()

  const [step, setStep] = useState<"pin" | "password">("pin")
  const [pin, setPin] = useState("")
  const [pinResetKey, setPinResetKey] = useState(0)
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [isResending, setIsResending] = useState(false)
  const [error, setError] = useState("")
  const [resendMessage, setResendMessage] = useState("")
  const [showPassword, setShowPassword] = useState(false)

  const handlePinComplete = async (completedPin: string) => {
    setPin(completedPin)
    setError("")
    setResendMessage("")
    setIsLoading(true)

    try {
      await authApi.verifyPin(email, completedPin)
      setStep("password")
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Invalid PIN. Please try again."
      setError(msg)
      setPinResetKey((k) => k + 1)
    } finally {
      setIsLoading(false)
    }
  }

  const handleResend = async () => {
    if (!email.trim()) return
    setError("")
    setResendMessage("")
    setIsResending(true)
    try {
      await authApi.forgotPassword({ channel: "email", email: email.trim() })
      setResendMessage("A new code was sent to your email.")
      setPinResetKey((k) => k + 1)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Failed to resend code. Please try again."
      setError(msg)
    } finally {
      setIsResending(false)
    }
  }

  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault()

    if (password.length < 8) {
      setError("Password must be at least 8 characters")
      return
    }

    if (password !== confirmPassword) {
      setError("Passwords do not match")
      return
    }

    setError("")
    setIsLoading(true)

    try {
      await authApi.resetPassword(email, pin, password)
      router.push("/auth/login?role=buyer&reset=true")
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Failed to reset password. Please try again."
      setError(msg)
    } finally {
      setIsLoading(false)
    }
  }

  if (!email.trim()) {
    return (
      <div className="min-h-screen flex flex-col">
        <div className="flex justify-between items-center p-6">
          <YamadaLogo size={40} href="/" />
          <DarkModeToggle />
        </div>
        <div className="flex-1 flex items-center justify-center p-6">
          <div className="w-full max-w-md text-center space-y-6">
            <Icon name="exclamation-circle" size="xl" className="mx-auto text-destructive" />
            <h2 className="text-2xl font-bold">Email required</h2>
            <p className="text-muted-foreground">
              Start from the forgot password page so we can send you a reset code.
            </p>
            <Button asChild className="w-full">
              <Link href="/auth/forgot-password">Go to forgot password</Link>
            </Button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col">
      <div className="flex justify-between items-center p-6">
        <YamadaLogo size={40} href="/" />
        <DarkModeToggle />
      </div>

      <div className="flex-1 flex items-center justify-center p-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="w-full max-w-md space-y-8"
        >
          {step === "pin" ? (
            <>
              <div className="text-center">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                  <Icon name="key" size="xl" className="text-primary" />
                </div>
                <h2 className="text-3xl font-bold mb-2">Enter PIN</h2>
                <p className="text-muted-foreground">
                  Enter the 6-digit PIN sent to <strong>{email}</strong>
                </p>
              </div>

              {error && (
                <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                  <Icon name="exclamation-circle" />
                  {error}
                </div>
              )}

              {resendMessage && (
                <div className="p-3 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 text-sm flex items-center gap-2">
                  <Icon name="check-circle" />
                  {resendMessage}
                </div>
              )}

              <div className="flex justify-center">
                <PinInput
                  length={6}
                  onComplete={handlePinComplete}
                  disabled={isLoading}
                  resetKey={pinResetKey}
                />
              </div>

              {isLoading && (
                <div className="flex justify-center">
                  <Icon name="spinner" className="animate-spin text-primary" size="lg" />
                </div>
              )}

              <p className="text-center text-sm text-muted-foreground">
                Didn&apos;t receive the PIN?{" "}
                <button
                  type="button"
                  onClick={handleResend}
                  disabled={isResending || isLoading}
                  className="text-primary hover:underline font-medium disabled:opacity-50"
                >
                  {isResending ? "Sending..." : "Resend"}
                </button>
              </p>
            </>
          ) : (
            <>
              <div className="text-center">
                <div className="w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center mx-auto mb-4">
                  <Icon name="check" size="xl" className="text-green-600 dark:text-green-400" />
                </div>
                <h2 className="text-3xl font-bold mb-2">Reset Password</h2>
                <p className="text-muted-foreground">PIN verified! Create your new password.</p>
              </div>

              {error && (
                <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                  <Icon name="exclamation-circle" />
                  {error}
                </div>
              )}

              <form onSubmit={handlePasswordReset} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="password">New Password</Label>
                  <div className="relative">
                    <Input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      placeholder="Create a strong password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
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
                  <PasswordStrengthIndicator password={password} />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="confirmPassword">Confirm Password</Label>
                  <Input
                    id="confirmPassword"
                    type="password"
                    placeholder="Confirm your new password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                  />
                </div>

                <Button type="submit" className="w-full" size="lg" disabled={isLoading}>
                  {isLoading ? (
                    <>
                      <Icon name="spinner" className="mr-2 animate-spin" />
                      Resetting...
                    </>
                  ) : (
                    "Reset Password"
                  )}
                </Button>
              </form>
            </>
          )}

          <p className="text-center text-sm text-muted-foreground">
            <Link href="/auth/login?role=buyer" className="text-primary hover:underline font-medium">
              Back to Sign In
            </Link>
          </p>
        </motion.div>
      </div>
    </div>
  )
}

export default function ResetPinPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center">
          <Icon name="spinner" className="animate-spin text-primary" size="xl" />
        </div>
      }
    >
      <ResetPinContent />
    </Suspense>
  )
}
