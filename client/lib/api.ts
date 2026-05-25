import axios, { type AxiosInstance, type AxiosError, type CancelTokenSource } from "axios"

const DEFAULT_DEV_API = "http://127.0.0.1:5000/api"

function resolveApiBaseUrl(): string {
  const configured = process.env.NEXT_PUBLIC_API_BASE_URL?.trim()
  if (configured) {
    return configured.endsWith("/api")
      ? configured.replace(/\/$/, "")
      : `${configured.replace(/\/$/, "")}/api`
  }
  if (process.env.NODE_ENV === "production") {
    throw new Error(
      "[Yamada] NEXT_PUBLIC_API_BASE_URL is required in production. " +
        "Set it in Vercel to your Railway URL ending in /api.",
    )
  }
  return DEFAULT_DEV_API
}

export const API_BASE_URL = resolveApiBaseUrl()
export const API_BASE_ORIGIN = API_BASE_URL.replace(/\/api(?:\/)?$/, "")

export const isApiConfiguredForProduction =
  Boolean(process.env.NEXT_PUBLIC_API_BASE_URL?.trim()) ||
  process.env.NODE_ENV !== "production"

// Create axios instance with default config
export const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  withCredentials: true,
  headers: {
    "Content-Type": "application/json",
  },
})

// Resolve image URLs that may come from the backend as "/static/..." paths
// so that Next.js requests them from the Flask origin instead of the Next host.
const STATIC_UPLOAD_PREFIXES = [
  "product_images/",
  "rider_docs/",
  "report_evidence/",
  "avatars/",
  "seller_avatars/",
  "seller_banners/",
  "rider_avatars/",
  "buyer_ids/",
  "seller_ids/",
  "seller_dti/",
  "seller_bir/",
  "seller_permits/",
  "chat_uploads/",
  "orders/product_images/",
]

const isStaticUploadPath = (path: string): boolean =>
  STATIC_UPLOAD_PREFIXES.some((prefix) => path.startsWith(prefix) || path.includes(`/${prefix}`))

export const resolveImageUrl = (url?: string | null): string | null => {
  if (!url) return null
  // Windows DB paths may use backslashes — URLs must use forward slashes
  const value = String(url).replace(/\\/g, "/")

  const origin = API_BASE_ORIGIN.replace(/\/static$/, "")

  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value
  }

  if (value.startsWith("/static/")) {
    return `${origin}${value}`
  }

  const trimmed = value.replace(/^\/+/, "")
  if (trimmed.startsWith("static/")) {
    return `${origin}/${trimmed}`
  }
  if (isStaticUploadPath(trimmed)) {
    return `${origin}/static/${trimmed}`
  }

  return value
}

/** Resolve private doc paths via admin signed-url API (admin UI only). */
export async function resolvePrivateDocUrl(
  path?: string | null,
  bucket = "docs",
): Promise<string | null> {
  if (!path) return null
  const value = String(path).replace(/\\/g, "/")
  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value
  }

  let storageBucket = bucket
  let storagePath = value.replace(/^\/+/, "")
  const knownBuckets = ["docs", "product-images", "avatars", "chat", "misc"]
  const first = storagePath.split("/")[0]
  if (knownBuckets.includes(first)) {
    storageBucket = first
    storagePath = storagePath.slice(first.length + 1)
  }

  try {
    const res = await apiClient.get("/admin/files/signed-url", {
      params: { bucket: storageBucket, path: storagePath },
    })
    const url = (res.data as { url?: string })?.url
    return url ?? null
  } catch {
    return resolveImageUrl(path)
  }
}

