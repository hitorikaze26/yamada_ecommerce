"use client"

import type React from "react"

import { useState, useRef, useEffect } from "react"

interface PinInputProps {
  length?: number
  onComplete: (pin: string) => void
  disabled?: boolean
}

export function PinInput({ length = 6, onComplete, disabled = false }: PinInputProps) {
  const [values, setValues] = useState<string[]>(Array(length).fill(""))
  const inputRefs = useRef<(HTMLInputElement | null)[]>([])

  useEffect(() => {
    // Focus first input on mount
    inputRefs.current[0]?.focus()
  }, [])

  const handleChange = (index: number, value: string) => {
    // Only allow digits
    if (value && !/^\d$/.test(value)) return

    const newValues = [...values]
    newValues[index] = value
    setValues(newValues)

    // Move to next input
    if (value && index < length - 1) {
      inputRefs.current[index + 1]?.focus()
    }

    // Check if complete
    if (newValues.every((v) => v !== "")) {
      onComplete(newValues.join(""))
    }
  }

  const handleKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    // Handle backspace
    if (e.key === "Backspace" && !values[index] && index > 0) {
      inputRefs.current[index - 1]?.focus()
    }

    // Handle arrow keys
    if (e.key === "ArrowLeft" && index > 0) {
      inputRefs.current[index - 1]?.focus()
    }
    if (e.key === "ArrowRight" && index < length - 1) {
      inputRefs.current[index + 1]?.focus()
    }
  }

  const handlePaste = (e: React.ClipboardEvent) => {
    e.preventDefault()
    const pastedData = e.clipboardData.getData("text").slice(0, length)

    if (!/^\d+$/.test(pastedData)) return

    const newValues = [...values]
    pastedData.split("").forEach((char, i) => {
      if (i < length) newValues[i] = char
    })
    setValues(newValues)

    // Focus the next empty input or the last one
    const nextEmptyIndex = newValues.findIndex((v) => v === "")
    inputRefs.current[nextEmptyIndex === -1 ? length - 1 : nextEmptyIndex]?.focus()

    // Check if complete
    if (newValues.every((v) => v !== "")) {
      onComplete(newValues.join(""))
    }
  }

  return (
    <div className="flex gap-3" onPaste={handlePaste}>
      {values.map((value, index) => (
        <input
          key={index}
          ref={(el) => {
            inputRefs.current[index] = el
          }}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={value}
          onChange={(e) => handleChange(index, e.target.value)}
          onKeyDown={(e) => handleKeyDown(index, e)}
          disabled={disabled}
          className="w-12 h-14 text-center text-2xl font-semibold border-2 rounded-xl bg-background transition-all focus:border-primary focus:ring-2 focus:ring-primary/20 outline-none disabled:opacity-50"
          aria-label={`PIN digit ${index + 1}`}
        />
      ))}
    </div>
  )
}
