"use client"

import Link from "next/link"
import Image from "next/image"
import { motion } from "framer-motion"
import Lottie from "lottie-react"
import { Footer } from "@/components/layout/footer"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { HeroButton } from "@/components/ui/hero-button"
import { useTheme } from "@/components/providers/theme-provider"
import truckLight from "@/public/landing_page_reso/truck-light.json"
import truckDark from "@/public/landing_page_reso/truck-dark.json"
import cartLight from "@/public/landing_page_reso/cart-light.json"
import cartDark from "@/public/landing_page_reso/cart-dark.json"

const easeOut = [0.16, 1, 0.3, 1] as [number, number, number, number]

const fadeInUp = (delay: number) => ({
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { delay, duration: 0.6, ease: easeOut },
  },
})

const fadeIn = (delay: number) => ({
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { delay, duration: 0.8, ease: easeOut },
  },
})

const scaleIn = (delay: number) => ({
  hidden: { scale: 0.85, opacity: 0 },
  visible: {
    scale: 1,
    opacity: 1,
    transition: { delay, duration: 0.5, ease: easeOut },
  },
})

const features = [
  {
    title: "Trendy & Curated Collections",
    description:
      "From chic dresses to activewear, everything is handpicked to match your look.",
    icon: "shopping-bag",
  },
  {
    title: "Secure & Seamless Shopping",
    description:
      "Safe checkout, verified sellers, and real-time order tracking.",
    icon: "shield-check",
  },
  {
    title: "Fast Nationwide Delivery",
    description: "Quick, reliable shipping handled by trusted riders.",
    icon: "truck-side",
  },
  {
    title: "Genuine Sellers & Quality Products",
    description:
      "Verified partners to give you an authentic and worry-free shopping experience.",
    icon: "badge-check",
  },
]

