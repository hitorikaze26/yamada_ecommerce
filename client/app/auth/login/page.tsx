"use client"

import type React from "react"

import { useState, Suspense } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { motion } from "framer-motion"
import { useAuth } from "@/context/auth-context"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { DarkModeToggle } from "@/components/ui/dark-mode-toggle"
import type { UserRole } from "@/lib/types"
import { YamadaLogo } from "@/components/brand/yamada-logo"

const roleConfig: Record<UserRole, { title: string; description: string; color: string }> = {
  buyer: {
    title: "Buyer Login",
    description: "Shop the latest women's fashion",
    color: "bg-primary",
  },
  seller: {
    title: "Seller Portal",
    description: "Manage your shop and products",
    color: "bg-secondary",
  },
  rider: {
    title: "Rider Portal",
    description: "Manage your deliveries",
    color: "bg-secondary",
  },
  admin: {
    title: "Admin Portal",
    description: "Manage the platform",
    color: "bg-destructive",
  },
}

function LoginContent() {
  const searchParams = useSearchParams()
  const roleParam = (searchParams.get("role") as UserRole) || "buyer"
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState("")
  const { login, getLoginErrorMessage } = useAuth()
  const redirectTo = searchParams.get("redirect") ?? undefined
  const passwordResetSuccess = searchParams.get("reset") === "true"

  const config = roleConfig[roleParam]

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")
    setIsLoading(true)

    try {
      await login(email, password, roleParam, redirectTo)
    } catch (err) {
      setError(getLoginErrorMessage(err))
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex">
      {/* Left Panel - Branding */}
      <div className={`hidden lg:flex lg:w-1/2 ${config.color} relative overflow-hidden`}>
        <div className="absolute inset-0 bg-gradient-to-br from-transparent to-black/20" />
        <div className="relative z-10 flex flex-col justify-between p-12 text-white">
          <YamadaLogo size={48} href="/" showName />

          <div>
            <h1 className="text-4xl font-bold mb-4">{config.title}</h1>
            <p className="text-lg opacity-90">{config.description}</p>
          </div>

          {/* Role is now chosen from the route (e.g. ?role=buyer/seller/rider/admin)
              Landing page and navbar buttons link directly to the correct role. */}
        </div>
      </div>

      {/* Right Panel - Form */}
      <div className="flex-1 flex flex-col">
        <div className="flex justify-between items-center p-6">
          <div className="lg:hidden">
            <YamadaLogo size={40} href="/" />
          </div>
          <DarkModeToggle />
        </div>

        <div className="flex-1 flex items-center justify-center p-6">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="w-full max-w-md space-y-8"
          >
            <div className="text-center lg:text-left">
              <h2 className="text-3xl font-bold mb-2">Welcome back</h2>
              <p className="text-muted-foreground">Enter your credentials to access your account</p>
            </div>

            {/* Role selector removed: role is controlled externally via link destination. */}

            {passwordResetSuccess && (
              <div className="p-3 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200 text-sm flex items-center gap-2">
                <Icon name="check-circle" />
                Password reset successful. Sign in with your new password.
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
              {error && (
                <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
                  <Icon name="exclamation-circle" />
                  {error}
                </div>
              )}

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
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

              <div className="space-y-2">
                <div className="flex justify-between">
                  <Label htmlFor="password">Password</Label>
                  <Link href="/auth/forgot-password" className="text-sm text-primary hover:underline">
                    Forgot password?
                  </Link>
                </div>
                <div className="relative">
                  <Icon name="lock" className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    id="password"
                    type={showPassword ? "text" : "password"}
                    placeholder="Enter your password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="pl-10 pr-10"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                    aria-label={showPassword ? "Hide password" : "Show password"}
                  >
                    <Icon name={showPassword ? "eye-crossed" : "eye"} />
                  </button>
                </div>
              </div>

              <Button type="submit" className="w-full" size="lg" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Icon name="spinner" className="mr-2 animate-spin" />
                    Signing in...
                  </>
                ) : (
                  "Sign In"
                )}
              </Button>
            </form>

            {roleParam === "buyer" && (
              <p className="text-center text-sm text-muted-foreground">
                Don&apos;t have an account?{" "}
                <Link href="/auth/register/buyer" className="text-primary hover:underline font-medium">
                  Create account
                </Link>
              </p>
            )}

            {roleParam === "seller" && (
              <p className="text-center text-sm text-muted-foreground">
                Want to sell on Yamada?{" "}
                <Link href="/auth/register/seller" className="text-primary hover:underline font-medium">
                  Apply as seller
                </Link>
              </p>
            )}

            {roleParam === "rider" && (
              <p className="text-center text-sm text-muted-foreground">
                Want to deliver for Yamada?{" "}
                <Link href="/auth/register/rider" className="text-primary hover:underline font-medium">
                  Apply as rider
                </Link>
              </p>
            )}
          </motion.div>
        </div>
      </div>
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen flex items-center justify-center">
          <Icon name="spinner" className="animate-spin text-primary" size="xl" />
        </div>
      }
    >
      <LoginContent />
    </Suspense>
  )
}
