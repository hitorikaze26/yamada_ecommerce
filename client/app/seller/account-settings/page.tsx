"use client"
import { useState } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/context/auth-context"
import { sellerAccountApi } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

// ── Types ─────────────────────────────────────────────────────────────────────

type Section = "change-password" | "change-email" | "contact" | "delete" | null

// ── Helpers ───────────────────────────────────────────────────────────────────

function SectionCard({
  title,
  description,
  icon,
  iconBg,
  onClick,
}: {
  title: string
  description: string
  icon: string
  iconBg: string
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full flex items-center gap-4 p-4 rounded-2xl border bg-card hover:bg-muted/40 transition-colors text-left group"
    >
      <div className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        <Icon name={icon} className="text-white" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="font-semibold text-sm">{title}</p>
        <p className="text-xs text-muted-foreground mt-0.5">{description}</p>
      </div>
      <Icon name="chevron-right" className="text-muted-foreground group-hover:text-foreground transition-colors" size="sm" />
    </button>
  )
}

function FormField({
  label,
  type = "text",
  value,
  onChange,
  placeholder,
  hint,
  showToggle,
  onToggle,
  show,
}: {
  label: string
  type?: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
  hint?: string
  showToggle?: boolean
  onToggle?: () => void
  show?: boolean
}) {
  const inputType = showToggle ? (show ? "text" : "password") : type
  return (
    <div className="space-y-1.5">
      <label className="block text-sm font-medium">{label}</label>
      <div className="relative">
        <input
          type={inputType}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full px-4 py-2.5 rounded-xl border bg-background focus:ring-2 focus:ring-primary focus:border-transparent outline-none text-sm pr-10"
        />
        {showToggle && (
          <button
            type="button"
            onClick={onToggle}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
          >
            <Icon name={show ? "eye-crossed" : "eye"} size="sm" />
          </button>
        )}
      </div>
      {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
    </div>
  )
}

// ── Main page ─────────────────────────────────────────────────────────────────

export default function AccountSettingsPage() {
  const router = useRouter()
  const { logout } = useAuth()
  const [activeSection, setActiveSection] = useState<Section>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  // ── Change Password state ─────────────────────────────────────────────────
  const [currentPw, setCurrentPw] = useState("")
  const [newPw, setNewPw] = useState("")
  const [confirmPw, setConfirmPw] = useState("")
  const [showCurrentPw, setShowCurrentPw] = useState(false)
  const [showNewPw, setShowNewPw] = useState(false)
  const [showConfirmPw, setShowConfirmPw] = useState(false)

  // ── Change Email state ────────────────────────────────────────────────────
  const [newEmail, setNewEmail] = useState("")
  const [emailPw, setEmailPw] = useState("")
  const [showEmailPw, setShowEmailPw] = useState(false)

  // ── Contact state ─────────────────────────────────────────────────────────
  const [contact, setContact] = useState("")

  // ── Delete Account state ──────────────────────────────────────────────────
  const [deletePw, setDeletePw] = useState("")
  const [showDeletePw, setShowDeletePw] = useState(false)
  const [deleteConfirmed, setDeleteConfirmed] = useState(false)

  // ── Helpers ───────────────────────────────────────────────────────────────

  const resetFeedback = () => {
    setError(null)
    setSuccess(null)
  }

  const openSection = (s: Section) => {
    resetFeedback()
    setActiveSection(s)
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  const handleChangePassword = async () => {
    resetFeedback()
    if (!currentPw || !newPw || !confirmPw) {
      setError("Please fill in all fields.")
      return
    }
    if (newPw.length < 6) {
      setError("New password must be at least 6 characters.")
      return
    }
    if (newPw !== confirmPw) {
      setError("New passwords do not match.")
      return
    }
    setSaving(true)
    try {
      await sellerAccountApi.changePassword({ currentPassword: currentPw, newPassword: newPw })
      setSuccess("Password changed successfully.")
      setCurrentPw(""); setNewPw(""); setConfirmPw("")
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to change password.")
    } finally {
      setSaving(false)
    }
  }

  const handleChangeEmail = async () => {
    resetFeedback()
    if (!newEmail || !emailPw) {
      setError("Please fill in all fields.")
      return
    }
    if (!newEmail.includes("@")) {
      setError("Enter a valid email address.")
      return
    }
    setSaving(true)
    try {
      await sellerAccountApi.changeEmail({ newEmail: newEmail.trim(), password: emailPw })
      setSuccess("Email changed successfully. Please log in again.")
      setNewEmail(""); setEmailPw("")
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to change email.")
    } finally {
      setSaving(false)
    }
  }

  const handleUpdateContact = async () => {
    resetFeedback()
    if (!contact.trim()) {
      setError("Please enter a contact number.")
      return
    }
    setSaving(true)
    try {
      await sellerAccountApi.updateContact(contact.trim())
      setSuccess("Contact number updated successfully.")
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to update contact number.")
    } finally {
      setSaving(false)
    }
  }

  const handleDeleteAccount = async () => {
    resetFeedback()
    if (!deletePw) {
      setError("Please enter your password to confirm.")
      return
    }
    if (!deleteConfirmed) {
      setError("Please check the confirmation checkbox.")
      return
    }
    setSaving(true)
    try {
      await sellerAccountApi.deleteAccount(deletePw)
      await logout()
      router.push("/")
    } catch (err: any) {
      setError(err?.response?.data?.msg || "Failed to delete account.")
      setSaving(false)
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold">Account Settings</h1>
        <p className="text-muted-foreground mt-1">
          Manage your security, contact info, and account.
        </p>
      </div>

      {/* Feedback */}
      {success && (
        <div className="flex items-center gap-3 p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm">
          <Icon name="check-circle" className="text-emerald-600 flex-shrink-0" size="sm" />
          <span>{success}</span>
          <button type="button" onClick={() => setSuccess(null)} className="ml-auto text-emerald-700 hover:text-emerald-900">
            <Icon name="times" size="sm" />
          </button>
        </div>
      )}
      {error && (
        <div className="flex items-center gap-3 p-4 rounded-2xl bg-red-50 border border-red-200 text-red-700 text-sm">
          <Icon name="exclamation-circle" className="text-red-500 flex-shrink-0" size="sm" />
          <span>{error}</span>
          <button type="button" onClick={() => setError(null)} className="ml-auto text-red-600 hover:text-red-800">
            <Icon name="times" size="sm" />
          </button>
        </div>
      )}

      {/* ── Security section ─────────────────────────────────────────────── */}
      <div className="space-y-3">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide px-1">
          Security
        </h2>

        {/* Change Password */}
        <div className="rounded-2xl border bg-card overflow-hidden">
          <SectionCard
            title="Change Password"
            description="Update your account password"
            icon="lock"
            iconBg="bg-primary"
            onClick={() => openSection(activeSection === "change-password" ? null : "change-password")}
          />
          {activeSection === "change-password" && (
            <div className="px-5 pb-5 pt-2 border-t space-y-4">
              <FormField
                label="Current Password"
                value={currentPw}
                onChange={setCurrentPw}
                placeholder="Enter current password"
                showToggle
                show={showCurrentPw}
                onToggle={() => setShowCurrentPw((v) => !v)}
              />
              <FormField
                label="New Password"
                value={newPw}
                onChange={setNewPw}
                placeholder="At least 6 characters"
                hint="Minimum 6 characters"
                showToggle
                show={showNewPw}
                onToggle={() => setShowNewPw((v) => !v)}
              />
              <FormField
                label="Confirm New Password"
                value={confirmPw}
                onChange={setConfirmPw}
                placeholder="Re-enter new password"
                showToggle
                show={showConfirmPw}
                onToggle={() => setShowConfirmPw((v) => !v)}
              />
              <button
                type="button"
                onClick={handleChangePassword}
                disabled={saving}
                className="w-full py-2.5 px-4 bg-primary text-primary-foreground rounded-xl font-medium text-sm hover:bg-primary/90 disabled:opacity-60 transition-colors"
              >
                {saving ? "Saving…" : "Change Password"}
              </button>
            </div>
          )}
        </div>

        {/* Change Email */}
        <div className="rounded-2xl border bg-card overflow-hidden">
          <SectionCard
            title="Change Email"
            description="Update your login email address"
            icon="envelope"
            iconBg="bg-blue-500"
            onClick={() => openSection(activeSection === "change-email" ? null : "change-email")}
          />
          {activeSection === "change-email" && (
            <div className="px-5 pb-5 pt-2 border-t space-y-4">
              <FormField
                label="New Email Address"
                type="email"
                value={newEmail}
                onChange={setNewEmail}
                placeholder="e.g., newemail@example.com"
              />
              <FormField
                label="Confirm with Password"
                value={emailPw}
                onChange={setEmailPw}
                placeholder="Enter your current password"
                showToggle
                show={showEmailPw}
                onToggle={() => setShowEmailPw((v) => !v)}
              />
              <button
                type="button"
                onClick={handleChangeEmail}
                disabled={saving}
                className="w-full py-2.5 px-4 bg-blue-500 text-white rounded-xl font-medium text-sm hover:bg-blue-600 disabled:opacity-60 transition-colors"
              >
                {saving ? "Saving…" : "Change Email"}
              </button>
            </div>
          )}
        </div>

        {/* Contact Information */}
        <div className="rounded-2xl border bg-card overflow-hidden">
          <SectionCard
            title="Contact Information"
            description="Update your contact number"
            icon="phone-flip"
            iconBg="bg-emerald-500"
            onClick={() => openSection(activeSection === "contact" ? null : "contact")}
          />
          {activeSection === "contact" && (
            <div className="px-5 pb-5 pt-2 border-t space-y-4">
              <FormField
                label="New Contact Number"
                type="tel"
                value={contact}
                onChange={setContact}
                placeholder="+63 9XX XXX XXXX"
              />
              <button
                type="button"
                onClick={handleUpdateContact}
                disabled={saving}
                className="w-full py-2.5 px-4 bg-emerald-500 text-white rounded-xl font-medium text-sm hover:bg-emerald-600 disabled:opacity-60 transition-colors"
              >
                {saving ? "Saving…" : "Save Contact"}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ── Danger Zone ──────────────────────────────────────────────────── */}
      <div className="space-y-3">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide px-1">
          Danger Zone
        </h2>

        <div className="rounded-2xl border border-red-200 bg-card overflow-hidden">
          <SectionCard
            title="Delete Account"
            description="Permanently remove your account and all data"
            icon="trash"
            iconBg="bg-red-500"
            onClick={() => openSection(activeSection === "delete" ? null : "delete")}
          />
          {activeSection === "delete" && (
            <div className="px-5 pb-5 pt-2 border-t space-y-4">
              {/* Warning */}
              <div className="flex gap-3 p-3 rounded-xl bg-red-50 border border-red-200 text-red-700 text-sm">
                <Icon name="exclamation-triangle" className="flex-shrink-0 mt-0.5 text-red-500" size="sm" />
                <p>
                  This action is <strong>permanent and cannot be undone</strong>. All your
                  products, orders, and shop data will be deleted immediately.
                </p>
              </div>

              <FormField
                label="Confirm with Password"
                value={deletePw}
                onChange={setDeletePw}
                placeholder="Enter your password to confirm"
                showToggle
                show={showDeletePw}
                onToggle={() => setShowDeletePw((v) => !v)}
              />

              <label className="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={deleteConfirmed}
                  onChange={(e) => setDeleteConfirmed(e.target.checked)}
                  className="mt-0.5 h-4 w-4 rounded border-gray-300 accent-red-500"
                />
                <span className="text-sm text-muted-foreground">
                  I understand this action is irreversible and I want to permanently delete my account.
                </span>
              </label>

              <button
                type="button"
                onClick={handleDeleteAccount}
                disabled={saving || !deleteConfirmed}
                className="w-full py-2.5 px-4 bg-red-500 text-white rounded-xl font-medium text-sm hover:bg-red-600 disabled:opacity-60 transition-colors"
              >
                {saving ? "Deleting…" : "Delete My Account"}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
