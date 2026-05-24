import { NextResponse } from "next/server"
import axios from "axios"

const PH_SGG_BASE_URL = process.env.NEXT_PUBLIC_PH_SGG_BASE_URL || "https://psgc.gitlab.io/api"

// Fallback mock data for all regions (PSGC codes are 9 digits)
const fallbackProvinces: Record<string, Array<{ code: string; name: string }>> = {
  "010000000": [{ code: "012800000", name: "Ilocos Norte" }, { code: "012900000", name: "Ilocos Sur" }, { code: "013300000", name: "La Union" }, { code: "015500000", name: "Pangasinan" }],
  "020000000": [{ code: "020900000", name: "Batanes" }, { code: "021500000", name: "Cagayan" }, { code: "023100000", name: "Isabela" }, { code: "025000000", name: "Nueva Vizcaya" }, { code: "025700000", name: "Quirino" }],
  "030000000": [{ code: "030800000", name: "Bataan" }, { code: "031400000", name: "Bulacan" }, { code: "034900000", name: "Nueva Ecija" }, { code: "035400000", name: "Pampanga" }, { code: "036900000", name: "Tarlac" }, { code: "037100000", name: "Zambales" }, { code: "037700000", name: "Aurora" }],
  "040000000": [{ code: "041000000", name: "Batangas" }, { code: "042100000", name: "Cavite" }, { code: "043400000", name: "Laguna" }, { code: "045600000", name: "Quezon" }, { code: "045800000", name: "Rizal" }],
  "050000000": [{ code: "050500000", name: "Albay" }, { code: "051600000", name: "Camarines Norte" }, { code: "051700000", name: "Camarines Sur" }, { code: "052000000", name: "Catanduanes" }, { code: "054100000", name: "Masbate" }, { code: "056200000", name: "Sorsogon" }],
  "060000000": [{ code: "060400000", name: "Aklan" }, { code: "060600000", name: "Antique" }, { code: "061900000", name: "Capiz" }, { code: "067900000", name: "Guimaras" }, { code: "063000000", name: "Iloilo" }, { code: "064500000", name: "Negros Occidental" }],
  "070000000": [{ code: "071200000", name: "Bohol" }, { code: "072200000", name: "Cebu" }, { code: "074600000", name: "Negros Oriental" }, { code: "076100000", name: "Siquijor" }],
  "080000000": [{ code: "082600000", name: "Biliran" }, { code: "083700000", name: "Eastern Samar" }, { code: "084800000", name: "Leyte" }, { code: "086400000", name: "Northern Samar" }, { code: "086000000", name: "Samar" }, { code: "087800000", name: "Southern Leyte" }],
  "090000000": [{ code: "097200000", name: "Zamboanga del Norte" }, { code: "097300000", name: "Zamboanga del Sur" }, { code: "098300000", name: "Zamboanga Sibugay" }],
  "100000000": [{ code: "101300000", name: "Bukidnon" }, { code: "101800000", name: "Camiguin" }, { code: "103500000", name: "Lanao del Norte" }, { code: "104200000", name: "Misamis Occidental" }, { code: "104300000", name: "Misamis Oriental" }],
  "110000000": [{ code: "112300000", name: "Davao de Oro" }, { code: "112400000", name: "Davao del Norte" }, { code: "112500000", name: "Davao del Sur" }, { code: "118200000", name: "Davao Occidental" }, { code: "118600000", name: "Davao Oriental" }],
  "120000000": [{ code: "124700000", name: "Cotabato" }, { code: "126300000", name: "Sarangani" }, { code: "126500000", name: "South Cotabato" }, { code: "128000000", name: "Sultan Kudarat" }],
  // NCR (130000000) has NO provinces - cities are directly under region
  "140000000": [{ code: "140100000", name: "Abra" }, { code: "141100000", name: "Benguet" }, { code: "142700000", name: "Ifugao" }, { code: "143200000", name: "Kalinga" }, { code: "144400000", name: "Mountain Province" }, { code: "148100000", name: "Apayao" }],
  "150000000": [{ code: "150700000", name: "Basilan" }, { code: "153600000", name: "Lanao del Sur" }, { code: "153800000", name: "Maguindanao" }, { code: "156600000", name: "Sulu" }, { code: "157000000", name: "Tawi-Tawi" }],
  "160000000": [{ code: "160300000", name: "Agusan del Norte" }, { code: "160400000", name: "Agusan del Sur" }, { code: "168500000", name: "Surigao del Norte" }, { code: "168600000", name: "Surigao del Sur" }, { code: "168700000", name: "Dinagat Islands" }],
  "170000000": [{ code: "174000000", name: "Marinduque" }, { code: "175100000", name: "Occidental Mindoro" }, { code: "175200000", name: "Oriental Mindoro" }, { code: "175300000", name: "Palawan" }, { code: "175900000", name: "Romblon" }],
}

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

  // NCR (National Capital Region) has NO provinces - return empty array
  if (isNCR(regionCode)) {
    return NextResponse.json([])
  }

  // PSGC region codes are 9 digits - ensure proper format
  let normalized = String(regionCode).trim()
  if (normalized.length > 9) {
    normalized = normalized.slice(0, 9)
  } else if (normalized.length < 9) {
    normalized = normalized.padEnd(9, '0')
  }

  try {
    const response = await axios.get(
      `${PH_SGG_BASE_URL}/regions/${normalized}/provinces`,
      { timeout: 30000 }
    )
    // PSGC API may return {value: [...]} or just [...]
    const data = response.data?.value || response.data || []
    console.log(`[API /provinces] Region ${regionCode} (normalized to 9-digit: ${normalized}) returned:`, data)
    return NextResponse.json(data)
  } catch (error) {
    console.error(`Failed to fetch provinces for region ${regionCode} (normalized ${normalized}):`, error)

    // Return fallback data if available (try normalized key)
    if (fallbackProvinces[normalized]) {
      return NextResponse.json(fallbackProvinces[normalized])
    }
    if (fallbackProvinces[regionCode]) {
      return NextResponse.json(fallbackProvinces[regionCode])
    }

    return NextResponse.json(
      { error: "Failed to fetch provinces" },
      { status: 500 }
    )
  }
}