// Helper to read a cookie by name (used for CSRF token with JWT-in-cookies setup)
const getCookie = (name: string): string | null => {
  if (typeof document === "undefined") return null
  const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`))
  return match ? decodeURIComponent(match[1]) : null
}

// Helper to get stored access token
const getStoredToken = (): string | null => {
  if (typeof window === "undefined") return null
  return localStorage.getItem("yamada-access-token")
}

// Request interceptor to add CSRF token for state-changing requests
apiClient.interceptors.request.use(
  (config) => {
    // Add Authorization header as fallback when cookies don't work
    const token = getStoredToken()
    if (token) {
      config.headers = config.headers ?? {}
      ;(config.headers as any)["Authorization"] = `Bearer ${token}`
    }

    // For POST/PUT/PATCH/DELETE we also need to send the CSRF token header.
    const method = (config.method || "get").toLowerCase()
    if (["post", "put", "patch", "delete"].includes(method)) {
      // Default Flask-JWT-Extended cookie name for access CSRF token
      const csrfToken = getCookie("csrf_access_token") || getCookie("access_csrf")
      if (csrfToken) {
        config.headers = config.headers ?? {}
        ;(config.headers as any)["X-CSRF-TOKEN"] = csrfToken
      }
    }

    // Let the browser set multipart boundary — manual Content-Type breaks file uploads.
    if (typeof FormData !== "undefined" && config.data instanceof FormData) {
      config.headers = config.headers ?? {}
      const headers = config.headers as Record<string, unknown>
      delete headers["Content-Type"]
      delete headers["content-type"]
    }

    return config
  },
  (error) => Promise.reject(error),
)

// Response interceptor for error handling
apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      const requestUrl = error.config?.url || ""

      // Let AuthProvider handle 401s from /accounts/protected (session check)
      // and let the login page handle 401s from /accounts/login (wrong credentials)
      if (
        requestUrl.includes("/accounts/protected") ||
        requestUrl.includes("/accounts/login") ||
        requestUrl.includes("/accounts/refresh") ||
        requestUrl.includes("/accounts/seller/profile") ||
        requestUrl.includes("/accounts/buyer/profile") ||
        requestUrl.includes("/accounts/rider/profile")
      ) {
        return Promise.reject(error)
      }

      // For admin endpoints, let the admin pages handle 401 explicitly
      if (requestUrl.startsWith("/admin/") || requestUrl.includes("/admin/")) {
        return Promise.reject(error)
      }

      // For other 401s, clear client snapshot and go to landing
      if (typeof window !== "undefined") {
        localStorage.removeItem("yamada-user")
        localStorage.removeItem("yamada-access-token")
        localStorage.removeItem("yamada-role")
        window.location.href = "/landing"
      }
    }
    return Promise.reject(error)
  },
)

// Create cancel token for request cancellation
export const createCancelToken = (): CancelTokenSource => axios.CancelToken.source()

// Auth API
export const authApi = {
  // Maps to Flask route: POST /api/accounts/login
  // Backend expects username and password; we use email as username for now
  // NOTE: Role is passed for potential server-side validation but not required
  login: (email: string, password: string, role?: string) =>
    apiClient.post("/accounts/login", { username: email, password, role }),

  logout: () => apiClient.post("/accounts/logout"),

  refresh: () => apiClient.post("/accounts/refresh"),

  checkSession: () => apiClient.get("/accounts/protected"),

  // Maps buyer registration to generic Flask registration: POST /api/accounts/register
  // New dedicated buyer registration endpoint: POST /api/accounts/register-buyer
  // Sends full buyer profile + address; backend keeps email_verified=False until admin approval
  registerBuyer: (data: BuyerRegistrationData) => {
    const formData = new FormData()
    formData.append("givenName", data.givenName)
    formData.append("surname", data.surname)
    formData.append("email", data.email)
    formData.append("password", data.password)
    formData.append("contactNumber", data.contactNumber)
    formData.append("address", JSON.stringify(data.address))

    if (data.validId instanceof File) {
      formData.append("validId", data.validId)
    }

    return apiClient.post("/accounts/register-buyer", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },

  registerSeller: (data: SellerRegistrationData) => {
    const formData = new FormData()
    formData.append("givenName", data.givenName)
    formData.append("surname", data.surname)
    formData.append("email", data.email)
    formData.append("password", data.password)
    formData.append("contactNumber", data.contactNumber)
    formData.append("shopName", data.shopName)
    formData.append("tagline", data.tagline)
    formData.append("description", data.description)

    formData.append("address", JSON.stringify(data.address))
    formData.append("categories", JSON.stringify(data.categories || []))

    if (data.logo instanceof File) {
      formData.append("logo", data.logo)
    }

    if (data.documents.dti instanceof File) {
      formData.append("dti", data.documents.dti)
    }
    if (data.documents.birTin instanceof File) {
      formData.append("birTin", data.documents.birTin)
    }
    if (data.documents.businessPermit instanceof File) {
      formData.append("businessPermit", data.documents.businessPermit)
    }
    if (data.documents.validId instanceof File) {
      formData.append("validId", data.documents.validId)
    }

    return apiClient.post("/accounts/register-seller", formData)
  },

  registerRider: (data: RiderRegistrationData) => {
    const formData = new FormData()
    formData.append("givenName", data.givenName)
    formData.append("surname", data.surname)
    formData.append("email", data.email)
    formData.append("password", data.password)
    formData.append("contactNumber", data.contactNumber)
    formData.append("vehicleType", data.vehicleType)
    formData.append("licenseNumber", data.licenseNumber)
    formData.append("address", JSON.stringify(data.address))

    if (data.license instanceof File) {
      formData.append("license", data.license)
    }

    if (data.orCr instanceof File) {
      formData.append("orCr", data.orCr)
    }

    return apiClient.post("/accounts/register-rider", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },

  lookupContactForReset: (email: string) =>
    apiClient.post<{ contactNumber: string | null }>(
      "/accounts/forgot-password/contact-lookup",
      { email },
    ),

  forgotPassword: (payload: {
    email?: string
    contactNumber?: string
    channel: "email" | "sms"
  }) => apiClient.post<{ msg: string; email?: string }>("/accounts/forgot-password", payload),

  verifyPin: (email: string, pin: string) =>
    apiClient.post("/accounts/verify-pin", { email, pin }),

  resetPassword: (email: string, pin: string, newPassword: string) =>
    apiClient.post("/accounts/reset-password", { email, pin, newPassword }),

  changePassword: (data: { currentPassword: string; newPassword: string }) =>
    apiClient.put("/accounts/change-password", data),

  changeEmail: (data: { newEmail: string; password: string }) =>
    apiClient.put("/accounts/change-email", data),

  deleteAccount: (password: string) =>
    apiClient.delete("/accounts/delete-account", { data: { password } }),
}

// Products API
export const productsApi = {
  // NOTE: Backend currently exposes more granular product endpoints; generic list endpoint is not implemented
  getAll: (params?: ProductQueryParams) => apiClient.get("/products", { params }),

  // Maps to Flask route: GET /api/products/product/<int:product_id>
  getById: (id: string) => apiClient.get(`/products/product/${id}`),

  // Maps to Flask route: GET /api/products/product/<string:product_name>
  // Backend expects the product name as part of the path
  search: (query: string, params?: ProductQueryParams) =>
    apiClient.get(`/products/product/${encodeURIComponent(query)}`, { params }),
  getReviews: (productId: string) => apiClient.get(`/products/${productId}/reviews`),
}

// Cart API
export const cartApi = {
  // Maps to Flask routes under /api/cart
  get: () => apiClient.get("/cart/get-cart"),
  add: (productId: number, variationId: number, quantity: number) =>
    apiClient.post("/cart/add-to-cart", { productId, variationId, quantity }),
  updateItem: (itemId: number, quantity: number) => 
    apiClient.put(`/cart/update-cart-item/${itemId}`, { quantity }),
  removeItem: (itemId: number) => 
    apiClient.delete(`/cart/remove-from-cart/${itemId}`),
  clear: () => apiClient.delete("/cart/clear-cart"),
}

// Orders API
export const ordersApi = {
  create: (data: CheckoutData) => apiClient.post("/orders/checkout", data),
  getById: (id: string) => apiClient.get(`/orders/${id}`),
  getAll: (params?: OrderQueryParams) => apiClient.get("/orders", { params }),
  cancel: (id: string) => apiClient.put(`/orders/${id}/cancel`),
  confirmReceived: (id: string) => apiClient.post(`/orders/${id}/confirm-received`),
  requestRefund: (id: string, reason: string) =>
    apiClient.post(`/orders/${id}/refund-request`, { reason }),
  getRefundRequests: () => apiClient.get("/buyer/refund-requests"),
  disputeRefund: (refundId: number, data?: { note?: string; evidencePaths?: string[] }) =>
    apiClient.post(`/buyer/refund-requests/${refundId}/dispute`, data ?? {}),
  getRefunds: () => apiClient.get("/orders/refunds"),
  addReview: (
    orderId: number,
    payload: {
      orderItemId: number
      reviewFormat: string
      overallRating?: number
      ratings: Record<string, number>
      customerReview?: string
      deliverySatisfaction: number
      deliveryPills: string[]
    },
  ) => apiClient.post(`/orders/${orderId}/reviews`, payload),
  getOrderReviews: (orderId: number) => apiClient.get(`/orders/${orderId}/reviews`),
}

// Shipping API
export const shippingApi = {
  calculateFee: (data: {
    shop_id: number
    order_total: number
    buyer_region_code?: string
    buyer_province_code?: string
    buyer_municipality_code?: string
  }) => apiClient.post("/shipping/calculate", data)
}

// Rider API
export const riderApi = {
  getDashboard: () => apiClient.get("/rider/dashboard"),
  getDeliveries: () => apiClient.get("/rider/deliveries"),
  updateDeliveryStatus: (deliveryId: number, status: string) =>
    apiClient.put(`/rider/deliveries/${deliveryId}/status`, { status }),
  acceptDelivery: (orderId: number) => apiClient.post(`/rider/orders/${orderId}/accept`),
  uploadDeliveryProof: (deliveryId: number, data: { note?: string; photo?: File | null }) => {
    const formData = new FormData()
    if (data.note && data.note.trim()) {
      formData.append("note", data.note.trim())
    }
    if (data.photo instanceof File) {
      formData.append("photo", data.photo)
    }

    return apiClient.post(`/rider/deliveries/${deliveryId}/proof`, formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },
}

// Rider account/profile API
export const riderAccountApi = {
  getProfile: () => apiClient.get("/accounts/rider/profile"),
  updateProfile: (data: {
    givenName?: string
    surname?: string
    email?: string
    contactNumber?: string
    vehicleType?: string
    licenseNumber?: string
  }) => apiClient.put("/accounts/rider/profile", data),
  uploadAvatar: (file: File) => {
    const formData = new FormData()
    formData.append("avatar", file)
    return apiClient.post("/accounts/rider/avatar", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },
  uploadRiderDocuments: (data: { license?: File | null; orCr?: File | null }) => {
    const formData = new FormData()
    if (data.license instanceof File) formData.append("license", data.license)
    if (data.orCr instanceof File) formData.append("orCr", data.orCr)
    return apiClient.post("/accounts/rider/documents", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },
}

// Seller API
export const sellerApi = {
  getProducts: (sellerId: string, params?: ProductQueryParams) =>
    apiClient.get(`/seller/${sellerId}/products`, { params }),
  getMyProducts: (params?: ProductQueryParams) =>
    apiClient.get("/seller/products", { params }),
  // For creation & updates, use the existing products endpoints that infer
  // the store from the authenticated seller (Option 1)
  addProduct: (data: ProductFormData | FormData) => {
    if (typeof FormData !== "undefined" && data instanceof FormData) {
      return apiClient.post("/products/create", data, {
        headers: { "Content-Type": "multipart/form-data" },
      })
    }

    return apiClient.post("/products/create", data)
  },
  updateProduct: (productId: string, data: any) =>
    apiClient.put(`/products/edit/${productId}`, data),
  deleteProduct: (productId: string) => apiClient.delete(`/products/delete/${productId}`),
  deactivateProduct: (productId: string) => apiClient.post(`/products/deactivate/${productId}`),
  getProfile: () => apiClient.get("/seller/profile"),
  getProfileById: (sellerId: string) => apiClient.get(`/seller/${sellerId}/profile`),
  getOrders: () => apiClient.get("/seller/orders"),
  updateOrderStatus: (orderId: number, status: string) =>
    apiClient.put(`/orders/${orderId}/status`, { status }),
  getDashboard: (sellerId: string) => apiClient.get(`/dashboard/seller/overview`),
  getWallet: () => apiClient.get("/seller/wallet"),
  getWalletTransactions: () => apiClient.get("/seller/wallet/transactions"),
  getRefundRequests: () => apiClient.get("/seller/refund-requests"),
  approveRefund: (refundId: number) =>
    apiClient.post(`/seller/refund-requests/${refundId}/approve`),
  rejectRefund: (refundId: number) =>
    apiClient.post(`/seller/refund-requests/${refundId}/reject`),
  getAnalytics: (days: number = 30) =>
    apiClient.get(`/seller/analytics?days=${days}`),
  downloadReport: (days: number = 30, format: string = "pdf") =>
    apiClient.get(`/seller/analytics/download?days=${days}&format=${format}`, {
      responseType: "blob",
    }),
}

// Seller shop settings API (reuses accounts /seller/profile routes)
export const sellerShopApi = {
  getProfile: () => apiClient.get("/accounts/seller/profile"),
  updateProfile: (data: {
    givenName?: string
    surname?: string
    shopName?: string
    tagline?: string
    description?: string
    categories?: string[]
    email?: string
    contactNumber?: string
  }) => apiClient.put("/accounts/seller/profile", data),
  uploadAvatar: (file: File) => {
    const formData = new FormData()
    formData.append("avatar", file)
    return apiClient.post("/accounts/seller/avatar", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },
  uploadBanner: (file: File) => {
    const formData = new FormData()
    formData.append("banner", file)
    return apiClient.post("/accounts/seller/banner", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },

  // Shop Settings APIs
  getAllSettings: () => apiClient.get("/seller/settings/all"),

  // Shipping Settings
  getShippingSettings: () => apiClient.get("/seller/settings/shipping"),
  createShippingSetting: (data: {
    regionCode?: string
    regionName: string
    provinceCode?: string
    provinceName: string
    cityCode?: string
    cityName: string
    shippingFee: number
    isActive?: boolean
  }) => apiClient.post("/seller/settings/shipping", data),
  updateShippingSetting: (settingId: number, data: {
    regionName?: string
    provinceName?: string
    cityName?: string
    shippingFee?: number
    isActive?: boolean
  }) => apiClient.put(`/seller/settings/shipping/${settingId}`, data),
  deleteShippingSetting: (settingId: number) =>
    apiClient.delete(`/seller/settings/shipping/${settingId}`),

  // Payment Settings
  getPaymentSettings: () => apiClient.get("/seller/settings/payment"),
  updatePaymentSettings: (data: { codEnabled: boolean }) =>
    apiClient.put("/seller/settings/payment", data),

  // Order Settings
  getOrderSettings: () => apiClient.get("/seller/settings/order"),
  updateOrderSettings: (data: {
    allowCancellation?: boolean
    maxCancellationHours?: number
    allowReturns?: boolean
    returnPeriodDays?: number
  }) => apiClient.put("/seller/settings/order", data),

  // Shop Customization
  getShopCustomization: () => apiClient.get("/seller/settings/customization"),
  updateShopCustomization: (data: {
    announcement?: string
    primaryColor?: string
    themeMode?: string
  }) => apiClient.put("/seller/settings/customization", data),

  // Chat Settings
  getChatSettings: () => apiClient.get("/seller/settings/chat"),
  updateChatSettings: (data: {
    autoReplyEnabled?: boolean
    autoReplyMessage?: string
  }) => apiClient.put("/seller/settings/chat", data),
}

// Seller account API
export const sellerInsightsApi = {
  getInsights: () => apiClient.get("/seller/insights"),
  getFollowers: (page = 1) =>
    apiClient.get("/seller/followers", { params: { page } }),
  getWishlistInsights: () => apiClient.get("/seller/wishlist-insights"),
  getReviews: (params?: { sort?: string; status?: string; page?: number }) =>
    apiClient.get("/seller/reviews", { params }),
  replyToReview: (reviewId: number, reply: string) =>
    apiClient.post<{ msg: string; review?: Record<string, unknown>; warning?: string }>(
      `/seller/reviews/${reviewId}/reply`,
      { reply },
    ),
  deleteReviewReply: (reviewId: number) =>
    apiClient.delete<{ msg: string; review?: Record<string, unknown> }>(
      `/seller/reviews/${reviewId}/reply`,
    ),
  moderateReview: (
    reviewId: number,
    data: { visibility?: string; delete?: boolean },
  ) => apiClient.patch(`/seller/reviews/${reviewId}`, data),
}

export interface SellerCouponDto {
  id: number
  code: string
  title: string
  description?: string
  discountType: string
  discountValue: number
  minOrderAmount: number
  maxUses?: number | null
  usedCount: number
  isActive: boolean
  expiresAt?: string | null
  scope?: string
  storeId?: number
}

export const sellerCouponsApi = {
  list: () =>
    apiClient.get<{ coupons: SellerCouponDto[] }>("/seller/coupons"),
  create: (data: {
    code: string
    title: string
    description?: string
    discountType?: string
    discountValue: number
    minOrderAmount?: number
    maxUses?: number | null
    expiresAt?: string | null
    isActive?: boolean
  }) => apiClient.post<{ coupon: SellerCouponDto }>("/seller/coupons", data),
  update: (
    couponId: number,
    data: Partial<{
      code: string
      title: string
      description: string
      discountType: string
      discountValue: number
      minOrderAmount: number
      maxUses: number | null
      expiresAt: string | null
      isActive: boolean
    }>,
  ) =>
    apiClient.put<{ coupon: SellerCouponDto }>(`/seller/coupons/${couponId}`, data),
  delete: (couponId: number) =>
    apiClient.delete(`/seller/coupons/${couponId}`),
}

// Seller account API
export const sellerAccountApi = {
  getProfile: () => apiClient.get("/accounts/seller/profile"),
  updateProfile: (data: { givenName: string; surname: string; email: string; contactNumber: string }) =>
    apiClient.put("/accounts/seller/profile", data),
  changePassword: (data: { currentPassword: string; newPassword: string }) =>
    apiClient.put("/accounts/change-password", data),
  changeEmail: (data: { newEmail: string; password: string }) =>
    apiClient.put("/accounts/change-email", data),
  updateContact: (contactNumber: string) =>
    apiClient.put("/accounts/seller/profile", { contactNumber }),
  deleteAccount: (password: string) =>
    apiClient.delete("/accounts/delete-account", { data: { password } }),
}

// Admin API
export const adminApi = {
  getSignedFileUrl: (bucket: string, path: string) =>
    apiClient.get("/admin/files/signed-url", { params: { bucket, path } }),
  getApprovals: () => apiClient.get("/admin/get-store-registrations"),
  approveUser: (registrationId: string) =>
    apiClient.post(`/admin/accept-store-registration/${registrationId}`),
  rejectUser: (registrationId: string, reason: string) =>
    apiClient.post(`/admin/reject-store-registration/${registrationId}`, { reason }),
  getUsers: (params?: UserQueryParams) => apiClient.get("/admin/get-users", { params }),
  approveBuyer: (userId: number) => apiClient.post(`/admin/buyers/${userId}/approve`),
  rejectBuyer: (userId: number, reason?: string) =>
    apiClient.post(`/admin/buyers/${userId}/reject`, { reason }),
  archiveUser: (userId: number) =>
    apiClient.post(`/admin/users/${userId}/archive`),
  approveRider: (userId: number) => apiClient.post(`/admin/riders/${userId}/approve`),
  rejectRider: (userId: number, reason?: string) =>
    apiClient.post(`/admin/riders/${userId}/reject`, { reason }),
  getUserActivityLogs: (userId: number) =>
    apiClient.get(`/admin/users/${userId}/activity-logs`),
  getBuyerOrders: (userId: number) =>
    apiClient.get(`/admin/users/${userId}/orders`),
  getSellerProducts: (userId: number) =>
    apiClient.get(`/admin/users/${userId}/products`),
  getRiderDetail: (userId: number) =>
    apiClient.get(`/admin/riders/${userId}`),
  getRiderDeliveries: (userId: number) =>
    apiClient.get(`/admin/users/${userId}/deliveries`),
  getStores: () => apiClient.get("/admin/stores"),
  getStoreDetail: (storeId: number) => apiClient.get(`/admin/stores/${storeId}`),
  getCategories: () => apiClient.get("/admin/categories"),
  getProducts: (params?: ProductQueryParams & { status?: string; storeId?: number }) =>
    apiClient.get("/admin/products", { params }),
  getProductModerationQueue: () => apiClient.get("/admin/products/moderation-queue"),
  updateProductModeration: (
    productId: number,
    data: { status: string; reason?: string; editRequestNote?: string },
  ) => apiClient.patch(`/admin/products/${productId}/moderation`, data),
  requestProductEdits: (productId: number, note: string) =>
    apiClient.post(`/admin/products/${productId}/request-edits`, { note }),
  getProductModerationLogs: (productId: number) =>
    apiClient.get(`/admin/products/${productId}/moderation-logs`),
  approveProduct: (productId: number) => apiClient.post(`/admin/products/${productId}/approve`),
  rejectProduct: (productId: number) => apiClient.post(`/admin/products/${productId}/reject`),
  getRefundRequests: (params?: { queue?: string; all?: boolean | string }) =>
    apiClient.get("/admin/refund-requests", { params }),
  approveRefund: (refundId: number) =>
    apiClient.post(`/admin/refund-requests/${refundId}/approve`),
  rejectRefund: (refundId: number, note?: string) =>
    apiClient.post(`/admin/refund-requests/${refundId}/reject`, note ? { note } : {}),
  requestRefundEvidence: (refundId: number, note: string) =>
    apiClient.post(`/admin/refund-requests/${refundId}/request-evidence`, { note }),
  freezeRefund: (refundId: number) =>
    apiClient.post(`/admin/refund-requests/${refundId}/freeze`),
  getOrderRefunds: () => apiClient.get("/admin/orders/refunds"),
  getOrders: (params?: OrderQueryParams) => apiClient.get("/admin/orders", { params }),
  getOrderById: (id: number) => apiClient.get(`/admin/orders/${id}`),
  getAnalytics: (days: number = 30) =>
    apiClient.get(`/admin/analytics?days=${days}`),
  getCommissionAnalytics: () =>
    apiClient.get("/admin/commission/analytics"),
  getCommissionSettings: () => apiClient.get("/admin/commission/settings"),
  updateCommissionSettings: (data: {
    commissionRate: number
    appliesToProductPriceOnly: boolean
  }) => apiClient.post("/admin/commission/settings", data),
  getShippingSettings: () => apiClient.get("/admin/commission/shipping-settings"),
  createShippingSetting: (data: {
    regionName: string
    provinceName?: string
    cityName?: string
    shippingFee: number
    storeId?: number
  }) => apiClient.post("/admin/commission/shipping-settings", data),
  getProblemReports: (params?: { status?: string; reporterRole?: string; targetRole?: string }) =>
    apiClient.get("/admin/problem-reports", { params }),
  updateProblemReport: (reportId: number, data: { status: string }) =>
    apiClient.patch(`/admin/problem-reports/${reportId}`, data),
  getCoupons: (params?: { scope?: string; storeId?: number }) =>
    apiClient.get("/admin/coupons", { params }),
  createCoupon: (data: Record<string, unknown>) =>
    apiClient.post("/admin/coupons", data),
  updateCoupon: (couponId: number, data: Record<string, unknown>) =>
    apiClient.put(`/admin/coupons/${couponId}`, data),
  deleteCoupon: (couponId: number) =>
    apiClient.delete(`/admin/coupons/${couponId}`),
  downloadReport: (days: number = 30, format: string = "pdf") =>
    apiClient.get(`/admin/analytics/download?days=${days}&format=${format}`, {
      responseType: "blob",
    }),
}

// Buyer API
export const buyerApi = {
  getProfile: () => apiClient.get("/accounts/buyer/profile"),
  updateProfile: (data: {
    givenName?: string
    surname?: string
    email?: string
    contactNumber?: string
    address?: AddressData
  }) => apiClient.put("/accounts/buyer/profile", data),
  uploadAvatar: (file: File) => {
    const formData = new FormData()
    formData.append("avatar", file)
    return apiClient.post("/accounts/buyer/avatar", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    })
  },
  getWishlist: () => apiClient.get("/accounts/buyer/wishlist"),
  addToWishlist: (productId: number) =>
    apiClient.post("/accounts/buyer/wishlist", { productId }),
  removeFromWishlist: (productId: number) =>
    apiClient.delete(`/accounts/buyer/wishlist/${productId}`),
  getReviews: (params?: { page?: number; perPage?: number }) =>
    apiClient.get("/accounts/buyer/reviews", {
      params: {
        page: params?.page,
        per_page: params?.perPage,
      },
    }),
  getFollowingStores: () => apiClient.get("/accounts/buyer/following-stores"),
  getFollowingStatus: (storeId: number) =>
    apiClient.get(`/accounts/buyer/following-stores/${storeId}`),
  followStore: (storeId: number) =>
    apiClient.post("/accounts/buyer/following-stores", { storeId }),
  unfollowStore: (storeId: number) =>
    apiClient.delete(`/accounts/buyer/following-stores/${storeId}`),
  getRecentlyViewed: () => apiClient.get("/accounts/buyer/recently-viewed"),
  recordRecentlyViewed: (productId: number) =>
    apiClient.post("/accounts/buyer/recently-viewed", { productId }),
  clearRecentlyViewed: () => apiClient.delete("/accounts/buyer/recently-viewed"),
  getCoupons: (params?: { storeId?: number }) =>
    apiClient.get("/accounts/buyer/coupons", {
      params: params?.storeId != null ? { storeId: params.storeId } : undefined,
    }),
}

export const storesApi = {
  getProfile: (storeId: number | string) =>
    apiClient.get<{ store: Record<string, unknown> }>(`/stores/${storeId}`),
  getProducts: (
    storeId: number | string,
    params?: { limit?: number; sort?: "newest" | "popular" | "relevance" },
  ) =>
    apiClient.get<{ products: Record<string, unknown>[] }>(`/stores/${storeId}/products`, {
      params: {
        limit: params?.limit,
        sort: params?.sort === "relevance" ? undefined : params?.sort,
      },
    }),
  getReviews: (storeId: number | string, params?: { limit?: number }) =>
    apiClient.get<{
      reviews: Record<string, unknown>[]
      breakdown: Record<string, number>
    }>(`/stores/${storeId}/reviews`, { params: { limit: params?.limit } }),
}

export interface SavedAddressDto {
  id: string
  label: string
  regionCode: string
  regionName: string
  provinceCode?: string
  provinceName?: string
  municipalityCode: string
  municipalityName: string
  barangayCode: string
  barangayName: string
  streetAddress?: string
  postalCode?: string
  isDefault?: boolean
}

export const addressesApi = {
  list: () => apiClient.get<{ addresses: SavedAddressDto[] }>("/user/addresses"),
  create: (data: Omit<SavedAddressDto, "id">) => apiClient.post("/user/addresses", data),
  update: (id: string, data: Partial<SavedAddressDto>) =>
    apiClient.put(`/user/addresses/${id}`, data),
  delete: (id: string) => apiClient.delete(`/user/addresses/${id}`),
  setDefault: (id: string) => apiClient.patch(`/user/addresses/${id}/default`),
}

export interface ChatPeerDto {
  name?: string
  role?: string
  userId?: number
  avatarUrl?: string | null
  isVerified?: boolean
  isOnline?: boolean
}

export interface ChatConversationDto {
  id: number
  title?: string
  kind?: string
  orderId?: number | null
  storeId?: number | null
  unreadCount?: number
  lastMessagePreview?: string
  lastMessageAt?: string | null
  isPinned?: boolean
  isArchived?: boolean
  peer?: ChatPeerDto
}

export interface ChatMessageDto {
  id: number
  conversationId: number
  senderUserId?: number | null
  senderRole?: string
  body?: string
  messageType?: string
  metadata?: Record<string, unknown>
  createdAt?: string | null
  isMine?: boolean
}

export interface ChatMessagesResponse {
  messages: ChatMessageDto[]
  nextCursor: number | null
  peer?: ChatPeerDto
  conversation?: ChatConversationDto
}

export const chatApi = {
  listConversations: (archived = false) =>
    apiClient.get<{ conversations: ChatConversationDto[]; unreadTotal?: number }>(
      "/chat/conversations",
      {
        params: archived ? { archived: "true" } : undefined,
      },
    ),
  getSupportConversation: () =>
    apiClient.get<{ conversation: ChatConversationDto }>("/chat/conversations/support"),
  openOrderChat: (orderId: number) =>
    apiClient.post<{ conversation: ChatConversationDto }>("/chat/conversations/from-order", {
      orderId,
    }),
  createConversation: (data: { kind: string; storeId?: number; orderId?: number }) =>
    apiClient.post<{ conversation: ChatConversationDto }>("/chat/conversations", data),
  fetchMessages: (conversationId: number, params?: { cursor?: number; limit?: number }) =>
    apiClient.get<ChatMessagesResponse>(`/chat/conversations/${conversationId}/messages`, {
      params,
    }),
  sendMessage: (
    conversationId: number,
    data: { body?: string; messageType: string; metadata?: Record<string, unknown> },
  ) => apiClient.post<{ message: ChatMessageDto }>(
    `/chat/conversations/${conversationId}/messages`,
    data,
  ),
  getUnreadTotal: () => apiClient.get<{ unreadTotal: number }>("/chat/unread-count"),
  markRead: (conversationId: number) =>
    apiClient.post(`/chat/conversations/${conversationId}/read`),
  setArchived: (conversationId: number, isArchived: boolean) =>
    apiClient.patch<{ isArchived: boolean }>(`/chat/conversations/${conversationId}/archive`, {
      isArchived,
    }),
  deleteConversation: (conversationId: number) =>
    apiClient.delete(`/chat/conversations/${conversationId}`),
  togglePin: (conversationId: number, isPinned?: boolean) =>
    apiClient.patch<{ isPinned: boolean }>(`/chat/conversations/${conversationId}/pin`, {
      ...(isPinned !== undefined ? { isPinned } : {}),
    }),
  uploadFile: (file: File) => {
    const formData = new FormData()
    formData.append("file", file)
    return apiClient.post<{ url: string; fileName: string; messageType: string }>(
      "/chat/upload",
      formData,
      { headers: { "Content-Type": "multipart/form-data" } },
    )
  },
  shareProducts: (storeId?: number) =>
    apiClient.get<{ products: Array<{ id: number; name: string; price: number; imageUrl?: string }> }>(
      "/chat/share/products",
      { params: storeId != null ? { storeId } : undefined },
    ),
  shareOrders: () =>
    apiClient.get<{
      orders: Array<{
        orderId: number
        orderNumber: string
        status: string
        productName: string
        productImageUrl?: string
        totalAmount: number
      }>
    }>("/chat/share/orders"),
}

// Notifications API
export interface NotificationDto {
  id: number
  title: string
  description: string
  createdAt: string | null
  read: boolean
  role?: string | null
  page?: string | null
}

export const notificationsApi = {
  getAll: (params?: { role?: string; page?: string; limit?: number; unreadOnly?: boolean }) =>
    apiClient.get<{ notifications: NotificationDto[] }>("/notifications", { params }),

  markAsRead: (notificationId: number) =>
    apiClient.post(`/notifications/${notificationId}/mark-read`),

  markAllAsRead: (data?: { role?: string; page?: string }) =>
    apiClient.post("/notifications/mark-all-read", data ?? {}),
}

// Philippine Geographic API (proxied through Next.js API routes to avoid CORS)
// Uses relative URLs to hit Next.js API routes (not the Flask backend)
// Uses PSGC API (psgc.gitlab.io) for accurate Philippine location data
export const phGeoApi = {
  getRegions: () => axios.get("/api/geo/regions"),
  getProvinces: (regionCode: string) => axios.get(`/api/geo/regions/${regionCode}/provinces`),
  // For NCR (region 13/130000000), skip province and get cities directly from region
  getMunicipalities: (regionCode: string, provinceCode?: string) => {
    // NCR has no provinces - get cities directly from region
    if (isNCRRegion(regionCode)) {
      return axios.get(`/api/geo/regions/${regionCode}/cities-municipalities`)
    }
    // Normal flow: get cities from province
    return axios.get(`/api/geo/provinces/${provinceCode}/cities-municipalities`)
  },
  getBarangays: (municipalityCode: string) =>
    axios.get(`/api/geo/cities-municipalities/${municipalityCode}/barangays`),
}

// NCR region codes - NCR has no provinces, cities are directly under region
// PSGC code for NCR is 130000000 (9 digits)
export const NCR_REGION_CODES = ["13", "130000000", "1300000000", "NCR", "Metro Manila", "National Capital Region"]

// Check if region is NCR (National Capital Region)
export function isNCRRegion(regionCode: string): boolean {
  if (!regionCode) return false
  const normalized = regionCode.toString().trim()
  return NCR_REGION_CODES.some(code => normalized === code || normalized.startsWith(code))
}

// Types
export interface BuyerRegistrationData {
  givenName: string
  surname: string
  email: string
  password: string
  contactNumber: string
  address: AddressData
  validId: File | string
}

export interface SellerRegistrationData {
  givenName: string
  surname: string
  email: string
  password: string
  contactNumber: string
  shopName: string
  categories: string[]
  logo: File | string
  tagline: string
  description: string
  address: AddressData
  documents: {
    dti: File | string
    birTin: File | string
    businessPermit: File | string
    validId: File | string
  }
}

export interface RiderRegistrationData {
  givenName: string
  surname: string
  email: string
  password: string
  contactNumber: string
  vehicleType: string
  licenseNumber: string
  license: File | string
  orCr: File | string
  address: AddressData
}

export interface AddressData {
  regionCode: string
  regionName: string
  provinceCode?: string
  provinceName?: string
  municipalityCode: string
  municipalityName: string
  barangayCode: string
  barangayName: string
  streetAddress?: string
  postalCode?: string
}

// Check if address is complete (handles NCR case where province is optional)
export function isAddressComplete(address: Partial<AddressData>): boolean {
  const hasRegion = !!address.regionCode
  const hasMunicipality = !!address.municipalityCode
  const hasBarangay = !!address.barangayCode
  // Province is required only for non-NCR regions
  const needsProvince = !isNCRRegion(address.regionCode || "")
  const hasProvince = !!address.provinceCode
  
  return hasRegion && hasMunicipality && hasBarangay && (!needsProvince || hasProvince)
}

export interface ProductQueryParams {
  search?: string
  category?: string
  subcategory?: string
  minPrice?: number
  maxPrice?: number
  size?: string[]
  color?: string[]
  seller?: string
  sort?: "newest" | "price_asc" | "price_desc" | "popular"
  page?: number
  limit?: number
  exclude?: string
}

export interface ProductVariant {
  size: string
  color: string
  sku?: string
}

export interface CheckoutData {
  shippingAddress: AddressData
  paymentMethod: string
  items: CartItem[]
  shippingFee?: number
  idempotencyKey?: string
}

export interface CartItem {
  productId: string
  quantity: number
  variant?: ProductVariant
}

export interface OrderQueryParams {
  status?: string
  page?: number
  limit?: number
}

export interface UserQueryParams {
  role?: string
  status?: string
  page?: number
  limit?: number
}

export interface ProductFormData {
  name: string
  category: string
  subcategory?: string
  description: string
  images: (File | string)[]
  variations: ProductVariation[]
  price: number
  salePrice?: number
  visibility: boolean
}

// --- Reports API ---

export const reportsApi = {
  /** Load report reasons for the role being reported (buyer | seller | rider). */
  getReportTypes: (targetRole: string) =>
    apiClient.get<{ types: Record<string, unknown>[] }>("/reports/types", {
      params: { targetRole },
    }),
  submitReport: (data: FormData) =>
    apiClient.post("/reports", data, {
      headers: { "Content-Type": "multipart/form-data" },
    }),
  getMyReports: () =>
    apiClient.get<{ reports: Record<string, unknown>[] }>("/reports"),
  getMyReport: (reportId: number) =>
    apiClient.get<{ report: Record<string, unknown> }>(`/reports/${reportId}`),
  getMyPunishments: () =>
    apiClient.get<{ punishments: Record<string, unknown>[] }>("/reports/punishments"),
  getMyViolations: () =>
    apiClient.get<{ violations: Record<string, unknown>[] }>("/reports/violations"),
}

export const adminReportsApi = {
  list: (params?: {
    status?: string
    reporterRole?: string
    targetRole?: string
    priority?: string
    reportTypeId?: number
  }) =>
    apiClient.get<{ reports: Record<string, unknown>[] }>("/reports/admin", {
      params,
    }),
  get: (reportId: number) =>
    apiClient.get<{ report: Record<string, unknown> }>(`/reports/admin/${reportId}`),
  update: (reportId: number, data: {
    status?: string
    adminNotes?: string
    priority?: string
  }) =>
    apiClient.patch(`/reports/admin/${reportId}`, data),
  issuePunishment: (reportId: number, data: {
    severity: string
    userId: number
    restrictionType?: string
    reason: string
    endDate?: string
  }) =>
    apiClient.post(`/reports/admin/${reportId}/punish`, data),
  listPunishments: (userId?: number) =>
    apiClient.get<{ punishments: Record<string, unknown>[] }>("/reports/admin/punishments", {
      params: userId ? { userId } : undefined,
    }),
  updatePunishment: (punishmentId: number, data: {
    isActive?: boolean
    endDate?: string | null
    reason?: string
  }) =>
    apiClient.patch(`/reports/admin/punishments/${punishmentId}`, data),
  getUserViolations: (userId: number) =>
    apiClient.get<{ violations: Record<string, unknown>[] }>(`/reports/admin/violations/${userId}`),
}

export interface ProductVariation {
  size: string
  color: string
  sku: string
  inventory: number
  price?: number
}
