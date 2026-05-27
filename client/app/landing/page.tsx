"use client"

import Link from "next/link"
import Image from "next/image"
import { motion } from "framer-motion"
import { Footer } from "@/components/layout/footer"
import { Button } from "@/components/ui/button"
import { Icon } from "@/components/ui/icon"
import { HeroButton } from "@/components/ui/hero-button"
import { useTheme } from "@/components/providers/theme-provider"

const fadeInUp = (delay: number) => ({
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { delay, duration: 0.6, ease: [0.16, 1, 0.3, 1] as [number, number, number, number] },
  },
})

const fadeIn = (delay: number) => ({
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { delay, duration: 0.8, ease: [0.16, 1, 0.3, 1] as [number, number, number, number] },
  },
})

export default function LandingPage() {
  const { resolvedTheme, setTheme, theme } = useTheme()

  const isDark = resolvedTheme === "dark"

  const toggleTheme = () => {
    if (theme === "system") {
      setTheme(isDark ? "light" : "dark")
    } else {
      setTheme(theme === "dark" ? "light" : "dark")
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-[--color-off-white] dark:bg-[#060709]">
      <header className="w-full border-b bg-[#f1f0f1] dark:bg-[#0c0d10] dark:border-[#1c1d21]">
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
              <button className="hover:text-black dark:hover:text-white transition-colors">Contact us</button>
              <button className="hover:text-black dark:hover:text-white transition-colors">About</button>
            </nav>

            <div className="flex items-center gap-4">
              <button
                type="button"
                onClick={toggleTheme}
                className="text-[--color-charcoal] dark:text-gray-200 hover:text-black dark:hover:text-white transition-colors"
                aria-label="Toggle theme"
              >
                <Icon name={isDark ? "moon" : "sun"} />
              </button>
              <HeroButton as={Link} href="/auth/login?role=buyer" className="hidden sm:inline-flex">
                Login and Sign up
              </HeroButton>
            </div>
          </div>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero Section */}
        <section className="relative border-b bg-[--color-off-white] dark:bg-[#060709] dark:border-[#1c1d21]">
          <div className="container mx-auto px-4 py-10 lg:py-16">
            <div className="grid gap-10 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] items-center">
              {/* Left: Text */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeInUp(0)}
                className="space-y-6"
              >
                <div className="inline-flex items-center gap-2 rounded-full bg-white dark:bg-[#111827] px-4 py-2 shadow-sm text-xs font-medium text-[--color-rosewood] mb-4">
                  <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-[--color-secondary] dark:bg-[#f97376] text-[--color-rosewood] dark:text-[#111827] text-sm">
                    Y
                  </span>
                  <span>Yamada Collections</span>
                </div>

                <h1 className="focus-in-contract text-3xl sm:text-4xl lg:text-[2.9rem] font-semibold leading-tight text-[--color-charcoal] dark:text-white">
                  Feel Confident. Feel Beautiful.
                  <br />
                  <span className="text-[--color-rosewood]">Shop the Yamada Collection.</span>
                </h1>

                <p className="max-w-xl text-sm sm:text-base text-[--color-muted-foreground] dark:text-gray-300 mb-4">
                  Discover curated women&apos;s fashion &mdash; from elegant dresses to everyday essentials.
                  Style, comfort, and confidence delivered to your door.
                </p>

                {/* Hero CTAs */}
                <div className="space-y-4">
                  <div className="flex flex-wrap gap-3">
                    <HeroButton as={Link} href="/auth/login?role=rider">
                      Rider Portal
                    </HeroButton>
                    <HeroButton as={Link} href="/auth/login?role=seller">
                      Seller Portal
                    </HeroButton>
                  </div>

                  <Link href="/home" className="mt-2 inline-block">
                    <button
                      type="button"
                      className="group relative z-10 flex justify-center items-center gap-2 mx-auto px-5 py-2.5 text-sm sm:text-base lg:font-semibold
                                 rounded-full border-2 shadow-xl overflow-hidden isolation-auto
                                 bg-transparent text-[--color-charcoal] border-[--color-rosewood]
                                 before:absolute before:content-[''] before:w-full before:h-full before:-left-full before:rounded-full
                                 before:bg-[--color-rosewood] before:transition-all before:duration-500 before:-z-10
                                 hover:text-[--color-off-white] hover:before:left-0"
                    >
                      <span className="relative">Shop Now</span>
                      <svg
                        className="relative w-6 h-6 sm:w-7 sm:h-7 justify-end rounded-full border border-[--color-rosewood]
                                   bg-[--color-off-white] text-[--color-rosewood]
                                   p-1.5 sm:p-2 rotate-45 transition-all duration-500 ease-linear
                                   group-hover:rotate-90 group-hover:border-transparent"
                        viewBox="0 0 16 19"
                        xmlns="http://www.w3.org/2000/svg"
                      >
                        <path
                          d="M7 18C7 18.5523 7.44772 19 8 19C8.55228 19 9 18.5523 9 18H7ZM8.70711 0.292893C8.31658 -0.0976311 7.68342 -0.0976311 7.29289 0.292893L0.928932 6.65685C0.538408 7.04738 0.538408 7.68054 0.928932 8.07107C1.31946 8.46159 1.95262 8.46159 2.34315 8.07107L8 2.41421L13.6569 8.07107C14.0474 8.46159 14.6805 8.46159 15.0711 8.07107C15.4616 7.68054 15.4616 7.04738 15.0711 6.65685L8.70711 0.292893ZM9 18L9 1H7L7 18H9Z"
                          className="fill-[--color-rosewood]"
                        />
                      </svg>
                    </button>
                  </Link>
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
                <div className="relative overflow-hidden rounded-3xl bg-white dark:bg-[#020617] shadow-[0_18px_40px_rgba(0,0,0,0.08)] dark:shadow-[0_18px_40px_rgba(0,0,0,0.6)] border border-[--color-warm-gray] dark:border-[#1f2933]">
                  <div className="aspect-[4/3] overflow-hidden">
                    <video
                      className="h-full w-full object-cover scale-105 transition-transform duration-700 ease-out hover:scale-110"
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
        <section className="bg-[--color-off-white] dark:bg-[#05060a] py-10 lg:py-14">
          <div className="container mx-auto px-4 space-y-6">
            <div className="grid gap-6 md:grid-cols-2">
              {/* Deliver card */}
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, amount: 0.4 }}
                variants={fadeInUp(0.1)}
                className="relative overflow-hidden rounded-3xl bg-white dark:bg-[#020617] shadow-[0_18px_40px_rgba(0,0,0,0.06)] dark:shadow-[0_18px_40px_rgba(0,0,0,0.6)] border border-[--color-warm-gray] dark:border-[#1f2933] px-8 py-8 flex flex-col gap-4"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="space-y-2">
                    <h2 className="text-xl font-semibold text-[--color-charcoal] dark:text-white">Deliver with Us</h2>
                    <p className="text-sm text-[--color-muted-foreground] dark:text-gray-300 max-w-sm">
                      Deliver orders, track earnings, and maximize your delivery schedule with flexible work.
                    </p>
                  </div>
                  <motion.img
                    src={isDark ? "/landing_page_reso/gif/icons8-truck-white.com-effects.gif" : "/landing_page_reso/gif/icons8-truck.gif"}
                    alt="Delivery icon"
                    className="h-16 w-16 object-contain"
                    initial={{ scale: 0.8, opacity: 0 }}
                    whileInView={{ scale: 1, opacity: 1 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                  />
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
                className="relative overflow-hidden rounded-3xl bg-white dark:bg-[#020617] shadow-[0_18px_40px_rgba(0,0,0,0.06)] dark:shadow-[0_18px_40px_rgba(0,0,0,0.6)] border border-[--color-warm-gray] dark:border-[#1f2933] px-8 py-8 flex flex-col gap-4"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="space-y-2">
                    <h2 className="text-xl font-semibold text-[--color-charcoal] dark:text-white">Partner with Yamada</h2>
                    <p className="text-sm text-[--color-muted-foreground] dark:text-gray-300 max-w-sm">
                      Open your shop, upload products, manage inventory, and reach fashion-forward customers.
                    </p>
                  </div>
                  <motion.img
                    src={isDark ? "/landing_page_reso/gif/icons8-shop-white.com-effects.gif" : "/landing_page_reso/gif/icons8-shop.gif"}
                    alt="Shop icon"
                    className="h-16 w-16 object-contain"
                    initial={{ scale: 0.8, opacity: 0 }}
                    whileInView={{ scale: 1, opacity: 1 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.3, type: "spring", stiffness: 200 }}
                  />
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
        <section className="bg-white dark:bg-[#05060a] py-12 lg:py-16">
          <div className="container mx-auto px-4">
            <motion.div
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, amount: 0.4 }}
              variants={fadeInUp(0)}
              className="mb-8 text-center"
            >
              <h2 className="text-2xl sm:text-3xl font-semibold text-[--color-charcoal] dark:text-white mb-2">
                Why Shop with Yamada?
              </h2>
              <p className="text-sm sm:text-base text-[--color-muted-foreground] dark:text-gray-300">
                Designed for women. Designed for you.
              </p>
            </motion.div>

            <div className="overflow-hidden rounded-3xl border border-[--color-warm-gray] dark:border-[#1f2933] bg-[--color-off-white] dark:bg-[#020617] shadow-[0_18px_40px_rgba(0,0,0,0.04)] dark:shadow-[0_18px_40px_rgba(0,0,0,0.6)] px-6 py-8 sm:px-10 sm:py-10">
              <div className="grid gap-8 md:grid-cols-4">
                {[
                  {
                    title: "Trendy & Curated Collections",
                    description:
                      "From chic dresses to activewear – everything is handpicked to match your look.",
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
                ].map((item, index) => (
                  <motion.div
                    key={item.title}
                    initial="hidden"
                    whileInView="visible"
                    viewport={{ once: true, amount: 0.4 }}
                    variants={fadeInUp(0.1 + index * 0.1)}
                    className="flex flex-col items-start gap-3 border-b last:border-b-0 md:border-b-0 md:border-r last:md:border-r-0 border-[--color-warm-gray]/60 pb-6 last:pb-0 md:pb-0 md:pr-6 last:md:pr-0"
                  >
                    <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[--color-secondary] dark:bg-[#111827] text-lg text-[--color-charcoal] dark:text-[#f9fafb]">
                      <Icon name={item.icon} size="lg" />
                    </div>
                    <h3 className="text-sm font-semibold text-[--color-charcoal] dark:text-white">
                      {item.title}
                    </h3>
                    <p className="text-xs sm:text-sm text-[--color-muted-foreground] dark:text-gray-300">
                      {item.description}
                    </p>
                  </motion.div>
                ))}
              </div>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}

