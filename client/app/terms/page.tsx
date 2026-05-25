import Link from "next/link"
import { Footer } from "@/components/layout/footer"
import { Navbar } from "@/components/layout/navbar"

export default function TermsPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1 container max-w-3xl py-12 px-4">
        <h1 className="text-3xl font-bold mb-4">Terms and Conditions</h1>
        <p className="text-muted-foreground mb-6">
          By registering as a buyer, seller, or rider on Yamada, you agree to follow marketplace
          policies, provide accurate information, and comply with applicable laws in the Philippines.
        </p>
        <p className="text-sm text-muted-foreground">
          Seller accounts require document verification and admin approval before a shop goes live.
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
