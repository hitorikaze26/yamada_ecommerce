// User types
export type UserRole = "buyer" | "seller" | "rider" | "admin"

export interface User {
  id: string
  email: string
  givenName: string
  surname: string
  role: UserRole
  contactNumber: string
  avatar?: string
  isVerified?: boolean
  /** Seller store id when approved / provisioned */
  storeId?: number | null
  storeStatus?: string | null
  shopName?: string
  createdAt: string
  updatedAt: string
}

export interface BuyerProfile extends User {
  role: "buyer"
  addresses: Address[]
  documents: {
    validId?: string
  }
}

export interface SellerProfile extends User {
  role: "seller"
  shopName: string
  shopLogo?: string
  tagline?: string
  description?: string
  categories: string[]
  rating: number
  totalSales: number
  verified: boolean
  address: Address
  documents: {
    dti?: string
    birTin?: string
    businessPermit?: string
    validId?: string
  }
}

export interface RiderProfile extends User {
  role: "rider"
  vehicleType: string
  licenseNumber: string
  rating: number
  totalDeliveries: number
  verified: boolean
  address: Address
  documents: {
    license?: string
    orCr?: string
  }
}

export interface Address {
  id: string
  label?: string
  regionCode: string
  regionName: string
  provinceCode: string
  provinceName: string
  municipalityCode: string
  municipalityName: string
  barangayCode: string
  barangayName: string
  streetAddress?: string
  postalCode?: string
  isDefault?: boolean
}

// Product types

export type SizeChartCategoryKey =
  | "tops"
  | "dresses_and_skirts"
  | "bottoms"
  | "activewear_and_yoga_pants"
  | "lingerie_and_sleepwear"
  | "jackets"
  | "shoes"

export type SizeChartMeasurementId =
  | "bust"
  | "waist"
  | "length"
  | "shoulder"
  | "sleeve_length"
  | "hips"
  | "inseam"
  | "thigh"
  | "stretch_fit_range"
  | "underbust"
  | "foot_length"

export interface ClothingSizeRow {
  label: string
  international: string
  numeric: string
  cm: Record<SizeChartMeasurementId, string | null>
  inch: Record<SizeChartMeasurementId, string | null>
}

export interface ClothingSizeChartMatrix {
  categoryKey: Exclude<SizeChartCategoryKey, "shoes">
  measurements: SizeChartMeasurementId[]
  sizes: ClothingSizeRow[]
}

export interface ShoeSizeRow {
  us: number
  eu: number
  cm: { foot_length: string | null }
  inch: { foot_length: string | null }
}

export interface ShoeSizeChartMatrix {
  categoryKey: "shoes"
  measurements: ["foot_length"]
  sizes: ShoeSizeRow[]
}

export type SizeChartMatrix = ClothingSizeChartMatrix | ShoeSizeChartMatrix

export interface LegacySizeChart {
  bust?: string
  waist?: string
  hips?: string
  length?: string
  otherNotes?: string
}

export interface Product {
  id: string
  slug: string
  name: string
  category: string
  subcategory?: string
  categories?: string[]
  description: string
  images: string[]
  image_url?: string
  imageUrl?: string
  variations: ProductVariation[]
  price: number
  salePrice?: number
  // Extended product fields
  brand?: string
  productCondition?: string
  weightKg?: number
  material?: string
  careInstructions?: string
  tags?: string[]
  sizeChart?: LegacySizeChart | SizeChartMatrix
  rating: number
  reviewCount: number
  sellerId: string
  sellerName: string
  sellerLogo?: string
  visibility: boolean
  createdAt: string
  updatedAt: string
}

export interface ProductVariation {
  id: string
  size: string
  color: string
  colorHex?: string
  sku: string
  inventory: number
  price?: number
}

// Cart types
export interface CartItem {
  id: string
  product: Product
  quantity: number
  selectedVariation: ProductVariation
}

export interface Cart {
  items: CartItem[]
  subtotal: number
  shipping: number
  total: number
}

// Order types
export type OrderStatus =
  | "pending"
  | "confirmed"
  | "processing"
  | "shipped"
  | "out_for_delivery"
  | "delivered"
  | "cancelled"
  | "returned"

