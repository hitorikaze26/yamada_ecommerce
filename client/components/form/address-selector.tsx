"use client"

import { useState, useEffect, useCallback } from "react"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { phGeoApi, isNCRRegion, type AddressData } from "@/lib/api"
import { Icon } from "@/components/ui/icon"

interface AddressSelectorProps {
  value: AddressData | null
  onChange: (address: AddressData) => void
}

interface GeoOption {
  code: string
  name: string
}

export function AddressSelector({ value, onChange }: AddressSelectorProps) {
  const [regions, setRegions] = useState<GeoOption[]>([])
  const [provinces, setProvinces] = useState<GeoOption[]>([])
  const [municipalities, setMunicipalities] = useState<GeoOption[]>([])
  const [barangays, setBarangays] = useState<GeoOption[]>([])

  const [isLoadingRegions, setIsLoadingRegions] = useState(true)
  const [isLoadingProvinces, setIsLoadingProvinces] = useState(false)
  const [isLoadingMunicipalities, setIsLoadingMunicipalities] = useState(false)
  const [isLoadingBarangays, setIsLoadingBarangays] = useState(false)

  const [selectedRegion, setSelectedRegion] = useState(value?.regionCode || "")
  const [selectedProvince, setSelectedProvince] = useState(value?.provinceCode || "")
  const [selectedMunicipality, setSelectedMunicipality] = useState(value?.municipalityCode || "")
  const [selectedBarangay, setSelectedBarangay] = useState(value?.barangayCode || "")
  const [streetAddress, setStreetAddress] = useState(value?.streetAddress || "")
  const [postalCode, setPostalCode] = useState(value?.postalCode || "")

  // Load regions on mount
  useEffect(() => {
    const loadRegions = async () => {
      try {
        const response = await phGeoApi.getRegions()
        // PSGC API returns a flat array of {code, name, regionName, ...}
        const regionsData = Array.isArray(response.data) ? response.data : response.data?.regions || []
        const formattedRegions = regionsData.map((r: string | { code: string; name: string }) => {
          if (typeof r === 'string') {
            return { code: r, name: r }
          }
          return r
        })
        setRegions(formattedRegions)
      } catch (error) {
        console.error("Failed to load regions:", error)
        // No fallback - let user retry
        setRegions([])
      } finally {
        setIsLoadingRegions(false)
      }
    }
    loadRegions()
  }, [])

  // Check if selected region is NCR (Metro Manila) - has no provinces
  const isNCR = isNCRRegion(selectedRegion)

  // Load provinces when region changes (skip for NCR)
  useEffect(() => {
    const loadProvinces = async () => {
      if (!selectedRegion || isNCR) {
        setProvinces([])
        return
      }
      setIsLoadingProvinces(true)
      try {
        console.log("[AddressSelector] Loading provinces for region:", selectedRegion)
        const response = await phGeoApi.getProvinces(selectedRegion)
        console.log("[AddressSelector] Provinces raw response:", response.data)
        // PSGC API returns a flat array of {code, name, ...}
        const provincesData = Array.isArray(response.data) ? response.data : response.data?.provinces || []
        const formattedProvinces = provincesData.map((p: any) => ({
          code: p.code?.toString() || '',
          name: p.name || p.provinceName || 'Unknown'
        })).filter((p: GeoOption) => p.code)
        console.log("[AddressSelector] Formatted provinces:", formattedProvinces)
        setProvinces(formattedProvinces)
      } catch (error) {
        console.error("[AddressSelector] Error loading provinces:", error)
        setProvinces([])
      } finally {
        setIsLoadingProvinces(false)
      }
    }
    loadProvinces()
  }, [selectedRegion, isNCR])

  // Load municipalities/cities when province is selected (or directly for NCR)
  useEffect(() => {
    const loadMunicipalities = async () => {
      // For NCR: load cities directly without province
      // For others: require province
      console.log("[AddressSelector] Checking municipalities - region:", selectedRegion, "province:", selectedProvince, "isNCR:", isNCR)
      if (!selectedRegion || (!isNCR && !selectedProvince)) {
        console.log("[AddressSelector] Skipping municipalities - missing required params")
        setMunicipalities([])
        return
      }
      
      setIsLoadingMunicipalities(true)
      try {
        console.log("[AddressSelector] Loading municipalities for region:", selectedRegion, "province:", selectedProvince)
        // Use updated phGeoApi that handles NCR internally
        const response = await phGeoApi.getMunicipalities(selectedRegion, selectedProvince)
        console.log("[AddressSelector] Municipalities raw response:", response.data)
        // PSGC API returns a flat array of {code, name, ...}
        const citiesData = Array.isArray(response.data) ? response.data : response.data?.cities || []
        const formattedCities = citiesData.map((c: any) => ({
          code: c.code?.toString() || '',
          name: c.name || c.cityName || 'Unknown'
        })).filter((c: GeoOption) => c.code)
        console.log("[AddressSelector] Formatted municipalities:", formattedCities)
        setMunicipalities(formattedCities)
      } catch (error) {
        console.error("[AddressSelector] Error loading cities:", error)
        setMunicipalities([])
      } finally {
        setIsLoadingMunicipalities(false)
      }
    }
    loadMunicipalities()
  }, [selectedRegion, selectedProvince, isNCR])

  // Load barangays when city/municipality is selected
  useEffect(() => {
    const loadBarangays = async () => {
      if (!selectedMunicipality) {
        setBarangays([])
        return
      }
      setIsLoadingBarangays(true)
      try {
        const response = await phGeoApi.getBarangays(selectedMunicipality)
        // PSGC API returns a flat array of {code, name, ...}
        const barangaysData = Array.isArray(response.data) ? response.data : response.data?.barangays || []
        const formattedBarangays = barangaysData.map((b: any) => ({
          code: b.code?.toString() || '',
          name: b.name || 'Unknown'
        })).filter((b: GeoOption) => b.code)
        setBarangays(formattedBarangays)
      } catch (error) {
        console.error("Error loading barangays:", error)
        setBarangays([])
      } finally {
        setIsLoadingBarangays(false)
      }
    }
    loadBarangays()
  }, [selectedMunicipality])

  const updateAddress = useCallback(() => {
    const region = regions.find((r) => r.code === selectedRegion)
    const province = provinces.find((p) => p.code === selectedProvince)
    const municipality = municipalities.find((m) => m.code === selectedMunicipality)
    const barangay = barangays.find((b) => b.code === selectedBarangay)

    // For NCR: province is not required
    // For other regions: all fields required
    const regionIsNCR = isNCRRegion(selectedRegion)
    const hasRequiredFields = region && municipality && barangay && (regionIsNCR || province)

    if (hasRequiredFields) {
      onChange({
        regionCode: selectedRegion,
        regionName: region?.name || "",
        provinceCode: regionIsNCR ? "" : (selectedProvince || ""),
        provinceName: regionIsNCR ? "N/A (NCR)" : (province?.name || ""),
        municipalityCode: selectedMunicipality,
        municipalityName: municipality?.name || "",
        barangayCode: selectedBarangay,
        barangayName: barangay?.name || "",
        streetAddress,
        postalCode,
      })
    }
  }, [
    selectedRegion,
    selectedProvince,
    selectedMunicipality,
    selectedBarangay,
    streetAddress,
    postalCode,
    regions,
    provinces,
    municipalities,
    barangays,
  ])

  // Update parent whenever selection changes
  useEffect(() => {
    updateAddress()
  }, [selectedRegion, selectedProvince, selectedMunicipality, selectedBarangay, streetAddress, postalCode, updateAddress])

  const handleRegionChange = (code: string) => {
    setSelectedRegion(code)
    setSelectedProvince("")
    setSelectedMunicipality("")
    setSelectedBarangay("")
    setProvinces([])
    setMunicipalities([])
    setBarangays([])
  }

  const handleProvinceChange = (code: string) => {
    setSelectedProvince(code)
    setSelectedMunicipality("")
    setSelectedBarangay("")
    setMunicipalities([])
    setBarangays([])
  }

  const handleMunicipalityChange = (code: string) => {
    setSelectedMunicipality(code)
    setSelectedBarangay("")
    setBarangays([])
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label>Region</Label>
          <Select value={selectedRegion} onValueChange={handleRegionChange} disabled={isLoadingRegions}>
            <SelectTrigger className="w-full truncate">
              <SelectValue className="truncate" placeholder={isLoadingRegions ? "Loading..." : "Select region"} />
            </SelectTrigger>
            <SelectContent>
              {regions.map((region) => (
                <SelectItem key={region.code} value={region.code}>
                  {region.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label>Province {isNCR && "(N/A for NCR)"}</Label>
          <Select
            value={selectedProvince}
            onValueChange={handleProvinceChange}
            disabled={!selectedRegion || isNCR || isLoadingProvinces || provinces.length === 0}
          >
            <SelectTrigger className="w-full truncate">
              <SelectValue className="truncate" placeholder={isNCR ? "N/A - NCR has no provinces" : isLoadingProvinces ? "Loading..." : "Select province"} />
            </SelectTrigger>
            <SelectContent>
              {provinces.map((province) => (
                <SelectItem key={province.code} value={province.code}>
                  {province.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="space-y-2">
          <Label>City/Municipality</Label>
          <Select
            value={selectedMunicipality}
            onValueChange={handleMunicipalityChange}
            disabled={!selectedRegion || (!isNCR && !selectedProvince) || isLoadingMunicipalities}
          >
            <SelectTrigger className="w-full truncate">
              <SelectValue className="truncate" placeholder={isLoadingMunicipalities ? "Loading..." : "Select city/municipality"} />
            </SelectTrigger>
            <SelectContent>
              {municipalities.map((municipality) => (
                <SelectItem key={municipality.code} value={municipality.code}>
                  {municipality.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-2">
          <Label>Barangay</Label>
          <Select
            value={selectedBarangay}
            onValueChange={setSelectedBarangay}
            disabled={!selectedMunicipality || isLoadingBarangays}
          >
            <SelectTrigger className="w-full truncate">
              <SelectValue className="truncate" placeholder={isLoadingBarangays ? "Loading..." : "Select barangay"} />
            </SelectTrigger>
            <SelectContent>
              {barangays.map((barangay) => (
                <SelectItem key={barangay.code} value={barangay.code}>
                  {barangay.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="space-y-2">
        <Label>Street Address (Optional)</Label>
        <Input
          placeholder="House/Unit/Building No., Street Name"
          value={streetAddress}
          onChange={(e) => setStreetAddress(e.target.value)}
        />
      </div>

      <div className="space-y-2">
        <Label>Postal Code (Optional)</Label>
        <Input placeholder="1234" value={postalCode} onChange={(e) => setPostalCode(e.target.value)} maxLength={4} />
      </div>

      {value && value.barangayName && (
        <div className="p-3 bg-muted rounded-lg text-sm">
          <div className="flex items-start gap-2">
            <Icon name="marker" className="text-primary mt-0.5" />
            <div>
              <p className="font-medium">Selected Address</p>
              <p className="text-muted-foreground">
                {[value.streetAddress, value.barangayName, value.municipalityName, value.provinceName, value.regionName]
                  .filter(Boolean)
                  .join(", ")}
                {value.postalCode && ` ${value.postalCode}`}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
