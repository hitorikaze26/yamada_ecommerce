"use client"

import { useMemo, useState, useRef } from "react"
import { Icon } from "@/components/ui/icon"

interface ReportTypeOption {
  id: number
  typeKey: string
  displayName: string
  category?: string
}

const CATEGORY_LABELS: Record<string, string> = {
  fraud: "Fraud",
  harassment: "Harassment",
  spam: "Spam",
  misconduct: "Misconduct",
  safety: "Safety",
  inappropriate_content: "Inappropriate content",
  other: "Other",
}

interface ReportFormProps {
  reportTypes: ReportTypeOption[]
  onSubmit: (data: FormData) => Promise<void>
  submitLabel?: string
  descriptionPlaceholder?: string
  showTargetUser?: boolean
  loading?: boolean
}

export function ReportForm({
  reportTypes,
  onSubmit,
  submitLabel = "Submit Report",
  descriptionPlaceholder = "Describe the issue in detail...",
  loading: externalLoading,
}: ReportFormProps) {
  const [selectedTypeId, setSelectedTypeId] = useState<number | null>(null)
  const [description, setDescription] = useState("")
  const [files, setFiles] = useState<File[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState("")
  const fileInputRef = useRef<HTMLInputElement>(null)

  const isLoading = submitting || externalLoading

  const groupedTypes = useMemo(() => {
    const map = new Map<string, ReportTypeOption[]>()
    for (const rt of reportTypes) {
      const key = rt.category || "other"
      if (!map.has(key)) map.set(key, [])
      map.get(key)!.push(rt)
    }
    return Array.from(map.entries())
  }, [reportTypes])

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selected = Array.from(e.target.files || [])
    const images = selected.filter((f) => f.type.startsWith("image/"))
    setFiles((prev) => [...prev, ...images].slice(0, 5))
  }

  const removeFile = (index: number) => {
    setFiles((prev) => prev.filter((_, i) => i !== index))
  }

  const handleSubmit = async () => {
    setError("")

    if (!selectedTypeId) {
      setError("Please select an issue type")
      return
    }
    if (description.trim().length < 10) {
      setError("Please provide at least 10 characters")
      return
    }

    setSubmitting(true)
    try {
      const formData = new FormData()
      formData.append("reportTypeId", String(selectedTypeId))
      formData.append("description", description.trim())
      files.forEach((f) => formData.append("evidence", f))

      await onSubmit(formData)
    } catch (err: unknown) {
      const axiosMsg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      setError(axiosMsg || (err instanceof Error ? err.message : "Failed to submit report"))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <label className="text-sm font-medium mb-2 block">What&apos;s the issue?</label>
        {reportTypes.length === 0 ? (
          <p className="text-sm text-muted-foreground">No report types available. Contact support.</p>
        ) : (
          <div className="space-y-4">
            {groupedTypes.map(([category, types]) => (
              <div key={category}>
                {groupedTypes.length > 1 && (
                  <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">
                    {CATEGORY_LABELS[category] ?? category}
                  </p>
                )}
                <div className="flex flex-wrap gap-2">
                  {types.map((rt) => (
                    <button
                      key={rt.id}
                      type="button"
                      onClick={() => setSelectedTypeId(rt.id)}
                      className={`px-4 py-2 rounded-full text-sm font-medium border transition-all ${
                        selectedTypeId === rt.id
                          ? "bg-primary text-primary-foreground border-primary shadow-sm"
                          : "bg-card text-muted-foreground border-muted-foreground/20 hover:border-primary/50 hover:text-foreground"
                      }`}
                    >
                      {rt.displayName}
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div>
        <label htmlFor="desc" className="text-sm font-medium mb-2 block">
          Description
        </label>
        <textarea
          id="desc"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder={descriptionPlaceholder}
          rows={5}
          maxLength={2000}
          className="w-full border rounded-xl px-4 py-3 text-sm bg-background resize-y focus:outline-none focus:ring-2 focus:ring-primary/30"
        />
        <p className="text-xs text-muted-foreground mt-1 text-right">
          {description.length}/2000
        </p>
      </div>

      <div>
        <label className="text-sm font-medium mb-2 block">
          Upload Evidence <span className="text-muted-foreground font-normal">(optional - up to 5 images)</span>
        </label>

        <div
          onClick={() => fileInputRef.current?.click()}
          className="border-2 border-dashed border-muted-foreground/30 rounded-xl p-6 text-center cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-colors"
        >
          <Icon name="image" className="mx-auto text-muted-foreground mb-2" />
          <p className="text-sm text-muted-foreground">
            Click to upload screenshots
          </p>
          <p className="text-xs text-muted-foreground/60 mt-1">
            PNG, JPG, GIF, WebP
          </p>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={handleFileSelect}
            className="hidden"
          />
        </div>

        {files.length > 0 && (
          <div className="flex flex-wrap gap-3 mt-3">
            {files.map((f, i) => (
              <div key={i} className="relative group">
                <img
                  src={URL.createObjectURL(f) || "/placeholder.svg"}
                  alt={f.name}
                  className="w-20 h-20 object-cover rounded-lg border"
                />
                <button
                  type="button"
                  onClick={() => removeFile(i)}
                  className="absolute -top-2 -right-2 w-5 h-5 bg-destructive text-destructive-foreground rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {error && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-xl px-4 py-3 text-sm">
          {error}
        </div>
      )}

      <button
        type="button"
        onClick={() => void handleSubmit()}
        disabled={isLoading}
        className="w-full py-3 rounded-xl bg-primary text-primary-foreground font-medium hover:bg-primary/90 disabled:opacity-50 transition-colors"
      >
        {isLoading ? (
          <span className="flex items-center justify-center gap-2">
            <span className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
            Submitting...
          </span>
        ) : (
          submitLabel
        )}
      </button>
    </div>
  )
}
