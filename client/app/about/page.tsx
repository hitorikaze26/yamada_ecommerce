"use client"

import { Navbar } from "@/components/layout/navbar"
import { Footer } from "@/components/layout/footer"
import { Icon } from "@/components/ui/icon"

const values = [
  {
    title: "Curated Feminine Aesthetic",
    description: "Every piece is thoughtfully chosen to celebrate confidence, elegance, and warmth.",
    icon: "sparkles",
  },
  {
    title: "Quality You Can Trust",
    description: "We partner with trusted brands and artisans to bring you clothing that lasts.",
    icon: "shield-check",
  },
  {
    title: "Inclusive Sizing",
    description: "Fashion is for everyone. Our collections span a wide range of sizes and fits.",
    icon: "users",
  },
  {
    title: "Sustainable Practices",
    description: "We're committed to reducing our footprint through ethical sourcing and eco-friendly packaging.",
    icon: "leaf",
  },
]

export default function AboutPage() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />
      <main className="flex-1">
        <section className="py-16 md:py-24">
          <div className="container mx-auto px-4">
            <div className="max-w-3xl mx-auto text-center mb-16">
              <h1 className="text-4xl md:text-5xl font-bold mb-6">About Yamada</h1>
              <p className="text-lg text-muted-foreground leading-relaxed">
                Yamada is a women&apos;s fashion e-commerce brand built on the belief that every woman
                deserves to feel elegant, warm, and confident in what she wears. We curate pieces that
                blend timeless sophistication with modern femininity.
              </p>
            </div>

            <div className="max-w-3xl mx-auto mb-16">
              <h2 className="text-2xl font-bold mb-6 text-center">Our Story</h2>
              <p className="text-muted-foreground leading-relaxed mb-4">
                Founded with a passion for feminine style, Yamada started as a small boutique
                dedicated to helping women discover clothing that makes them feel beautiful inside
                and out. What began as a curated collection of dresses and tops has grown into a
                full lifestyle destination for the modern woman.
              </p>
              <p className="text-muted-foreground leading-relaxed mb-4">
                Every piece in our collection is selected with care — from the fabric to the fit,
                from the color palette to the finishing details. We believe that fashion should
                celebrate individuality, not compromise it.
              </p>
              <p className="text-muted-foreground leading-relaxed">
                Today, Yamada serves thousands of customers nationwide, offering everything from
                everyday essentials to occasion-ready pieces. Our community of women inspires us
                every day to keep raising the bar.
              </p>
            </div>

            <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6 max-w-5xl mx-auto mb-16">
              {values.map((v) => (
                <div
                  key={v.title}
                  className="bg-card border rounded-2xl p-6 text-center"
                >
                  <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                    <Icon name={v.icon} className="text-primary" />
                  </div>
                  <h3 className="font-semibold mb-2">{v.title}</h3>
                  <p className="text-sm text-muted-foreground">{v.description}</p>
                </div>
              ))}
            </div>

            <div className="max-w-3xl mx-auto text-center">
              <h2 className="text-2xl font-bold mb-4">Join Our Community</h2>
              <p className="text-muted-foreground mb-8">
                Follow us on social media and be the first to know about new arrivals, exclusive
                drops, and style inspiration.
              </p>
              <div className="flex justify-center gap-4">
                <span className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border text-sm">
                  <Icon name="facebook" />
                  Facebook
                </span>
                <span className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border text-sm">
                  <Icon name="instagram" />
                  Instagram
                </span>
                <span className="inline-flex items-center gap-2 px-4 py-2 rounded-xl border text-sm">
                  <Icon name="pinterest" />
                  Pinterest
                </span>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  )
}
