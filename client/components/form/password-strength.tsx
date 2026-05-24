"use client"

import { useMemo } from "react"

interface PasswordStrengthIndicatorProps {
  password: string
}

export function PasswordStrengthIndicator({ password }: PasswordStrengthIndicatorProps) {
  const strength = useMemo(() => {
    if (!password) return { score: 0, label: "", color: "" }

    let score = 0

    // Length checks
    if (password.length >= 8) score++
    if (password.length >= 12) score++

    // Character variety checks
    if (/[a-z]/.test(password)) score++
    if (/[A-Z]/.test(password)) score++
    if (/[0-9]/.test(password)) score++
    if (/[^a-zA-Z0-9]/.test(password)) score++

    // Determine strength level
    if (score <= 2) return { score: 1, label: "Weak", color: "bg-destructive" }
    if (score <= 4) return { score: 2, label: "Fair", color: "bg-yellow-500" }
    if (score <= 5) return { score: 3, label: "Good", color: "bg-blue-500" }
    return { score: 4, label: "Strong", color: "bg-green-500" }
  }, [password])

  if (!password) return null

  return (
    <div className="space-y-1">
      <div className="flex gap-1">
        {[1, 2, 3, 4].map((level) => (
          <div
            key={level}
            className={`h-1 flex-1 rounded-full transition-all ${
              level <= strength.score ? strength.color : "bg-muted"
            }`}
          />
        ))}
      </div>
      <p className={`text-xs ${strength.color.replace("bg-", "text-")}`}>{strength.label} password</p>
    </div>
  )
}