export interface Order {
  id: string
  orderNumber: string
  buyer: {
    id: string
    name: string
    email: string
  }
  seller: {
    id: string
    shopName: string
  }
  rider?: {
    id: string
    name: string
    contactNumber: string
  }
  items: OrderItem[]
  shippingAddress: Address
  paymentMethod: string
  paymentStatus: "pending" | "paid" | "failed" | "refunded"
  status: OrderStatus
  subtotal: number
  shipping: number
  total: number
  createdAt: string
  updatedAt: string
}

export interface OrderItem {
  id?: string
  product: Product
  quantity: number
  variation: ProductVariation
  price: number
  sellerId?: string
  sellerName?: string
}

// Category types
export const CATEGORIES = [
  { id: "dress-skirts", name: "Dress & Skirts", icon: "dress" },
  { id: "lingerie-sleepwear", name: "Lingerie & Sleepwear", icon: "sleeping-bag" },
  { id: "activewear", name: "Activewear & Yoga Pants", icon: "gym" },
  { id: "jackets-coats", name: "Jackets & Coats", icon: "lab-coat" },
  { id: "tops-blouses", name: "Tops & Blouses", icon: "shirt-long-sleeve" },
  { id: "accessories-shoes", name: "Accessories & Shoes", icon: "boot-heeled" },
] as const

export type CategoryId = (typeof CATEGORIES)[number]["id"]

// Map database category names -> CategoryId for cross-linking
export const CATEGORY_NAME_TO_ID: Record<string, CategoryId> = {
  "Dresses and Skirts": "dress-skirts",
  "Dressess and Skirts": "dress-skirts",
  "tops and blouses": "tops-blouses",
  "activewear and yoga pants": "activewear",
  "lingerie and sleepwear": "lingerie-sleepwear",
  "jackets and coats": "jackets-coats",
  "shoes and accessories": "accessories-shoes",
}

