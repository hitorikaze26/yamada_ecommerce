"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import Swal from "sweetalert2"
import { Icon } from "@/components/ui/icon"
import { GlassAlert } from "@/components/ui/glass-alert"
import { useAuth } from "@/context/auth-context"
import { authApi } from "@/lib/api"
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Button } from "@/components/ui/button"

const DIALOG_CLASS = "sm:max-w-md"

function SettingsRow({
  icon,
  iconClass,
  title,
  subtitle,
  onClick,
  danger,
}: {
  icon: string
  iconClass?: string
  title: string
  subtitle: string
  onClick: () => void
  danger?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full flex items-center gap-4 px-4 py-3.5 text-left hover:bg-muted/50 transition-colors first:rounded-t-2xl last:rounded-b-2xl"
    >
      <div
        className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
          danger ? "bg-destructive/10" : "bg-primary/10"
        }`}
      >
        <Icon name={icon} className={danger ? "text-destructive" : iconClass ?? "text-primary"} />
      </div>
      <div className="flex-1 min-w-0">
        <p className={`font-medium text-sm ${danger ? "text-destructive" : ""}`}>{title}</p>
        <p className="text-xs text-muted-foreground">{subtitle}</p>
      </div>
      <Icon name="angle-right" className="text-muted-foreground shrink-0" />
    </button>
  )
}

export default function RiderSettingsPage() {
  const { user, logout } = useAuth()
  const router = useRouter()

  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const [passwordOpen, setPasswordOpen] = useState(false)
  const [emailOpen, setEmailOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [saving, setSaving] = useState(false)

  const [currentPassword, setCurrentPassword] = useState("")
  const [newPassword, setNewPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [newEmail, setNewEmail] = useState(user?.email || "")
  const [emailPassword, setEmailPassword] = useState("")
  const [deletePassword, setDeletePassword] = useState("")

  const showAlert = (message: string, variant: typeof alertVariant) => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  const handleChangePassword = async () => {
    if (newPassword !== confirmPassword) {
      showAlert("New passwords do not match.", "warning")
      return
    }
    if (newPassword.length < 8) {
      showAlert("Password must be at least 8 characters.", "warning")
      return
    }
    setSaving(true)
    try {
      await authApi.changePassword({ currentPassword, newPassword })
      setPasswordOpen(false)
      setCurrentPassword("")
      setNewPassword("")
      setConfirmPassword("")
      showAlert("Password changed successfully.", "success")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to change password.", "error")
    } finally {
      setSaving(false)
    }
  }

  const handleChangeEmail = async () => {
    setSaving(true)
    try {
      await authApi.changeEmail({ newEmail: newEmail.trim(), password: emailPassword })
      setEmailOpen(false)
      setEmailPassword("")
      showAlert("Email updated successfully.", "success")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to change email.", "error")
    } finally {
      setSaving(false)
    }
  }

  const handleDeleteAccount = async () => {
    setSaving(true)
    try {
      await authApi.deleteAccount(deletePassword)
      setDeleteOpen(false)
      await logout()
      router.push("/landing")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to delete account. Check your password.", "error")
      setSaving(false)
    }
  }

  const handleLogout = async () => {
    const result = await Swal.fire({
      title: "Logout",
      text: "Are you sure you want to logout?",
      icon: "question",
      showCancelButton: true,
      confirmButtonText: "Yes, logout",
      cancelButtonText: "Cancel",
      confirmButtonColor: "#ef4444",
    })

    if (result.isConfirmed) {
      await logout()
      router.push("/landing")
    }
  }

  return (
    <div className="space-y-6">
      <GlassAlert
        open={alertOpen && !!alertMessage}
        title={alertVariant === "success" ? "Success" : alertVariant === "error" ? "Error" : "Notice"}
        description={alertMessage ?? undefined}
        variant={alertVariant}
        onClose={() => setAlertOpen(false)}
      />

      <div>
        <h1 className="text-3xl font-bold mb-2">Account Settings</h1>
        <p className="text-muted-foreground">Manage your account security and preferences.</p>
      </div>

      <div className="bg-card border rounded-2xl divide-y">
        <SettingsRow
          icon="lock"
          iconClass="text-blue-500"
          title="Change Password"
          subtitle="Update your account password"
          onClick={() => setPasswordOpen(true)}
        />
        <SettingsRow
          icon="envelope"
          iconClass="text-blue-500"
          title="Change Email"
          subtitle="Update your login email address"
          onClick={() => setEmailOpen(true)}
        />
      </div>

      <div className="bg-card border rounded-2xl divide-y">
        <SettingsRow
          icon="trash"
          title="Delete Account"
          subtitle="Permanently remove your account and all data"
          danger
          onClick={() => setDeleteOpen(true)}
        />
      </div>

      <div className="bg-card border rounded-2xl divide-y">
        <SettingsRow
          icon="sign-out"
          title="Logout"
          subtitle="Sign out of your account"
          onClick={handleLogout}
        />
      </div>

      <Dialog open={passwordOpen} onOpenChange={setPasswordOpen}>
        <DialogContent className={DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Change Password</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="current-pw">Current Password</Label>
              <Input
                id="current-pw"
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="new-pw">New Password</Label>
              <Input
                id="new-pw"
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                placeholder="At least 8 characters"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="confirm-pw">Confirm New Password</Label>
              <Input
                id="confirm-pw"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPasswordOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={handleChangePassword} disabled={saving}>
              {saving ? "Saving..." : "Change Password"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={emailOpen} onOpenChange={setEmailOpen}>
        <DialogContent className={DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Change Email</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="new-email">New Email Address</Label>
              <Input
                id="new-email"
                type="email"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                placeholder="e.g. newemail@example.com"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="email-pw">Confirm with Password</Label>
              <Input
                id="email-pw"
                type="password"
                value={emailPassword}
                onChange={(e) => setEmailPassword(e.target.value)}
                placeholder="Enter your current password"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEmailOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button onClick={handleChangeEmail} disabled={saving}>
              {saving ? "Saving..." : "Change Email"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent className={DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Delete Account</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="p-3 rounded-lg bg-destructive/10 border border-destructive/20 text-sm text-destructive flex items-start gap-2">
              <Icon name="exclamation-triangle" className="shrink-0 mt-0.5" />
              <span>
                This action is permanent and cannot be undone. All your delivery history and rider account data will be
                deleted.
              </span>
            </div>
            <div className="space-y-2">
              <Label htmlFor="delete-pw">Confirm with Password</Label>
              <Input
                id="delete-pw"
                type="password"
                value={deletePassword}
                onChange={(e) => setDeletePassword(e.target.value)}
                placeholder="Enter your password to confirm"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteAccount} disabled={saving}>
              {saving ? "Deleting..." : "Delete My Account"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
