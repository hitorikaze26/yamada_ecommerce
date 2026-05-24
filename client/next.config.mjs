/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: process.env.VERCEL_ENV === "preview",
  },
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**.vercel.app",
      },
      {
        protocol: "https",
        hostname: "**.railway.app",
      },
      {
        protocol: "https",
        hostname: "*.supabase.co",
      },
      {
        protocol: "https",
        hostname: "placehold.co",
      },
    ],
  },
  compiler: {
    styledComponents: true,
  },
  async rewrites() {
    return [
      {
        source: "/api/geo/:path*",
        destination: "https://psgc.gitlab.io/api/:path*",
      },
    ]
  },
}

export default nextConfig