// Subcategories per main category, used in seller product creation UI
export const SUBCATEGORIES: Record<CategoryId, string[]> = {
  "dress-skirts": [
    "Maxi dresses",
    "Midi dresses",
    "Mini dresses",
    "Bodycon dresses",
    "A-line dresses",
    "Fit & flare dresses",
    "Wrap dresses",
    "Shift dresses",
    "Shirt dresses",
    "Slip dresses",
    "Halter dresses",
    "Off-shoulder dresses",
    "One-shoulder dresses",
    "Cocktail dresses",
    "Evening gowns",
    "Knit dresses",
    "Sweater dresses",
    "Denim dresses",
    "Floral dresses",
    "Boho dresses",
    "Sundresses",
    "Skater dresses",
    "Ruffle dresses",
    "Tiered dresses",
    "Pleated dresses",
    "Sequin dresses",
    "Lace dresses",
    "Satin/silk dresses",
    "Formal event dresses",
    "Work/office dresses",
    "Maternity dresses",
    "Maxi skirts",
    "Midi skirts",
    "Mini skirts",
    "A-line skirts",
    "Pencil skirts",
    "Pleated skirts",
    "Skater skirts",
    "Wrap skirts",
    "Asymmetrical skirts",
    "Cargo skirts",
    "Denim skirts",
    "Satin skirts",
    "Tulle skirts",
    "Leather skirts",
  ],
  "tops-blouses": [
    "Crop tops",
    "Tank tops / sleeveless tops",
    "Tube tops",
    "Camisoles",
    "Basic tees",
    "Fitted tees",
    "Oversized tees",
    "Blouses (general)",
    "Button-down blouses",
    "Ruffle blouses",
    "Peplum tops",
    "Off-shoulder tops",
    "One-shoulder tops",
    "Halter tops",
    "Square-neck tops",
    "V-neck tops",
    "Collared tops",
    "Graphic tees",
    "Knit tops",
    "Sweaters",
    "Cardigans (thin/lightweight)",
    "Wrap tops",
    "Satin/silk tops",
    "Lace tops",
    "Mesh tops",
    "Sheer tops",
    "Bodysuits",
    "Corset tops",
    "Tube corsets",
    "Tunics",
    "Long-sleeve tops",
    "Puff-sleeve tops",
    "Balloon-sleeve tops",
  ],
  "activewear": [
    "Sports bras",
    "High-impact sports bras",
    "Medium-impact sports bras",
    "Low-impact sports bras",
    "Compression tops",
    "Dry-fit tops",
    "Workout tank tops",
    "Long-sleeve active tops",
    "Yoga tees",
    "Lightweight hoodies",
    "Zip-up active jackets",
    "Yoga pants (general)",
    "High-waisted yoga pants",
    "Flare yoga pants",
    "Compression leggings",
    "Seamless leggings",
    "Printed leggings",
    "Running leggings",
    "Biker shorts",
    "Running shorts",
    "Skort activewear",
    "Joggers",
    "Sweatpants",
    "Gym sets / co-ords",
    "Yoga & Athleisure Sets",
  ],
  "lingerie-sleepwear": [
    "Bras",
    "Everyday bras",
    "Push-up bras",
    "T-shirt bras",
    "Bandeau bras",
    "Strapless bras",
    "Bralettes",
    "Lace bras",
    "Sports bras (lingerie)",
    "Wire-free bras",
    "Underwire bras",
    "Panties",
    "Bikini panties",
    "Hipster panties",
    "High-waisted panties",
    "Thongs",
    "Seamless panties",
    "Lace panties",
    "Cotton basic panties",
    "Shapewear bodysuits",
    "Shapewear shorts",
    "Waist cinchers",
    "Camisole lingerie",
    "Babydolls",
    "Chemise",
    "Corset lingerie",
    "Robes",
    "Satin robes",
    "Silk robes",
    "Pajama sets (shorts)",
    "Pajama sets (pants)",
    "Nightgowns",
    "Sleep shirts",
    "Satin sleepwear",
    "Fluffy sleepwear",
    "Thermal sleepwear",
  ],
  "jackets-coats": [
    "Denim jackets",
    "Cropped denim jackets",
    "Oversized denim jackets",
    "Leather jackets",
    "Faux-leather jackets",
    "Bomber jackets",
    "Windbreakers",
    "Hooded jackets",
    "Zip-up hoodies",
    "Pullover hoodies",
    "Knit cardigans",
    "Long cardigans",
    "Blazers",
    "Oversized blazers",
    "Fitted blazers",
    "Trench coats",
    "Wool coats",
    "Puffer jackets",
    "Light puffer coats",
    "Parkas",
    "Raincoats",
    "Varsity jackets",
    "Quilted jackets",
    "Sherpa jackets",
    "Faux fur coats",
  ],
  "accessories-shoes": [
    "Sneakers",
    "Running shoes",
    "Slip-on sneakers",
    "Sandals",
    "Flat sandals",
    "Strappy sandals",
    "Slides",
    "Wedge sandals",
    "Heels",
    "Stilettos",
    "Block heels",
    "Wedge heels",
    "Kitten heels",
    "Platform heels",
    "Boots",
    "Ankle boots",
    "Knee-high boots",
    "Chelsea boots",
    "Combat boots",
    "Loafers",
    "Ballet flats",
    "Mules",
    "Accessories",
    "Handbags",
    "Shoulder bags",
    "Tote bags",
    "Crossbody bags",
    "Mini bags",
    "Wallets",
    "Belts",
    "Sunglasses",
    "Scarves",
    "Hair accessories (clips, scrunchies)",
    "Hats (bucket, baseball cap, sun hat)",
    "Jewelry",
    "Earrings",
    "Necklaces",
    "Bracelets",
    "Rings",
  ],
}

// Split accessories vs shoes within the "accessories-shoes" category
export const SHOES_SUBCATEGORIES: string[] = [
  "Sneakers",
  "Running shoes",
  "Slip-on sneakers",
  "Sandals",
  "Flat sandals",
  "Strappy sandals",
  "Slides",
  "Wedge sandals",
  "Heels",
  "Stilettos",
  "Block heels",
  "Wedge heels",
  "Kitten heels",
  "Platform heels",
  "Boots",
  "Ankle boots",
  "Knee-high boots",
  "Chelsea boots",
  "Combat boots",
  "Loafers",
  "Ballet flats",
  "Mules",
]

