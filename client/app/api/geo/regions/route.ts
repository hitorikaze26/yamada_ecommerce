import { NextResponse } from "next/server"
import axios from "axios"

const PH_SGG_BASE_URL = process.env.NEXT_PUBLIC_PH_SGG_BASE_URL || "https://psgc.gitlab.io/api"

// Fallback mock data for regions (PSGC codes are 9 digits)
const fallbackRegions = [
  { code: "010000000", name: "Region I (Ilocos Region)" },
  { code: "020000000", name: "Region II (Cagayan Valley)" },
  { code: "030000000", name: "Region III (Central Luzon)" },
  { code: "040000000", name: "Region IV-A (CALABARZON)" },
  { code: "050000000", name: "Region V (Bicol Region)" },
  { code: "060000000", name: "Region VI (Western Visayas)" },
  { code: "070000000", name: "Region VII (Central Visayas)" },
  { code: "080000000", name: "Region VIII (Eastern Visayas)" },
  { code: "090000000", name: "Region IX (Zamboanga Peninsula)" },
  { code: "100000000", name: "Region X (Northern Mindanao)" },
  { code: "110000000", name: "Region XI (Davao Region)" },
  { code: "120000000", name: "Region XII (SOCCSKSARGEN)" },
  { code: "130000000", name: "National Capital Region (NCR)" },
  { code: "140000000", name: "Cordillera Administrative Region (CAR)" },
  { code: "150000000", name: "Bangsamoro Autonomous Region in Muslim Mindanao (BARMM)" },
  { code: "160000000", name: "Region XIII (Caraga)" },
  { code: "170000000", name: "Mimaropa Region" },
]

export async function GET() {
  try {
    const response = await axios.get(`${PH_SGG_BASE_URL}/regions`, {
      timeout: 30000,
    })
    // PSGC API may return {value: [...]} or just [...]
    const data = response.data?.value || response.data || []
    console.log(`[API /regions] Returned ${data.length} regions`)
    return NextResponse.json(data)
  } catch (error) {
    console.error("[API /regions] Failed to fetch regions:", error)
    // Return fallback data instead of error
    return NextResponse.json(fallbackRegions)
  }
}
