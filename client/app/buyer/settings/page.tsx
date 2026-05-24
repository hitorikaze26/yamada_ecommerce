"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { useTheme } from "@/components/providers/theme-provider"
import { AddressSelector } from "@/components/form/address-selector"
import { buyerApi, authApi, type AddressData, isAddressComplete } from "@/lib/api"
import { GlassAlert } from "@/components/ui/glass-alert"
import { useAuth } from "@/context/auth-context"
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

/** Compact width for account security form dialogs */
const ACCOUNT_DIALOG_CLASS = "sm:max-w-md"

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

export default function SettingsPage() {
  const { theme, setTheme } = useTheme()
  const { user, logout, refreshBuyerProfile } = useAuth()
  const router = useRouter()

  const [homeAddress, setHomeAddress] = useState<AddressData | null>(null)
  const [savingAddress, setSavingAddress] = useState(false)
  const [alertOpen, setAlertOpen] = useState(false)
  const [alertMessage, setAlertMessage] = useState<string | null>(null)
  const [alertVariant, setAlertVariant] = useState<"success" | "error" | "info" | "warning">("info")

  const [passwordOpen, setPasswordOpen] = useState(false)
  const [emailOpen, setEmailOpen] = useState(false)
  const [contactOpen, setContactOpen] = useState(false)
  const [deleteOpen, setDeleteOpen] = useState(false)
  const [savingAccount, setSavingAccount] = useState(false)

  const [currentPassword, setCurrentPassword] = useState("")
  const [newPassword, setNewPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [newEmail, setNewEmail] = useState("")
  const [emailPassword, setEmailPassword] = useState("")
  const [contactNumber, setContactNumber] = useState("")
  const [deletePassword, setDeletePassword] = useState("")

  const showAlert = (message: string, variant: typeof alertVariant) => {
    setAlertMessage(message)
    setAlertVariant(variant)
    setAlertOpen(true)
  }

  useEffect(() => {
    const load = async () => {
      try {
        const res = await buyerApi.getProfile()
        const profile = res.data?.profile ?? res.data
        const addr = profile?.address
        if (addr?.regionName) {
          setHomeAddress({
            regionCode: addr.regionCode ?? "",
            regionName: addr.regionName ?? "",
            provinceCode: addr.provinceCode,
            provinceName: addr.provinceName,
            municipalityCode: addr.municipalityCode ?? "",
            municipalityName: addr.municipalityName ?? "",
            barangayCode: addr.barangayCode ?? "",
            barangayName: addr.barangayName ?? "",
            streetAddress: addr.streetAddress,
            postalCode: addr.postalCode,
          })
        }
        setContactNumber(profile?.contactNumber ?? user?.contactNumber ?? "")
        setNewEmail(profile?.email ?? user?.email ?? "")
      } catch {
        // optional
      }
    }
    void load()
  }, [user?.contactNumber, user?.email])

  const saveHomeAddress = async () => {
    if (!homeAddress || !isAddressComplete(homeAddress)) {
      showAlert("Please complete your home address.", "warning")
      return
    }
    setSavingAddress(true)
    try {
      await buyerApi.updateProfile({ address: homeAddress })
      showAlert("Home address updated.", "success")
    } catch {
      showAlert("Failed to save home address.", "error")
    } finally {
      setSavingAddress(false)
    }
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
    setSavingAccount(true)
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
      setSavingAccount(false)
    }
  }

  const handleChangeEmail = async () => {
    setSavingAccount(true)
    try {
      await authApi.changeEmail({ newEmail: newEmail.trim(), password: emailPassword })
      await refreshBuyerProfile()
      setEmailOpen(false)
      setEmailPassword("")
      showAlert("Email updated successfully.", "success")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to change email.", "error")
    } finally {
      setSavingAccount(false)
    }
  }

  const handleChangeContact = async () => {
    if (!contactNumber.trim()) {
      showAlert("Please enter a contact number.", "warning")
      return
    }
    setSavingAccount(true)
    try {
      await buyerApi.updateProfile({ contactNumber: contactNumber.trim() })
      await refreshBuyerProfile()
      setContactOpen(false)
      showAlert("Contact number updated.", "success")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to update contact number.", "error")
    } finally {
      setSavingAccount(false)
    }
  }

  const handleDeleteAccount = async () => {
    setSavingAccount(true)
    try {
      await authApi.deleteAccount(deletePassword)
      setDeleteOpen(false)
      await logout()
      router.push("/landing")
    } catch (err: unknown) {
      const msg = (err as { response?: { data?: { msg?: string } } })?.response?.data?.msg
      showAlert(msg ?? "Failed to delete account. Check your password.", "error")
      setSavingAccount(false)
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
        <h1 className="text-3xl font-bold mb-2">Settings</h1>
        <p className="text-muted-foreground">Account security, delivery preferences, and appearance.</p>
      </div>

      <div className="bg-card border rounded-2xl overflow-hidden divide-y">
        <div className="px-4 py-3 bg-muted/30">
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Account security</p>
        </div>
        <SettingsRow
          icon="lock"
          title="Change password"
          subtitle="Update your sign-in password"
          onClick={() => setPasswordOpen(true)}
        />
        <SettingsRow
          icon="envelope"
          title="Change email"
          subtitle={user?.email ? `Current: ${user.email}` : "Update login email"}
          onClick={() => setEmailOpen(true)}
        />
        <SettingsRow
          icon="phone-call"
          title="Contact number"
          subtitle={user?.contactNumber ? `Current: ${user.contactNumber}` : "Add a phone number"}
          onClick={() => setContactOpen(true)}
        />
        <SettingsRow
          icon="trash"
          title="Delete account"
          subtitle="Permanently remove your account and data"
          onClick={() => setDeleteOpen(true)}
          danger
        />
      </div>

      <div className="bg-card border rounded-2xl p-6 space-y-4">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <h3 className="text-lg font-semibold">Delivery address (home)</h3>
            <p className="text-sm text-muted-foreground">
              Used when you have no saved checkout address. Manage multiple addresses on{" "}
              <Link href="/buyer/addresses" className="text-primary hover:underline">
                Saved Addresses
              </Link>
              .
            </p>
          </div>
          <Link href="/buyer/help" className="text-sm text-primary hover:underline flex items-center gap-1">
            <Icon name="question-circle" />
            Help Center
          </Link>
        </div>
        <AddressSelector value={homeAddress} onChange={setHomeAddress} />
        <button
          type="button"
          onClick={() => void saveHomeAddress()}
          disabled={savingAddress}
          className="px-4 py-2 bg-primary text-primary-foreground rounded-xl font-medium hover:bg-primary/90 disabled:opacity-60"
        >
          {savingAddress ? "Saving..." : "Save home address"}
        </button>
      </div>

      <div className="bg-card border rounded-2xl p-6">
        <h3 className="text-lg font-semibold mb-2">Appearance</h3>
        <p className="text-sm text-muted-foreground mb-6">Device display preference (stored in this browser).</p>
        <div className="flex gap-4 flex-wrap">
          {(["light", "dark", "system"] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTheme(t)}
              className={`flex-1 min-w-[100px] p-4 rounded-xl border-2 transition-colors capitalize ${
                theme === t ? "border-primary bg-primary/5" : "border-muted hover:border-muted-foreground/30"
              }`}
            >
              <Icon name={t === "light" ? "sun" : t === "dark" ? "moon" : "laptop"} size="lg" className="mx-auto mb-2" />
              <p className="font-medium">{t}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="bg-card border rounded-2xl p-6">
        <h3 className="text-lg font-semibold mb-2">Notifications</h3>
        <p className="text-sm text-muted-foreground">
          In-app notifications are managed from the bell icon in the header. Email/SMS preferences are not yet synced
          to your account.
        </p>
      </div>

      <Dialog open={passwordOpen} onOpenChange={setPasswordOpen}>
        <DialogContent className={ACCOUNT_DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Change password</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="current-password">Current password</Label>
              <Input
                id="current-password"
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                autoComplete="current-password"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="new-password">New password</Label>
              <Input
                id="new-password"
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                autoComplete="new-password"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="confirm-password">Confirm new password</Label>
              <Input
                id="confirm-password"
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                autoComplete="new-password"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setPasswordOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleChangePassword()} disabled={savingAccount}>
              {savingAccount ? "Saving..." : "Change password"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={emailOpen} onOpenChange={setEmailOpen}>
        <DialogContent className={ACCOUNT_DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Change email</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="new-email">New email</Label>
              <Input
                id="new-email"
                type="email"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                autoComplete="email"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="email-password">Current password</Label>
              <Input
                id="email-password"
                type="password"
                value={emailPassword}
                onChange={(e) => setEmailPassword(e.target.value)}
                autoComplete="current-password"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEmailOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleChangeEmail()} disabled={savingAccount}>
              {savingAccount ? "Saving..." : "Update email"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={contactOpen} onOpenChange={setContactOpen}>
        <DialogContent className={ACCOUNT_DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle>Update contact number</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label htmlFor="contact-number">Contact number</Label>
              <Input
                id="contact-number"
                type="tel"
                value={contactNumber}
                onChange={(e) => setContactNumber(e.target.value)}
                placeholder="09XX XXX XXXX"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setContactOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void handleChangeContact()} disabled={savingAccount}>
              {savingAccount ? "Saving..." : "Save contact"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <DialogContent className={ACCOUNT_DIALOG_CLASS}>
          <DialogHeader>
            <DialogTitle className="text-destructive">Delete account</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            This permanently deletes your buyer account and cannot be undone. Enter your password to confirm.
          </p>
          <div className="space-y-2 py-2">
            <Label htmlFor="delete-password">Password</Label>
            <Input
              id="delete-password"
              type="password"
              value={deletePassword}
              onChange={(e) => setDeletePassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={() => void handleDeleteAccount()} disabled={savingAccount}>
              {savingAccount ? "Deleting..." : "Delete account"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
