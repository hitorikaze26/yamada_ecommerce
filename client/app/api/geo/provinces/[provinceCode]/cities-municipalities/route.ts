import { NextResponse } from "next/server"
import axios from "axios"

const PH_SGG_BASE_URL = process.env.NEXT_PUBLIC_PH_SGG_BASE_URL || "https://psgc.gitlab.io/api"

// Fallback mock data for common provinces (PSGC codes are 9 digits)
const fallbackCities: Record<string, Array<{ code: string; name: string }>> = {
  // Laguna (043400000)
  "043400000": [
    { code: "043404000", name: "Biñan City" },
    { code: "043405000", name: "Cabuyao City" },
    { code: "043406000", name: "Calamba City" },
    { code: "043407000", name: "San Pablo City" },
    { code: "043408000", name: "San Pedro City" },
    { code: "043409000", name: "Santa Rosa City" },
    { code: "043410000", name: "Alaminos" },
    { code: "043411000", name: "Bay" },
    { code: "043412000", name: "Calauan" },
    { code: "043413000", name: "Cavinti" },
    { code: "043414000", name: "Famy" },
    { code: "043415000", name: "Kalayaan" },
    { code: "043416000", name: "Liliw" },
    { code: "043417000", name: "Los Baños" },
    { code: "043418000", name: "Luisiana" },
    { code: "043419000", name: "Lumban" },
    { code: "043420000", name: "Mabitac" },
    { code: "043421000", name: "Magdalena" },
    { code: "043422000", name: "Majayjay" },
    { code: "043423000", name: "Nagcarlan" },
    { code: "043424000", name: "Paete" },
    { code: "043425000", name: "Pagsanjan" },
    { code: "043426000", name: "Pakil" },
    { code: "043427000", name: "Pangil" },
    { code: "043428000", name: "Pila" },
    { code: "043429000", name: "Rizal" },
    { code: "043430000", name: "Santa Cruz" },
    { code: "043431000", name: "Santa Maria" },
    { code: "043432000", name: "Siniloan" },
    { code: "043433000", name: "Victoria" },
  ],
  // Oriental Mindoro (175200000)
  "175200000": [
    { code: "175201000", name: "Calapan City" },
    { code: "175202000", name: "Baco" },
    { code: "175203000", name: "Bansud" },
    { code: "175204000", name: "Bongabong" },
    { code: "175205000", name: "Bulalacao" },
    { code: "175206000", name: "Gloria" },
    { code: "175207000", name: "Mansalay" },
    { code: "175208000", name: "Naujan" },
    { code: "175209000", name: "Pinamalayan" },
    { code: "175210000", name: "Pola" },
    { code: "175211000", name: "Puerto Galera" },
    { code: "175212000", name: "Roxas" },
    { code: "175213000", name: "San Teodoro" },
    { code: "175214000", name: "Socorro" },
    { code: "175215000", name: "Victoria" },
  ],
  // Cavite (042100000)
  "042100000": [
    { code: "042103000", name: "Cavite City" },
    { code: "042104000", name: "Dasmariñas City" },
    { code: "042105000", name: "General Trias City" },
    { code: "042106000", name: "Imus City" },
    { code: "042107000", name: "Tagaytay City" },
    { code: "042108000", name: "Trece Martires City" },
    { code: "042109000", name: "Bacoor City" },
    { code: "042110000", name: "Carmona" },
    { code: "042111000", name: "General Mariano Alvarez" },
    { code: "042112000", name: "Kawit" },
    { code: "042113000", name: "Magallanes" },
    { code: "042114000", name: "Maragondon" },
    { code: "042115000", name: "Mendez" },
    { code: "042116000", name: "Naic" },
    { code: "042117000", name: "Noveleta" },
    { code: "042118000", name: "Rosario" },
    { code: "042119000", name: "Silang" },
    { code: "042120000", name: "Tanza" },
    { code: "042121000", name: "Ternate" },
  ],
  // Batangas (041000000)
  "041000000": [
    { code: "041003000", name: "Batangas City" },
    { code: "041004000", name: "Lipa City" },
    { code: "041005000", name: "Tanauan City" },
    { code: "041006000", name: "Agoncillo" },
    { code: "041007000", name: "Alitagtag" },
    { code: "041008000", name: "Balayan" },
    { code: "041009000", name: "Balete" },
    { code: "041010000", name: "Bauan" },
    { code: "041011000", name: "Calaca" },
    { code: "041012000", name: "Calatagan" },
    { code: "041013000", name: "Cuenca" },
    { code: "041014000", name: "Ibaan" },
    { code: "041015000", name: "Laurel" },
    { code: "041016000", name: "Lemery" },
    { code: "041017000", name: "Lian" },
    { code: "041018000", name: "Mabini" },
    { code: "041019000", name: "Malvar" },
    { code: "041020000", name: "Mataasnakahoy" },
    { code: "041021000", name: "Nasugbu" },
    { code: "041022000", name: "Padre Garcia" },
    { code: "041023000", name: "Rosario" },
    { code: "041024000", name: "San Jose" },
    { code: "041025000", name: "San Juan" },
    { code: "041026000", name: "San Luis" },
    { code: "041027000", name: "San Nicolas" },
    { code: "041028000", name: "San Pascual" },
    { code: "041029000", name: "Santa Teresita" },
    { code: "041030000", name: "Santo Tomas" },
    { code: "041031000", name: "Taal" },
    { code: "041032000", name: "Talisay" },
    { code: "041033000", name: "Taysan" },
    { code: "041034000", name: "Tingloy" },
    { code: "041035000", name: "Tuy" },
  ],
  // Quezon (045600000)
  "045600000": [
    { code: "045601000", name: "Lucena City" },
    { code: "045602000", name: "Tayabas City" },
    { code: "045603000", name: "Agdangan" },
    { code: "045604000", name: "Alabat" },
    { code: "045605000", name: "Atimonan" },
    { code: "045606000", name: "Buenavista" },
    { code: "045607000", name: "Burdeos" },
    { code: "045608000", name: "Calauag" },
    { code: "045609000", name: "Candelaria" },
    { code: "045610000", name: "Catanauan" },
    { code: "045611000", name: "Dolores" },
    { code: "045612000", name: "General Luna" },
    { code: "045613000", name: "General Nakar" },
    { code: "045614000", name: "Guinayangan" },
    { code: "045615000", name: "Gumaca" },
    { code: "045616000", name: "Infanta" },
    { code: "045617000", name: "Jomalig" },
    { code: "045618000", name: "Lopez" },
    { code: "045619000", name: "Lucban" },
    { code: "045620000", name: "Macalelon" },
    { code: "045621000", name: "Mauban" },
    { code: "045622000", name: "Mulanay" },
    { code: "045623000", name: "Padre Burgos" },
    { code: "045624000", name: "Pagbilao" },
    { code: "045625000", name: "Panukulan" },
    { code: "045626000", name: "Patnanungan" },
    { code: "045627000", name: "Perez" },
    { code: "045628000", name: "Pitogo" },
    { code: "045629000", name: "Plaridel" },
    { code: "045630000", name: "Polillo" },
    { code: "045631000", name: "Quezon" },
    { code: "045632000", name: "Real" },
    { code: "045633000", name: "Sampaloc" },
    { code: "045634000", name: "San Andres" },
    { code: "045635000", name: "San Antonio" },
    { code: "045636000", name: "San Francisco" },
    { code: "045637000", name: "San Narciso" },
    { code: "045638000", name: "Sariaya" },
    { code: "045639000", name: "Tagkawayan" },
    { code: "045640000", name: "Tiaong" },
    { code: "045641000", name: "Unisan" },
  ],
  // Rizal (045800000)
  "045800000": [
    { code: "045801000", name: "Antipolo City" },
    { code: "045802000", name: "Angono" },
    { code: "045803000", name: "Baras" },
    { code: "045804000", name: "Binangonan" },
    { code: "045805000", name: "Cainta" },
    { code: "045806000", name: "Cardona" },
    { code: "045807000", name: "Jalajala" },
    { code: "045808000", name: "Morong" },
    { code: "045809000", name: "Pililla" },
    { code: "045810000", name: "Rodriguez" },
    { code: "045811000", name: "San Mateo" },
    { code: "045812000", name: "Tanay" },
    { code: "045813000", name: "Taytay" },
    { code: "045814000", name: "Teresa" },
  ],
}