export default function LandingPage() {
  const { resolvedTheme, setTheme, theme } = useTheme()

  const isDark = resolvedTheme === "dark"

  const truckAnimation = isDark ? truckDark : truckLight
  const cartAnimation = isDark ? cartDark : cartLight

  const toggleTheme = () => {
    if (theme === "system") {
      setTheme(isDark ? "light" : "dark")
    } else {
      setTheme(theme === "dark" ? "light" : "dark")
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-[--color-off-white] dark:bg-navy">
      <header className="w-full border-b bg-card dark:bg-navy/90 dark:border-muted">
        <div className="container mx-auto px-4">
          <div className="flex h-16 items-center justify-between gap-6">
            <Link href="/landing" className="flex items-center gap-3">
              <div className="hidden sm:block">
                <Image
                  src="/logo/logo.png"
                  alt="Yamada logo"
                  width={96}
                  height={24}
                  className="h-6 w-auto"
                />
              </div>
              <span className="sm:hidden text-lg font-semibold text-[--color-charcoal] dark:text-white">Yamada</span>
            </Link>

            <nav className="hidden md:flex items-center gap-10 text-sm font-medium text-[--color-charcoal] dark:text-gray-200">
              <Link href="/about" className="hover:text-[--color-rosewood] dark:hover:text-white transition-colors">About</Link>
              <Link href="/contact" className="hover:text-[--color-rosewood] dark:hover:text-white transition-colors">Contact</Link>
            </nav>

            <div className="flex items-center gap-4">
              <button
                type="button"
                onClick={toggleTheme}
                className="text-[--color-charcoal] dark:text-[--color-foreground] hover:text-[--color-rosewood] dark:hover:text-[--color-foreground] transition-colors"
                aria-label="Toggle theme"
              >
                <Icon name={isDark ? "moon" : "sun"} />
              </button>
              <Button asChild className="hidden sm:inline-flex rounded-full px-5">
                <Link href="/auth/login?role=buyer">Login and Sign up</Link>
              </Button>
            </div>
          </div>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero Section */}
        <section className="relative border-b bg-[--color-off-white] dark:bg-navy dark:border-muted">
          <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-10 lg:py-20">
            <div className="grid gap-10 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] items-center">
              {/* Left: Text */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeInUp(0)}
                className="space-y-8"
              >
                <div className="inline-flex items-center gap-2 rounded-full bg-card dark:bg-muted px-4 py-2 shadow-sm text-xs font-medium text-[--color-rosewood]">
                  <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-secondary text-primary dark:text-navy text-sm">
                    Y
                  </span>
                  Yamada Collections
                </div>

                <h1 className="text-3xl sm:text-4xl lg:text-[2.9rem] font-semibold leading-tight text-[--color-charcoal] dark:text-white">
                  Feel Confident. Feel Beautiful.
                  <br />
                  <span className="text-[--color-rosewood]">Shop the Yamada Collection.</span>
                </h1>

                <p className="max-w-prose text-sm sm:text-base text-[--color-muted-foreground]">
                  Discover curated women&apos;s fashion, from elegant dresses to everyday essentials.
                  Style, comfort, and confidence delivered to your door.
                </p>

                <div className="flex flex-wrap items-center gap-4">
                  <Button asChild size="lg" className="rounded-full px-8 text-base">
                    <Link href="/home">Shop Now</Link>
                  </Button>
                  <HeroButton as={Link} href="/auth/login?role=rider">
                    Rider Portal
                  </HeroButton>
                  <HeroButton as={Link} href="/auth/login?role=seller">
                    Seller Portal
                  </HeroButton>
                </div>
              </motion.div>

              {/* Right: Video Card */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeIn(0.2)}
                className="relative"
              >
                <div className="relative overflow-hidden rounded-3xl bg-card dark:bg-card shadow-sm border border-[--color-warm-gray] dark:border-muted">
                  <div className="aspect-[4/3] overflow-hidden">
                    <video
                      className="h-full w-full object-cover"
                      autoPlay
                      muted
                      loop
                      playsInline
                    >
                      <source src="/landing_page_reso/video_reso/0_Woman_Shopping_1920x1080.mp4" type="video/mp4" />
                    </video>
                  </div>
                </div>
              </motion.div>
            </div>
          </div>
        </section>

        {/* Middle Cards: Deliver / Partner */}
        <section className="bg-[--color-off-white] dark:bg-navy/95 py-10 lg:py-14">
          <div className="container mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
            <div className="grid gap-6 md:grid-cols-2">
              {/* Deliver card */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeInUp(0.1)}
                className="relative overflow-hidden rounded-3xl bg-card dark:bg-card shadow-sm border border-[--color-warm-gray] dark:border-muted px-8 py-8 flex flex-col gap-4"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="space-y-2">
                    <h2 className="text-xl font-semibold text-[--color-charcoal] dark:text-white">Deliver with Us</h2>
                    <p className="text-sm text-[--color-muted-foreground] max-w-sm">
                      Deliver orders, track earnings, and maximize your delivery schedule with flexible work.
                    </p>
                  </div>
                  <motion.div
                    variants={scaleIn(0.2)}
                    initial="hidden"
                    whileInView="visible"
                    viewport={{ once: true }}
                  >
                    <Lottie animationData={truckAnimation} className="h-20 w-20" />
                  </motion.div>
                </div>

                <div className="pt-2">
                  <HeroButton as={Link} href="/auth/register/rider">
                    Rider Registration
                  </HeroButton>
                </div>
              </motion.div>

              {/* Partner card */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeInUp(0.2)}
                className="relative overflow-hidden rounded-3xl bg-card dark:bg-card shadow-sm border border-[--color-warm-gray] dark:border-muted px-8 py-8 flex flex-col gap-4"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="space-y-2">
                    <h2 className="text-xl font-semibold text-[--color-charcoal] dark:text-white">Partner with Yamada</h2>
                    <p className="text-sm text-[--color-muted-foreground] max-w-sm">
                      Open your shop, upload products, manage inventory, and reach fashion-forward customers.
                    </p>
                  </div>
                  <motion.div
                    variants={scaleIn(0.3)}
                    initial="hidden"
                    whileInView="visible"
                    viewport={{ once: true }}
                  >
                    <Lottie animationData={cartAnimation} className="h-20 w-20" />
                  </motion.div>
                </div>

                <div className="pt-2">
                  <HeroButton as={Link} href="/auth/register/seller">
                    Seller Registration
                  </HeroButton>
                </div>
              </motion.div>
            </div>
          </div>
        </section>

        {/* Why Shop with Yamada */}
        <section className="bg-card dark:bg-navy py-12 lg:py-16">
          <div className="container mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, amount: 0.4 }}
              variants={fadeInUp(0)}
              className="mb-10 text-center"
            >
              <h2 className="text-2xl sm:text-3xl font-semibold text-[--color-charcoal] dark:text-[--color-foreground]">
                Why Shop with Yamada?
              </h2>
              <p className="mt-2 text-sm sm:text-base text-[--color-muted-foreground]">
                Designed for women, designed for you.
              </p>
            </motion.div>

            <div className="grid gap-6 sm:grid-cols-2">
              {features.slice(0, 2).map((item, index) => (
                <motion.div
                  key={item.title}
                  initial="hidden"
                  whileInView="visible"
                  viewport={{ once: true, amount: 0.4 }}
                  variants={fadeInUp(0.1 + index * 0.1)}
                  className="rounded-3xl bg-[--color-off-white] dark:bg-card border border-[--color-warm-gray] dark:border-muted p-8 flex flex-col gap-4"
                >
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-secondary text-foreground">
                    <Icon name={item.icon} size="xl" />
                  </div>
                  <h3 className="text-lg font-semibold text-[--color-charcoal] dark:text-white">
                    {item.title}
                  </h3>
                  <p className="text-sm text-[--color-muted-foreground] leading-relaxed">
                    {item.description}
                  </p>
                </motion.div>
              ))}
              {features.slice(2, 4).map((item, index) => (
                <motion.div
                  key={item.title}
                  initial="hidden"
                  whileInView="visible"
                  viewport={{ once: true, amount: 0.4 }}
                  variants={fadeInUp(0.3 + index * 0.1)}
                  className="rounded-3xl border border-[--color-warm-gray] dark:border-muted p-8 flex flex-col gap-4"
                >
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary">
                    <Icon name={item.icon} size="xl" />
                  </div>
                  <h3 className="text-lg font-semibold text-[--color-charcoal] dark:text-white">
                    {item.title}
                  </h3>
                  <p className="text-sm text-[--color-muted-foreground] leading-relaxed">
                    {item.description}
                  </p>
                </motion.div>
              ))}
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}

