"use client"

import type React from "react"

import { useState, useCallback, useEffect } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { PinInput } from "@/components/form/pin-input"
import { authApi } from "@/lib/api"

interface EmailVerificationProps {
  email: string
  onVerified: () => void
}

export function EmailVerification({ email, onVerified }: EmailVerificationProps) {
  const [isSending, setIsSending] = useState(false)
  const [isVerifying, setIsVerifying] = useState(false)
  const [error, setError] = useState("")
  const [resetKey, setResetKey] = useState(0)
  const [sent, setSent] = useState(false)

  const handleSendCode = useCallback(async () => {
    setError("")
    setIsSending(true)
    try {
      await authApi.sendVerificationCode(email)
      setSent(true)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Failed to send code"
      setError(msg)
    } finally {
      setIsSending(false)
    }
  }, [email])

  useEffect(() => {
    handleSendCode()
  }, [handleSendCode])

  const handleCodeComplete = useCallback(async (code: string) => {
    setError("")
    setIsVerifying(true)
    try {
      await authApi.verifyEmailCode(email, code)
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

  return (
    <div className="space-y-3">
      {sent ? (
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
      ) : (
        <div className="flex flex-col items-center gap-3">
          <Button
            type="button"
            variant="outline"
            onClick={handleSendCode}
            disabled={isSending}
          >
            {isSending ? (
              <>
                <Icon name="spinner" className="mr-2 animate-spin" />
                Sending...
              </>
            ) : (
              "Send verification code"
            )}
          </Button>
          {error && (
            <div className="p-2 rounded-lg bg-destructive/10 text-destructive text-xs flex items-center gap-2">
              <Icon name="exclamation-circle" />
              {error}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
