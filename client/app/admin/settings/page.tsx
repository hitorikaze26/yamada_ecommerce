"use client"

import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { useAuth } from "@/context/auth-context"

const settingsSections = [
  {
    href: "/admin/commission",
    icon: "percentage",
    title: "Commission & Shipping",
    description: "Platform commission rate and regional shipping fees.",
  },
  {
    href: "/admin/categories",
    icon: "tags",
    title: "Categories",
    description: "Browse product categories and storefront links.",
  },
  {
    href: "/admin/coupons",
    icon: "ticket",
    title: "Coupons",
    description: "Create and manage platform-wide promotional coupons.",
  },
  {
    href: "/admin/analytics",
    icon: "chart-histogram",
    title: "Analytics & Reports",
    description: "Revenue charts and downloadable PDF reports.",
  },
  {
    href: "/admin/reports",
    icon: "exclamation",
    title: "Problem Reports",
    description: "User-submitted issues about the app, stores, or riders.",
  },
]

export default function AdminSettingsPage() {
  const { user } = useAuth()

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold mb-2">Settings</h1>
        <p className="text-muted-foreground">
          Platform configuration and admin account overview.
        </p>
      </div>

      <div className="bg-card border rounded-2xl p-6">
        <h2 className="text-lg font-semibold mb-4">Admin Account</h2>
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-slate-900 flex items-center justify-center">
            <Icon name="user-shield" className="text-white" />
          </div>
          <div>
            <p className="font-medium">{user?.fullName ?? "Administrator"}</p>
            <p className="text-sm text-muted-foreground">{user?.email ?? "—"}</p>
            <p className="text-xs text-muted-foreground mt-1 capitalize">Role: {user?.role ?? "admin"}</p>
          </div>
        </div>
        <p className="text-xs text-muted-foreground mt-4">
          Operational admin tools run on the web panel. Mobile admin login is limited to a placeholder dashboard.
        </p>
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-4">Platform Configuration</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {settingsSections.map((section) => (
            <Link
              key={section.href}
              href={section.href}
              className="flex items-start gap-4 p-5 rounded-2xl border bg-card hover:border-primary hover:bg-primary/5 transition-colors"
            >
              <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                <Icon name={section.icon} className="text-primary" />
              </div>
              <div>
                <p className="font-medium">{section.title}</p>
                <p className="text-sm text-muted-foreground mt-1">{section.description}</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
