"use client"

import type React from "react"
import { useState } from "react"
import Link from "next/link"
import { useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import { YamadaLogo } from "@/components/brand/yamada-logo"
import { authApi } from "@/lib/api"

export default function ForgotPasswordPage() {
  const searchParams = useSearchParams()
  const [email, setEmail] = useState("")
  const [accountEmail, setAccountEmail] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [isSubmitted, setIsSubmitted] = useState(false)
  const [error, setError] = useState("")

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim()) {
      setError("Please enter your email address")
      return
    }

    setError("")
    setIsLoading(true)

    try {
      const res = await authApi.forgotPassword({
        channel: "email",
        email: email.trim(),
      })
      setAccountEmail(res.data.email ?? email.trim())
      setIsSubmitted(true)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg ??
        "Failed to send reset code. Please try again."
      setError(msg)
    } finally {
      setIsLoading(false)
    }
  }

  const resetEmail = accountEmail || email.trim()
  const role = (searchParams.get("role") || "buyer").toLowerCase()
  const loginHref = `/auth/login?role=${encodeURIComponent(role)}`

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
          {!isSubmitted ? (
            <>
              <div className="text-center">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                  <Icon name="lock" size="xl" className="text-primary" />
                </div>
                <h2 className="text-3xl font-bold mb-2">Forgot Password?</h2>
                <p className="text-muted-foreground">Enter your email to receive a 6-digit reset code.</p>
              </div>

              <p className="text-xs text-center text-muted-foreground bg-muted/50 rounded-lg px-3 py-2">
                SMS reset is coming soon — please use email for now.
              </p>

              {error && (
                <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                  <Icon name="exclamation-circle" />
                  {error}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="email">Email address</Label>
                  <div className="relative">
                    <Icon name="envelope" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                    <Input
                      id="email"
                      type="email"
                      placeholder="you@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="pl-10"
                      required
                    />
                  </div>
                </div>

                <Button type="submit" className="w-full" disabled={isLoading}>
                  {isLoading ? "Sending..." : "Send reset code"}
                </Button>
              </form>

              <p className="text-center text-sm text-muted-foreground">
                Remember your password?{" "}
                <Link href={loginHref} className="text-primary hover:underline font-medium">
                  Sign in
                </Link>
              </p>
            </>
          ) : (
            <div className="text-center space-y-6">
              <div className="w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center mx-auto">
                <Icon name="check-circle" size="xl" className="text-green-600 dark:text-green-400" />
              </div>
              <h2 className="text-2xl font-bold">Check your email</h2>
              <p className="text-muted-foreground">
                If an account exists for <strong>{resetEmail}</strong>, we sent a 6-digit code.
              </p>
              <Button asChild className="w-full">
                <Link href={`/auth/reset-pin?email=${encodeURIComponent(resetEmail)}&channel=email`}>
                  Enter reset code
                </Link>
              </Button>
              <Link href={loginHref} className="text-sm text-primary hover:underline">
                Back to sign in
              </Link>
            </div>
          )}
        </motion.div>
      </div>
    </div>
  )
}