export async function GET(
  request: Request,
  { params }: { params: Promise<{ provinceCode: string }> }
) {
  const { provinceCode } = await params
  // PSGC codes are 9 digits - ensure proper format
  let normalized = String(provinceCode).trim()
  // Remove any trailing zeros beyond 9 digits, or pad to 9 digits
  if (normalized.length > 9) {
    normalized = normalized.slice(0, 9)
  } else if (normalized.length < 9) {
    normalized = normalized.padEnd(9, '0')
  }

  try {
    console.log(`[API /cities-municipalities] Fetching for province: ${provinceCode} (normalized to 9-digit: ${normalized})`)
    const response = await axios.get(`${PH_SGG_BASE_URL}/provinces/${normalized}/cities-municipalities`)
    // PSGC API may return {value: [...]} or just [...]
    const data = response.data?.value || response.data || []
    console.log(`[API /cities-municipalities] Province ${provinceCode} returned ${data.length} items:`, data)
    return NextResponse.json(data)
  } catch (error) {
    console.error(`Failed to fetch cities/municipalities for province ${provinceCode} (normalized ${normalized}):`, error)

    // Return fallback data if available (try normalized key)
    if (fallbackCities[normalized]) {
      return NextResponse.json(fallbackCities[normalized])
    }
    if (fallbackCities[provinceCode]) {
      return NextResponse.json(fallbackCities[provinceCode])
    }

    // No fallback available — return empty array to let the client handle gracefully
    return NextResponse.json([])
  }
}
