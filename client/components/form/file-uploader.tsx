"use client"

import type React from "react"

import { useEffect, useMemo, useRef, useState } from "react"
import { Icon } from "@/components/ui/icon"
import { Button } from "@/components/ui/button"

interface FileUploaderProps {
  accept?: string
  onUpload: (file: File | null) => void
  value: File | null
  maxSize?: number // in MB
}

export function FileUploader({ accept = "image/*,.pdf", onUpload, value, maxSize = 5 }: FileUploaderProps) {
  const [isDragging, setIsDragging] = useState(false)
  const [error, setError] = useState("")
  const inputRef = useRef<HTMLInputElement>(null)

  const previewUrl = useMemo(() => {
    if (!value || !value.type.startsWith("image/")) return null
    return URL.createObjectURL(value)
  }, [value])

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl)
    }
  }, [previewUrl])

  const validateFile = (file: File): boolean => {
    if (file.size > maxSize * 1024 * 1024) {
      setError(`File size must be less than ${maxSize}MB`)
      return false
    }

    const acceptedTypes = accept.split(",").map((t) => t.trim())
    const fileType = file.type
    const fileExtension = `.${file.name.split(".").pop()?.toLowerCase()}`

    const isAccepted = acceptedTypes.some((type) => {
      if (type.startsWith(".")) {
        return fileExtension === type
      }
      if (type.endsWith("/*")) {
        const prefix = type.replace("/*", "/")
        return fileType.startsWith(prefix) || (fileType === "" && fileExtension.match(/\.(png|jpe?g|webp|gif)$/))
      }
      return fileType === type
    })

    if (!isAccepted) {
      setError("Invalid file type")
      return false
    }

    setError("")
    return true
  }

  const handleFile = (file: File) => {
    if (validateFile(file)) {
      onUpload(file)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(false)

    const file = e.dataTransfer.files[0]
    if (file) {
      handleFile(file)
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    setIsDragging(true)
  }

  const handleDragLeave = () => {
    setIsDragging(false)
  }

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      handleFile(file)
    }
  }

  const handleRemove = () => {
    onUpload(null)
    if (inputRef.current) {
      inputRef.current.value = ""
    }
  }

  return (
    <div className="space-y-2">
      {!value ? (
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onClick={() => inputRef.current?.click()}
          className={`relative w-full cursor-pointer transition-all duration-300
            rounded-3xl border-2 border-dashed px-8 py-7 text-center shadow-[0_0_80px_rgba(0,0,0,0.08)]
            bg-muted/60 hover:bg-muted ${
              isDragging ? "border-primary bg-primary/10" : "border-border hover:border-primary/70"
            }`}
        >
          <input ref={inputRef} type="file" accept={accept} onChange={handleInputChange} className="hidden" />

          <div className="flex flex-col items-center justify-center gap-2">
            <div className="flex items-center justify-center mb-2">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-background">
                <Icon name="cloud-upload-alt" size="xl" className="text-muted-foreground" />
              </div>
            </div>

            <p className="text-base font-semibold text-foreground">Drag and Drop</p>
            <p className="text-sm text-muted-foreground">or</p>
            <button
              type="button"
              className="mt-1 rounded-xl bg-foreground px-4 py-1.5 text-xs font-medium text-background shadow-sm transition-colors hover:bg-foreground/90"
            >
              Browse file
            </button>

            <p className="mt-2 text-xs text-muted-foreground">
              {accept.includes("image") && accept.includes("pdf")
                ? "PNG, JPG, or PDF"
                : accept.includes("image")
                  ? "PNG or JPG"
                  : "PDF"}
              {` · Max ${maxSize}MB`}
            </p>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          {previewUrl && (
            <div className="relative overflow-hidden rounded-xl border border-border bg-muted/40">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={previewUrl}
                alt={`Preview of ${value.name}`}
                className="max-h-48 w-full object-contain"
              />
            </div>
          )}
          <div className="flex items-center gap-3 p-3 bg-muted rounded-xl">
            <div className="w-10 h-10 rounded-lg bg-background flex items-center justify-center overflow-hidden">
              {previewUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={previewUrl} alt="" className="h-full w-full object-cover" />
              ) : value.type.startsWith("image/") ? (
                <Icon name="image" className="text-primary" />
              ) : (
                <Icon name="file-pdf" className="text-destructive" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-medium text-sm truncate">{value.name}</p>
              <p className="text-xs text-muted-foreground">{(value.size / 1024).toFixed(1)} KB</p>
            </div>
            <Button type="button" variant="ghost" size="icon" onClick={handleRemove} className="flex-shrink-0">
              <Icon name="cross" />
              <span className="sr-only">Remove file</span>
            </Button>
          </div>
        </div>
      )}

      {error && (
        <p className="text-sm text-destructive flex items-center gap-1">
          <Icon name="exclamation-circle" size="sm" />
          {error}
        </p>
      )}
    </div>
  )
}
