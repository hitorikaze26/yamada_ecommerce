/**
 * Shipping fee calculation service
 * Location-based shipping logic comparing seller and buyer addresses
 */

import type { AddressData } from './api'

export interface ShippingCalculation {
  fee: number
  isFree: boolean
  isEstimated?: boolean
  note?: string
}

export interface ShippingOptions {
  subtotal: number
  buyerAddress?: AddressData
  sellerAddress?: AddressData
}

// Shipping rates based on location comparison
export const SHIPPING_RATES = {
  SAME_CITY: 30,        // Same region, same province, same city
  SAME_PROVINCE: 35,    // Same region, same province, different city
  SAME_REGION: 70,      // Same region, different province
  DIFFERENT_REGION: 100 // Different region
} as const

// Free shipping and fallback constants
export const FREE_SHIPPING_THRESHOLD = 10000
export const FALLBACK_SHIPPING_FEE = 100

/**
 * Calculate shipping fee based on seller and buyer location comparison
 */
export function calculateShipping(options: ShippingOptions): ShippingCalculation {
  const { subtotal, buyerAddress, sellerAddress } = options

  // Free shipping for orders over threshold
  if (subtotal >= FREE_SHIPPING_THRESHOLD) {
    return {
      fee: 0,
      isFree: true,
      note: `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD.toLocaleString()}`
    }
  }

  // If no seller or buyer address, use highest rate as estimate
  if (!buyerAddress?.regionCode || !sellerAddress?.regionCode) {
    return {
      fee: SHIPPING_RATES.DIFFERENT_REGION,
      isFree: false,
      isEstimated: true,
      note: 'Shipping fee calculated at checkout based on locations'
    }
  }

  // Calculate shipping based on location comparison
  const fee = calculateLocationBasedShipping(
    sellerAddress.regionCode,
    sellerAddress.provinceCode || '',
    sellerAddress.municipalityCode || '',
    buyerAddress.regionCode,
    buyerAddress.provinceCode || '',
    buyerAddress.municipalityCode || ''
  )

  const note = getShippingNote(fee)

  return {
    fee,
    isFree: false,
    note
  }
}

/**
 * Calculate shipping fee based on location comparison between seller and buyer
 */
export function calculateLocationBasedShipping(
  sellerRegionCode: string,
  sellerProvinceCode: string, 
  sellerMunicipalityCode: string,
  buyerRegionCode: string,
  buyerProvinceCode: string,
  buyerMunicipalityCode: string
): number {
  // Normalize codes for comparison
  const normalize = (code: string) => code?.toLowerCase().trim() || ''
  
  const sRegion = normalize(sellerRegionCode)
  const sProvince = normalize(sellerProvinceCode)
  const sMunicipality = normalize(sellerMunicipalityCode)
  const bRegion = normalize(buyerRegionCode)
  const bProvince = normalize(buyerProvinceCode)
  const bMunicipality = normalize(buyerMunicipalityCode)

  // Log the comparison (matching mobile app format)
  console.log(`Using CODE-based comparison: seller(${sellerRegionCode}/${sellerProvinceCode}/${sellerMunicipalityCode}) vs buyer(${buyerRegionCode}/${buyerProvinceCode}/${buyerMunicipalityCode})`)

  let fee: number
  let reason: string

  // Apply shipping logic:
  // 1. same region, same province, same city = 30
  // 2. same region, same province, not same city = 35
  // 3. same region, not same province = 70
  // 4. not same region = 100
  
  if (sRegion === bRegion) {
    // Same region
    if (sProvince === bProvince) {
      // Same province
      if (sMunicipality === bMunicipality) {
        // Same city
        fee = SHIPPING_RATES.SAME_CITY
        reason = 'Same region, same province, same city'
      } else {
        // Different city
        fee = SHIPPING_RATES.SAME_PROVINCE
        reason = 'Same region, same province, different city'
      }
    } else {
      // Different province
      fee = SHIPPING_RATES.SAME_REGION
      reason = 'Same region, different province'
    }
  } else {
    // Different region
    fee = SHIPPING_RATES.DIFFERENT_REGION
    reason = 'Different region'
  }

  // Log the result (matching mobile app format)
  console.log(`Shipping fee calculated: ₱${fee}.0 - ${reason}`)

  return fee
}

/**
 * Get shipping note based on fee
 */
function getShippingNote(fee: number): string {
  switch (fee) {
    case SHIPPING_RATES.SAME_CITY:
      return 'Same city delivery'
    case SHIPPING_RATES.SAME_PROVINCE:
      return 'Same province delivery'
    case SHIPPING_RATES.SAME_REGION:
      return 'Same region delivery'
    case SHIPPING_RATES.DIFFERENT_REGION:
      return 'Inter-region delivery'
    default:
      return 'Shipping fee calculated'
  }
}

/**
 * Get shipping fee for cart display (no address needed)
 */
export function getCartShippingEstimate(subtotal: number): ShippingCalculation {
  if (subtotal >= FREE_SHIPPING_THRESHOLD) {
    return {
      fee: 0,
      isFree: true,
      note: `Free shipping for orders over ₱${FREE_SHIPPING_THRESHOLD.toLocaleString()}`
    }
  }

  return {
    fee: FALLBACK_SHIPPING_FEE,
    isFree: false,
    note: 'Shipping calculated at checkout'
  }
}

/**
 * Format shipping fee for display
 */
export function formatShippingDisplay(calculation: ShippingCalculation): string {
  if (calculation.isFree) {
    return 'Free'
  }
  
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
  }).format(calculation.fee)
}