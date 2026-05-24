import { NextResponse } from "next/server"
import axios from "axios"

const PH_SGG_BASE_URL = process.env.NEXT_PUBLIC_PH_SGG_BASE_URL || "https://psgc.gitlab.io/api"

// NCR (National Capital Region) has no provinces, cities are directly under region
// These are the NCR cities/municipalities
const fallbackNCRCities = [
  { code: "137400000", name: "Caloocan City" },
  { code: "137500000", name: "Las Piñas City" },
  { code: "137600000", name: "Makati City" },
  { code: "137700000", name: "Malabon City" },
  { code: "137800000", name: "Mandaluyong City" },
  { code: "137900000", name: "Manila City" },
  { code: "138000000", name: "Marikina City" },
  { code: "138100000", name: "Muntinlupa City" },
  { code: "138200000", name: "Navotas City" },
  { code: "138300000", name: "Parañaque City" },
  { code: "138400000", name: "Pasay City" },
  { code: "138500000", name: "Pasig City" },
  { code: "138600000", name: "Pateros Municipality" },
  { code: "138700000", name: "Quezon City" },
  { code: "138800000", name: "San Juan City" },
  { code: "138900000", name: "Taguig City" },
  { code: "139000000", name: "Valenzuela City" },
  { code: "139100000", name: "Bacoor City" },
]

// Helper to check if region is NCR (130000000)
function isNCR(regionCode: string): boolean {
  const normalized = String(regionCode).trim()
  return normalized === "130000000" || normalized === "13" || normalized.startsWith("13")
}

export async function GET(
  request: Request,
  { params }: { params: Promise<{ regionCode: string }> }
) {
  const { regionCode } = await params

  // For NCR, return cities directly (NCR has no provinces)
  if (isNCR(regionCode)) {
    try {
      // Try to fetch from PSGC API first
      // PSGC codes are 9 digits - ensure proper format
      let normalized = String(regionCode).trim()
      if (normalized.length > 9) {
        normalized = normalized.slice(0, 9)
      } else if (normalized.length < 9) {
        normalized = normalized.padEnd(9, '0')
      }
      console.log(`[API /region-cities] Fetching NCR cities for region: ${regionCode} (normalized to 9-digit: ${normalized})`)
      const response = await axios.get(
        `${PH_SGG_BASE_URL}/regions/${normalized}/cities-municipalities`,
        { timeout: 30000 }
      )
      // PSGC API may return {value: [...]} or just [...]
      const data = response.data?.value || response.data || []
      console.log(`[API /region-cities] NCR returned ${data.length} cities`)
      return NextResponse.json(data)
    } catch (error) {
      console.error(`[API /region-cities] Failed to fetch NCR cities, using fallback:`, error)
      // Return fallback NCR cities
      return NextResponse.json(fallbackNCRCities)
    }
  }

  // For non-NCR regions, return empty array (they should use provinces endpoint first)
  console.log(`[API /region-cities] Region ${regionCode} is not NCR, returning empty. Use /provinces/[code]/cities-municipalities instead.`)
  return NextResponse.json([])
}
