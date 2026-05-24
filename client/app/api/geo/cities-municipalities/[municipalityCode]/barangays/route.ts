import { NextResponse } from "next/server"
import axios from "axios"

const PH_SGG_BASE_URL = process.env.NEXT_PUBLIC_PH_SGG_BASE_URL || "https://psgc.gitlab.io/api"

// Fallback mock data for common cities/municipalities
const fallbackBarangays: Record<string, Array<{ code: string; name: string }>> = {
  "133912000": [
    { code: "133912001", name: "Bangkal" },
    { code: "133912002", name: "Bel-Air" },
    { code: "133912003", name: "Carmona" },
    { code: "133912004", name: "Dasmariñas" },
    { code: "133912005", name: "Forbes Park" },
    { code: "133912006", name: "Kasilawan" },
    { code: "133912007", name: "La Paz" },
    { code: "133912008", name: "Magallanes" },
    { code: "133912009", name: "Olympia" },
    { code: "133912010", name: "Palanan" },
    { code: "133912011", name: "Pio del Pilar" },
    { code: "133912012", name: "Poblacion" },
    { code: "133912013", name: "San Antonio" },
    { code: "133912014", name: "San Isidro" },
    { code: "133912015", name: "San Lorenzo" },
    { code: "133912016", name: "Singkamas" },
    { code: "133912017", name: "Tejeros" },
    { code: "133912018", name: "Urdaneta" },
    { code: "133912019", name: "Valenzuela" },
  ],
  "137404000": [
    { code: "137404001", name: "Baritan" },
    { code: "137404002", name: "Bayan-bayanan" },
    { code: "137404003", name: "Catmon" },
    { code: "137404004", name: "Concepcion" },
    { code: "137404005", name: "Dampalit" },
    { code: "137404006", name: "Flores" },
    { code: "137404007", name: "Hulong Duhat" },
    { code: "137404008", name: "Ibaba" },
    { code: "137404009", name: "Longos" },
    { code: "137404010", name: "Maysilo" },
    { code: "137404011", name: "Muzon" },
    { code: "137404012", name: "Niugan" },
    { code: "137404013", name: "Panghulo" },
    { code: "137404014", name: "Potrero" },
    { code: "137404015", name: "San Agustin" },
    { code: "137404016", name: "Santolan" },
    { code: "137404017", name: "Tañong" },
    { code: "137404018", name: "Tinajeros" },
    { code: "137404019", name: "Tonsuya" },
  ],
}

export async function GET(
  request: Request,
  { params }: { params: Promise<{ municipalityCode: string }> }
) {
  const { municipalityCode } = await params
  // PSGC codes are 9 digits - ensure proper format
  let normalized = String(municipalityCode).trim()
  if (normalized.length > 9) {
    normalized = normalized.slice(0, 9)
  } else if (normalized.length < 9) {
    normalized = normalized.padEnd(9, '0')
  }

  try {
    console.log(`[API /barangays] Fetching for municipality: ${municipalityCode} (normalized to 9-digit: ${normalized})`)
    const response = await axios.get(
      `${PH_SGG_BASE_URL}/cities-municipalities/${normalized}/barangays`,
      { timeout: 30000 }
    )
    // PSGC API may return {value: [...]} or just [...]
    const data = response.data?.value || response.data || []
    console.log(`[API /barangays] Municipality ${municipalityCode} returned ${data.length} barangays`)
    return NextResponse.json(data)
  } catch (error) {
    console.error(`[API /barangays] Failed to fetch barangays for municipality ${municipalityCode} (normalized ${normalized}):`, error)

    // Return fallback data if available (try normalized key)
    if (fallbackBarangays[normalized]) {
      return NextResponse.json(fallbackBarangays[normalized])
    }
    if (fallbackBarangays[municipalityCode]) {
      return NextResponse.json(fallbackBarangays[municipalityCode])
    }

    // No fallback available — return empty array to let the client handle gracefully
    return NextResponse.json([])
  }
}
