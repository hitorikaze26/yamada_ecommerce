/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    remotePatterns: [
      // Localhost patterns for development
      {
        protocol: "http",
        hostname: "localhost",
        port: "3000",
        pathname: "/static/**",
      },
      {
        protocol: "http",
        hostname: "127.0.0.1",
        port: "3000",
        pathname: "/static/**",
      },
      {
        protocol: "http",
        hostname: "localhost",
        port: "5000",
        pathname: "/static/**",
      },
      {
        protocol: "http",
        hostname: "127.0.0.1",
        port: "5000",
        pathname: "/static/**",
      },
      // Production patterns (conditionally included based on env)
      ...(process.env.USE_PRODUCTION_URLS?.toLowerCase() === "true" ? [
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
          pathname: "/storage/v1/object/public/**",
        },
        {
          protocol: "https",
          hostname: "*.supabase.co",
          pathname: "/storage/v1/object/sign/**",
        },
        {
          protocol: "https",
          hostname: "placehold.co",
        },
      ] : []),
    ],
  },
  compiler: {
    styledComponents: true,
  },
  // Rewrites run on the Next.js server (never in the browser).
  // Development: Axios uses `/api` (relative), so these rewrites proxy to Flask.
  // Production:   Axios uses the full Railway URL, so these rewrites are unused.
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: "http://127.0.0.1:5000/api/:path*",
      },
      {
        source: "/api/geo/:path*",
        destination: "https://psgc.gitlab.io/api/:path*",
      },
    ]
  },
}

export default nextConfig
