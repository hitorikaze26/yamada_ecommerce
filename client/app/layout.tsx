import type React from "react"
import type { Metadata, Viewport } from "next"
import { Analytics } from "@vercel/analytics/next"
import "./globals.css"
import { ThemeProvider } from "@/components/providers/theme-provider"
import { AuthProvider } from "@/context/auth-context"
import { CartProvider } from "@/context/cart-context"
import { WishlistProvider } from "@/context/wishlist-context"
import { NotificationProvider } from "@/context/notification-context"
import { ChatProvider } from "@/context/chat-context"
import { Toaster } from "@/components/ui/toaster"

export const metadata: Metadata = {
  title: "Yamada | Women's Apparel",
  description:
    "Discover the latest in women's fashion at Yamada. Shop dresses, tops, activewear, and more with a feminine modern touch.",
  keywords: ["women fashion", "apparel", "dresses", "clothing", "yamada"],
    generator: 'v0.app'
}

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FAF7F9" },
    { media: "(prefers-color-scheme: dark)", color: "#1E2A3A" },
  ],
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap"
        />
        <link
          rel="stylesheet"
          href="https://cdn-uicons.flaticon.com/2.6.0/uicons-regular-rounded/css/uicons-regular-rounded.css"
        />
        <link rel="icon" type="image/png" sizes="32x32" href="/logo/favicon-32x32.png" />
      </head>
      <body className="font-sans antialiased">
        <ThemeProvider>
          <AuthProvider>
            <NotificationProvider>
              <ChatProvider>
                <WishlistProvider>
                  <CartProvider>
                    {children}
                    <Toaster />
                  </CartProvider>
                </WishlistProvider>
              </ChatProvider>
            </NotificationProvider>
          </AuthProvider>
        </ThemeProvider>
        <Analytics />
      </body>
    </html>
  )
}
