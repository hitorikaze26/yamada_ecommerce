"use client"

import type React from "react"

import { useState, useCallback } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { PinInput } from "@/components/form/pin-input"
import { authApi } from "@/lib/api"

interface EmailVerificationProps {
  email: string
  onVerified: () => void
}

export function EmailVerification({ email, onVerified }: EmailVerificationProps) {
  const [step, setStep] = useState<"send" | "input" | "verified">("send")
  const [isSending, setIsSending] = useState(false)
  const [isVerifying, setIsVerifying] = useState(false)
  const [error, setError] = useState("")
  const [resetKey, setResetKey] = useState(0)

  const handleSendCode = useCallback(async () => {
    setError("")
    setIsSending(true)
    try {
      await authApi.sendVerificationCode(email)
      setStep("input")
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Failed to send code"
      setError(msg)
    } finally {
      setIsSending(false)
    }
  }, [email])

  const handleCodeComplete = useCallback(async (code: string) => {
    setError("")
    setIsVerifying(true)
    try {
      await authApi.verifyEmailCode(email, code)
      setStep("verified")
      onVerified()
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Invalid code"
      setError(msg)
      setResetKey((k) => k + 1)
    } finally {
      setIsVerifying(false)
    }
  }, [email, onVerified])

  if (step === "verified") {
    return (
      <div className="flex items-center gap-2 text-green-600 dark:text-green-400 text-sm">
        <Icon name="check-circle" />
        <span>Email verified</span>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {step === "send" ? (
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={handleSendCode}
          disabled={isSending}
        >
          {isSending ? (
            <>
              <Icon name="spinner" className="mr-2 animate-spin" />
              Sending...
            </>
          ) : (
            "Verify email"
          )}
        </Button>
      ) : (
        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">
            Enter the 6-digit code sent to <strong>{email}</strong>
          </p>
          {error && (
            <div className="p-2 rounded-lg bg-destructive/10 text-destructive text-xs flex items-center gap-2">
              <Icon name="exclamation-circle" />
              {error}
            </div>
          )}
          <div className="flex justify-center">
            <PinInput
              length={6}
              onComplete={handleCodeComplete}
              disabled={isVerifying}
              resetKey={resetKey}
            />
          </div>
          {isVerifying && (
            <div className="flex justify-center">
              <Icon name="spinner" className="animate-spin text-primary" size="lg" />
            </div>
          )}
          <div className="flex gap-2 justify-center">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={handleSendCode}
              disabled={isSending || isVerifying}
            >
              {isSending ? "Sending..." : "Resend code"}
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
