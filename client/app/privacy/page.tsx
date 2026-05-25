import Link from "next/link"
import { Footer } from "@/components/layout/footer"
import { Navbar } from "@/components/layout/navbar"

export default function PrivacyPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1 container max-w-3xl py-12 px-4">
        <h1 className="text-3xl font-bold mb-4">Privacy Policy</h1>
        <p className="text-muted-foreground mb-6">
          Yamada respects your privacy. This page outlines how account and order data are collected,
          stored, and used to operate the marketplace.
        </p>
        <p className="text-sm text-muted-foreground">
          For questions, contact support through the Help Center after signing in.
        </p>
        <p className="mt-8">
          <Link href="/" className="text-primary hover:underline">
            Back to home
          </Link>
        </p>
      </main>
      <Footer />
    </div>
  )
}
