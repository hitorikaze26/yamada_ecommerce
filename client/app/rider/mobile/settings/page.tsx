"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/context/auth-context"
import { authApi } from "@/lib/api"
import Swal from "sweetalert2"

const kPrimaryPink = "#E891A0"

export default function RiderMobileSettings() {
  const { user, logout } = useAuth()
  const router = useRouter()

  const [showChangePassword, setShowChangePassword] = useState(false)
  const [showChangeEmail, setShowChangeEmail] = useState(false)
  const [showDelete, setShowDelete] = useState(false)

  const [currentPassword, setCurrentPassword] = useState("")
  const [newPassword, setNewPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [newEmail, setNewEmail] = useState(user?.email || "")
  const [emailPassword, setEmailPassword] = useState("")
  const [deletePassword, setDeletePassword] = useState("")
  const [saving, setSaving] = useState(false)

  const showToast = async (icon: "success" | "error", title: string) => {
    await Swal.fire({ icon, title, timer: 2000, showConfirmButton: false, toast: true, position: "top-end" })
  }

  const handleChangePassword = async () => {
    if (newPassword !== confirmPassword) {
      await showToast("error", "Passwords do not match")
      return
    }
    if (newPassword.length < 8) {
      await showToast("error", "Password must be at least 8 characters")
      return
    }
    setSaving(true)
    try {
      await authApi.changePassword({ currentPassword, newPassword })
      setShowChangePassword(false)
      setCurrentPassword("")
      setNewPassword("")
      setConfirmPassword("")
      await showToast("success", "Password changed")
    } catch {
      await showToast("error", "Failed to change password")
    } finally {
      setSaving(false)
    }
  }

  const handleChangeEmail = async () => {
    setSaving(true)
    try {
      await authApi.changeEmail({ newEmail: newEmail.trim(), password: emailPassword })
      setShowChangeEmail(false)
      setEmailPassword("")
      await showToast("success", "Email updated")
    } catch {
      await showToast("error", "Failed to change email")
    } finally {
      setSaving(false)
    }
  }

  const handleDeleteAccount = async () => {
    const confirmed = await Swal.fire({
      title: "Delete Account?",
      text: "This is permanent and cannot be undone.",
      icon: "warning",
      showCancelButton: true,
      confirmButtonColor: "#ef4444",
      confirmButtonText: "Yes, delete",
    })
    if (!confirmed.isConfirmed) return

    setSaving(true)
    try {
      await authApi.deleteAccount(deletePassword)
      setShowDelete(false)
      await logout()
      router.push("/landing")
    } catch {
      await showToast("error", "Failed to delete account")
      setSaving(false)
    }
  }

  return (
    <div className="p-4 space-y-6">
      <div>
        <h1 className="text-lg font-semibold dark:text-white">Settings</h1>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage your account</p>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-2xl divide-y divide-gray-100 dark:divide-gray-700 shadow-sm">
        <button
          onClick={() => setShowChangePassword(true)}
          className="w-full flex items-center gap-4 px-4 py-4 text-left"
        >
          <div className="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center">
            <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <div className="flex-1">
            <p className="font-medium text-sm dark:text-white">Change Password</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">Update your account password</p>
          </div>
          <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>

        <button
          onClick={() => setShowChangeEmail(true)}
          className="w-full flex items-center gap-4 px-4 py-4 text-left"
        >
          <div className="w-10 h-10 rounded-xl bg-blue-100 flex items-center justify-center">
            <svg className="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
          </div>
          <div className="flex-1">
            <p className="font-medium text-sm dark:text-white">Change Email</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">Update your login email</p>
          </div>
          <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-2xl divide-y divide-gray-100 dark:divide-gray-700 shadow-sm">
        <button
          onClick={() => setShowDelete(true)}
          className="w-full flex items-center gap-4 px-4 py-4 text-left"
        >
          <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
            <svg className="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </div>
          <div className="flex-1">
            <p className="font-medium text-sm text-red-600">Delete Account</p>
            <p className="text-xs text-gray-500 dark:text-gray-400">Permanently remove your account</p>
          </div>
          <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      {/* Modals */}
      {showChangePassword && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-end sm:items-center justify-center">
          <div className="bg-white dark:bg-gray-800 w-full max-w-md rounded-t-2xl sm:rounded-2xl p-6">
            <h2 className="text-lg font-semibold mb-4 dark:text-white">Change Password</h2>
            <div className="space-y-4">
              <input
                type="password"
                placeholder="Current Password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2 focus:ring-[#E891A0]"
              />
              <input
                type="password"
                placeholder="New Password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2"
              />
              <input
                type="password"
                placeholder="Confirm New Password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2"
              />
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowChangePassword(false)}
                className="flex-1 py-3 rounded-xl border text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-white transition-colors"
                disabled={saving}
              >
                Cancel
              </button>
              <button
                onClick={handleChangePassword}
                className="flex-1 py-3 rounded-xl text-sm font-medium text-white"
                style={{ backgroundColor: kPrimaryPink }}
                disabled={saving}
              >
                {saving ? "Saving..." : "Change Password"}
              </button>
            </div>
          </div>
        </div>
      )}

      {showChangeEmail && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-end sm:items-center justify-center">
          <div className="bg-white dark:bg-gray-800 w-full max-w-md rounded-t-2xl sm:rounded-2xl p-6">
            <h2 className="text-lg font-semibold mb-4 dark:text-white">Change Email</h2>
            <div className="space-y-4">
              <input
                type="email"
                placeholder="New Email Address"
                value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2"
              />
              <input
                type="password"
                placeholder="Current Password"
                value={emailPassword}
                onChange={(e) => setEmailPassword(e.target.value)}
                className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2"
              />
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowChangeEmail(false)}
                className="flex-1 py-3 rounded-xl border text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-white transition-colors"
                disabled={saving}
              >
                Cancel
              </button>
              <button
                onClick={handleChangeEmail}
                className="flex-1 py-3 rounded-xl text-sm font-medium text-white"
                style={{ backgroundColor: kPrimaryPink }}
                disabled={saving}
              >
                {saving ? "Saving..." : "Change Email"}
              </button>
            </div>
          </div>
        </div>
      )}

      {showDelete && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-end sm:items-center justify-center">
          <div className="bg-white dark:bg-gray-800 w-full max-w-md rounded-t-2xl sm:rounded-2xl p-6">
            <h2 className="text-lg font-semibold mb-2 dark:text-white">Delete Account</h2>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              This action is permanent and cannot be undone. All your delivery history and rider data will be deleted.
            </p>
            <input
              type="password"
              placeholder="Enter your password"
              value={deletePassword}
              onChange={(e) => setDeletePassword(e.target.value)}
              className="w-full px-4 py-3 rounded-xl border bg-gray-50 dark:bg-gray-900 dark:text-white dark:border-gray-700 text-sm outline-none focus:ring-2"
            />
            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowDelete(false)}
                className="flex-1 py-3 rounded-xl border text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-white transition-colors"
                disabled={saving}
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteAccount}
                className="flex-1 py-3 rounded-xl text-sm font-medium text-white bg-red-500 hover:bg-red-600 transition-colors"
                disabled={saving}
              >
                {saving ? "Deleting..." : "Delete My Account"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