export const ACCESSORY_SUBCATEGORIES: string[] = [
  "Accessories",
  "Handbags",
  "Shoulder bags",
  "Tote bags",
  "Crossbody bags",
  "Mini bags",
  "Wallets",
  "Belts",
  "Sunglasses",
  "Scarves",
  "Hair accessories (clips, scrunchies)",
  "Hats (bucket, baseball cap, sun hat)",
  "Jewelry",
  "Earrings",
  "Necklaces",
  "Bracelets",
  "Rings",
]

export const SHOE_SIZES: Record<"US" | "EU" | "UK", string[]> = {
  US: [
    "4",
    "4.5",
    "5",
    "5.5",
    "6",
    "6.5",
    "7",
    "7.5",
    "8",
    "8.5",
    "9",
    "9.5",
    "10",
    "10.5",
    "11",
    "11.5",
    "12",
  ],
  EU: [
    "34",
    "34.5",
    "35",
    "35.5",
    "36",
    "36.5",
    "37",
    "37.5",
    "38",
    "38.5",
    "39",
    "39.5",
    "40",
    "40.5",
    "41",
    "41.5",
    "42",
  ],
  UK: [
    "2",
    "2.5",
    "3",
    "3.5",
    "4",
    "4.5",
    "5",
    "5.5",
    "6",
    "6.5",
    "7",
    "7.5",
    "8",
    "8.5",
    "9",
  ],
}

// Dashboard analytics types
export interface DashboardOverview {
  totalSales: number
  totalOrders: number
  totalProducts: number
  netSales: number
  salesTrend: number
  ordersTrend: number
  recentTransactions: Transaction[]
  visitors: number
  searchCount: number
}

export interface Transaction {
  id: string
  type: "sale" | "refund"
  amount: number
  buyerName: string
  riderName?: string
  status: string
  createdAt: string
}

export interface SalesData {
  date: string
  sales: number
  orders: number
}

export interface CategoryPerformance {
  category: string
  sales: number
  orders: number
}

// --- Report types ---

export type ReportStatusType = "pending" | "under_review" | "investigating" | "resolved" | "dismissed"

export type PunishmentSeverityType = "warning" | "restriction" | "ban"

export interface ReportTypeDto {
  id: number
  reporterRole: "buyer" | "seller" | "rider"
  typeKey: string
  displayName: string
  description: string | null
}

export interface ReportEvidenceDto {
  id: number
  filePath: string
  fileUrl?: string | null
  fileType: string
  originalFilename: string | null
  uploadedAt: string | null
}

export interface PunishmentDto {
  id: number
  reportId: number | null
  userId: number
  severity: PunishmentSeverityType
  restrictionType: string | null
  reason: string
  issuedBy: number | null
  startDate: string | null
  endDate: string | null
  isActive: boolean
  createdAt: string | null
}

export interface ViolationDto {
  id: number
  userId: number
  reportId: number | null
  punishmentId: number | null
  violationType: string
  description: string | null
  issuedBy: number | null
  createdAt: string | null
}

export interface ProblemReportDto {
  id: number
  reporterUserId: number
  reporterRole: "buyer" | "seller" | "rider"
  reportTypeId: number | null
  reportType: string | null
  reportTypeCategory?: string | null
  description: string
  status: ReportStatusType
  priority: string
  targetUserId: number | null
  targetRole: string | null
  targetLabel?: string | null
  storeId: number | null
  orderId: number | null
  store?: { id: number; name: string | null } | null
  order?: {
    id: number
    displayId: string
    status: string
    totalAmount: number
    grandTotal: number
    createdAt: string | null
  } | null
  adminNotes: string | null
  resolvedBy: number | null
  evidence: ReportEvidenceDto[]
  evidenceCount?: number
  punishments: PunishmentDto[]
  createdAt: string | null
  updatedAt: string | null
  resolvedAt: string | null
}
