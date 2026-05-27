import Link from "next/link"
import { Icon } from "@/components/ui/icon"
import { CATEGORIES } from "@/lib/types"

export function Footer() {
  return (
    <footer className="bg-card border-t">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center">
                <span className="text-primary-foreground font-bold text-xl">Y</span>
              </div>
              <span className="text-xl font-semibold">Yamada</span>
            </div>
            <p className="text-sm text-muted-foreground">
              Discover your style with Yamada. Premium women&apos;s apparel curated with love and designed for the
              modern woman.
            </p>
            <div className="flex gap-4">
              <a href="#" className="text-muted-foreground hover:text-primary transition-colors" aria-label="Facebook">
                <Icon name="facebook" size="lg" />
              </a>
              <a href="#" className="text-muted-foreground hover:text-primary transition-colors" aria-label="Instagram">
                <Icon name="instagram" size="lg" />
              </a>
              <a href="#" className="text-muted-foreground hover:text-primary transition-colors" aria-label="Twitter">
                <Icon name="twitter" size="lg" />
              </a>
            </div>
          </div>

          {/* Categories */}
          <div>
            <h3 className="font-semibold mb-4">Categories</h3>
            <ul className="space-y-2">
              {CATEGORIES.slice(0, 5).map((category) => (
                <li key={category.id}>
                  <Link
                    href={`/search?category=${category.id}`}
                    className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {category.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="font-semibold mb-4">Quick Links</h3>
            <ul className="space-y-2">
              <li>
                <Link href="#" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
                  About Us
                </Link>
              </li>
              <li>
                <Link
                  href="/auth/register/seller"
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  Become a Seller
                </Link>
              </li>
              <li>
                <Link
                  href="/auth/register/rider"
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                >
                  Become a Rider
                </Link>
              </li>
              <li>
                <Link href="/terms" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
                  Terms of Service
                </Link>
              </li>
              <li>
                <Link href="/privacy" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
                  Privacy Policy
                </Link>
              </li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h3 className="font-semibold mb-4">Contact Us</h3>
            <ul className="space-y-3">
              <li className="flex items-center gap-2 text-sm text-muted-foreground">
                <Icon name="envelope" />
                support@yamada.ph
              </li>
              <li className="flex items-center gap-2 text-sm text-muted-foreground">
                <Icon name="phone-call" />
                +63 912 345 6789
              </li>
              <li className="flex items-start gap-2 text-sm text-muted-foreground">
                <Icon name="marker" className="mt-0.5" />
                <span>123 Fashion Street, Makati City, Metro Manila, Philippines</span>
              </li>
            </ul>
          </div>
        </div>

        <div className="border-t mt-8 pt-8 flex flex-col sm:flex-row justify-between items-center gap-4">
          <p className="text-sm text-muted-foreground">© {new Date().getFullYear()} Yamada. All rights reserved.</p>
          <div className="flex items-center gap-4">
            <Icon name="credit-card" className="text-muted-foreground" />
            <Icon name="paypal" className="text-muted-foreground" />
            <span className="text-sm text-muted-foreground">Secure payments</span>
          </div>
        </div>
      </div>
    </footer>
  )
}
