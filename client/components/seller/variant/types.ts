import type { ColorOption } from "@/data/colors"

export interface VariantEntry {
  id: string
  color: ColorOption
  size: string
  stock: number
  sku: string
  price: number | null
}

export interface VariantFormState {
  selectedColors: ColorOption[]
  selectedSizes: string[]
  variants: VariantEntry[]
}

export const SIZE_OPTIONS = ["XS", "S", "M", "L", "XL", "XXL"]

export const SHOE_SIZE_OPTIONS = [
  "US 4", "US 4.5", "US 5", "US 5.5", "US 6", "US 6.5", "US 7",
  "US 7.5", "US 8", "US 8.5", "US 9", "US 9.5", "US 10",
  "US 10.5", "US 11", "US 11.5", "US 12",
]

export type VariantAction =
  | { type: "SET_COLORS"; colors: ColorOption[] }
  | { type: "SET_SIZES"; sizes: string[] }
  | { type: "GENERATE_VARIANTS" }
  | { type: "UPDATE_VARIANT"; id: string; field: keyof VariantEntry; value: unknown }
  | { type: "REMOVE_VARIANT"; id: string }
  | { type: "ADD_CUSTOM_VARIANT"; variant: VariantEntry }
  | { type: "RESET" }

let _nextId = 1
export function generateVariantId(): string {
  return `v_${Date.now()}_${_nextId++}`
}

export function cartesianProduct(
  colors: ColorOption[],
  sizes: string[],
): VariantEntry[] {
  const result: VariantEntry[] = []
  for (const color of colors) {
    for (const size of sizes) {
      result.push({
        id: generateVariantId(),
        color,
        size,
        stock: 0,
        sku: "",
        price: null,
      })
    }
  }
  return result
}

export function variantReducer(
  state: VariantFormState,
  action: VariantAction,
): VariantFormState {
  switch (action.type) {
    case "SET_COLORS":
      return { ...state, selectedColors: action.colors }
    case "SET_SIZES":
      return { ...state, selectedSizes: action.sizes }
    case "GENERATE_VARIANTS": {
      if (state.selectedColors.length === 0 || state.selectedSizes.length === 0) {
        return state
      }
      return {
        ...state,
        variants: cartesianProduct(state.selectedColors, state.selectedSizes),
      }
    }
    case "UPDATE_VARIANT":
      return {
        ...state,
        variants: state.variants.map((v) =>
          v.id === action.id ? { ...v, [action.field]: action.value } : v,
        ),
      }
    case "REMOVE_VARIANT":
      return {
        ...state,
        variants: state.variants.filter((v) => v.id !== action.id),
      }
    case "ADD_CUSTOM_VARIANT":
      return {
        ...state,
        variants: [...state.variants, action.variant],
      }
    case "RESET":
      return { selectedColors: [], selectedSizes: [], variants: [] }
    default:
      return state
  }
}
