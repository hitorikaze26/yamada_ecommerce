"use client"

import { useEffect, useState, useRef } from "react"
import type React from "react"
import { motion, AnimatePresence } from "framer-motion"
import Image from "next/image"
import { Icon } from "@/components/ui/icon"
import { sellerShopApi } from "@/lib/api"
import { CATEGORIES } from "@/lib/types"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Switch } from "@/components/ui/switch"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { toast } from "sonner"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"

// Types
interface ShippingSetting {
  id: number
  regionCode: string | null
  regionName: string
  provinceCode: string | null
  provinceName: string
  cityCode: string | null
  cityName: string
  shippingFee: number
  isActive: boolean
}

interface PaymentSettings {
  codEnabled: boolean
}

interface OrderSettings {
  allowCancellation: boolean
  maxCancellationHours: number
  allowReturns: boolean
  returnPeriodDays: number
}

interface ShopCustomization {
  announcement: string | null
  primaryColor: string
  themeMode: string
}

interface ChatSettings {
  autoReplyEnabled: boolean
  autoReplyMessage: string
}

// Animation variants
const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: "easeInOut" },
  },
}

export default function ShopSettingsPage() {
  const [activeTab, setActiveTab] = useState("shipping")
  const [hasChanges, setHasChanges] = useState<Record<string, boolean>>({})

  // Profile
  const [formData, setFormData] = useState({
    shopName: "",
    tagline: "",
    description: "",
    givenName: "",
    surname: "",
    email: "",
    phone: "",
    categories: [] as string[],
    freeShippingThreshold: "1500",
  })
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState<string | null>(null)
  const [isUploading, setIsUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null)
  const [bannerUrl, setBannerUrl] = useState<string | null>(null)
  const [storeStatus, setStoreStatus] = useState<string | null>(null)
  const [isVerified, setIsVerified] = useState(false)
  const [rating, setRating] = useState(0)
  const [totalSales, setTotalSales] = useState(0)
  const [address, setAddress] = useState<any>(null)
  const [documents, setDocuments] = useState<any>(null)
  
  const avatarInputRef = useRef<HTMLInputElement>(null)
  const bannerInputRef = useRef<HTMLInputElement>(null)

  // Shipping
  const [shippingSettings, setShippingSettings] = useState<ShippingSetting[]>([])
  const [newShipping, setNewShipping] = useState({
    regionName: "",
    provinceName: "",
    cityName: "",
  })
  const [editingShipping, setEditingShipping] = useState<ShippingSetting | null>(null)
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false)

  // Philippine locations
  const [philippineLocations, setPhilippineLocations] = useState<any>(null)
  const [regions, setRegions] = useState<string[]>([])
  const [provinces, setProvinces] = useState<string[]>([])
  const [cities, setCities] = useState<string[]>([])
  const [selectedRegion, setSelectedRegion] = useState("")
  const [selectedProvince, setSelectedProvince] = useState("")
  const [selectedCity, setSelectedCity] = useState("")
  const [isCopyDialogOpen, setIsCopyDialogOpen] = useState(false)

  // Payment
  const [paymentSettings, setPaymentSettings] = useState<PaymentSettings>({ codEnabled: true })
  const [originalPayment, setOriginalPayment] = useState<PaymentSettings>({ codEnabled: true })

  // Order
  const [orderSettings, setOrderSettings] = useState<OrderSettings>({
    allowCancellation: true,
    maxCancellationHours: 24,
    allowReturns: true,
    returnPeriodDays: 7,
  })
  const [originalOrder, setOriginalOrder] = useState<OrderSettings>({
    allowCancellation: true,
    maxCancellationHours: 24,
    allowReturns: true,
    returnPeriodDays: 7,
  })

  // Customization
  const [customization, setCustomization] = useState<ShopCustomization>({
    announcement: "",
    primaryColor: "#3b82f6",
    themeMode: "light",
  })
  const [originalCustomization, setOriginalCustomization] = useState<ShopCustomization>({
    announcement: "",
    primaryColor: "#3b82f6",
    themeMode: "light",
  })

  // Chat
  const [chatSettings, setChatSettings] = useState<ChatSettings>({
    autoReplyEnabled: false,
    autoReplyMessage: "Thank you for your message! We will get back to you shortly.",
  })
  const [originalChat, setOriginalChat] = useState<ChatSettings>({
    autoReplyEnabled: false,
    autoReplyMessage: "Thank you for your message! We will get back to you shortly.",
  })

  // Load all settings
  useEffect(() => {
    const loadAll = async () => {
      try {
        setIsLoading(true)
        setError(null)
        
        // Load profile
        const profileRes = await sellerShopApi.getProfile()
        const profile = (profileRes.data as any)?.profile
        
        setFormData({
          shopName: profile?.shopName ?? "",
          tagline: profile?.tagline ?? "",
          description: profile?.description ?? "",
          givenName: profile?.givenName ?? "",
          surname: profile?.surname ?? "",
          email: profile?.email ?? "",
          phone: profile?.contactNumber ?? "",
          categories: Array.isArray(profile?.categories) ? profile.categories : [],
          freeShippingThreshold: profile?.freeShippingThreshold?.toString() ?? "1500",
        })
        
        const avatar = (profile as any)?.avatarUrl as string | undefined
        const banner = (profile as any)?.bannerUrl as string | undefined
        if (avatar) setAvatarUrl(avatar)
        if (banner) setBannerUrl(banner)
        
        setStoreStatus(profile?.storeStatus ?? null)
        setIsVerified(profile?.isVerified ?? false)
        setRating(profile?.rating ?? 0)
        setTotalSales(profile?.totalSales ?? 0)
        setAddress(profile?.address ?? null)
        setDocuments(profile?.documents ?? null)

        const storeId = profile?.storeId
        if (storeId != null && storeId !== 0) {
          const settingsRes = await sellerShopApi.getAllSettings()
          const data = settingsRes.data.settings

          if (data.shipping) setShippingSettings(data.shipping)
          if (data.payment) {
            setPaymentSettings(data.payment)
            setOriginalPayment(data.payment)
          }
          if (data.order) {
            setOrderSettings(data.order)
            setOriginalOrder(data.order)
          }
          if (data.customization) {
            setCustomization(data.customization)
            setOriginalCustomization(data.customization)
          }
          if (data.chat) {
            setChatSettings(data.chat)
            setOriginalChat(data.chat)
          }
        }
      } catch (err: any) {
        const msg = err?.response?.data?.msg || "Failed to load shop settings."
        setError(msg)
        toast.error(msg)
      } finally {
        setIsLoading(false)
      }
    }

    void loadAll()
  }, [])

  // Track changes
  useEffect(() => {
    setHasChanges({
      payment: JSON.stringify(paymentSettings) !== JSON.stringify(originalPayment),
      order: JSON.stringify(orderSettings) !== JSON.stringify(originalOrder),
      customization: JSON.stringify(customization) !== JSON.stringify(originalCustomization),
      chat: JSON.stringify(chatSettings) !== JSON.stringify(originalChat),
    })
  }, [paymentSettings, orderSettings, customization, chatSettings, originalPayment, originalOrder, originalCustomization, originalChat])

  // Profile handlers
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setSuccess(null)
    setIsSaving("profile")

    try {
      await sellerShopApi.updateProfile({
        shopName: formData.shopName,
        tagline: formData.tagline,
        description: formData.description,
        givenName: formData.givenName,
        surname: formData.surname,
        email: formData.email,
        contactNumber: formData.phone,
      })
      setSuccess("Shop profile updated successfully.")
      toast.success("Shop profile updated successfully.")
    } catch (err: any) {
      const msg = err?.response?.data?.msg || "Failed to update shop settings."
      setError(msg)
      toast.error(msg)
    } finally {
      setIsSaving(null)
    }
  }

  const handleAvatarChange = async (file: File) => {
    if (!file) return

    try {
      setIsUploading(true)
      const res = await sellerShopApi.uploadAvatar(file)
      const url = (res.data as any)?.avatarUrl as string | undefined
      if (url) {
        setAvatarUrl(url)
        toast.success("Avatar uploaded successfully")
      }
    } catch (err) {
      console.error("Failed to upload seller avatar", err)
      setError("Failed to upload profile photo.")
      toast.error("Failed to upload profile photo.")
    } finally {
      setIsUploading(false)
    }
  }

  const handleBannerChange = async (file: File) => {
    if (!file) return

    try {
      setIsUploading(true)
      const res = await sellerShopApi.uploadBanner(file)
      const url = (res.data as any)?.bannerUrl as string | undefined
      if (url) {
        setBannerUrl(url)
        toast.success("Banner uploaded successfully")
      }
    } catch (err) {
      console.error("Failed to upload seller banner", err)
      setError("Failed to upload cover photo.")
      toast.error("Failed to upload cover photo.")
    } finally {
      setIsUploading(false)
    }
  }

  const onAvatarFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) handleAvatarChange(file)
    e.target.value = ""
  }

  const onBannerFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) handleBannerChange(file)
    e.target.value = ""
  }

  // Shipping handlers
  const handleAddShipping = async () => {
    if (!newShipping.regionName || !newShipping.provinceName || !newShipping.cityName) {
      toast.error("Please fill in all location fields")
      return
    }

    // Auto-calculate shipping fee based on region
    const getShippingFeeByRegion = (region: string): number => {
      const regionLower = region.toLowerCase()
      if (regionLower.includes("metro manila") || regionLower.includes("ncr")) {
        return 30
      } else if (regionLower.includes("luzon")) {
        return 60
      } else if (regionLower.includes("visayas")) {
        return 100
      } else if (regionLower.includes("mindanao")) {
        return 130
      } else {
        return 130 // Default to highest rate
      }
    }

    const calculatedShippingFee = getShippingFeeByRegion(newShipping.regionName)

    setIsSaving("shipping-add")
    try {
      await sellerShopApi.createShippingSetting({
        regionName: newShipping.regionName,
        provinceName: newShipping.provinceName,
        cityName: newShipping.cityName,
        shippingFee: calculatedShippingFee,
      })
      toast.success(`Shipping location added with ₱${calculatedShippingFee} fee`)
      setNewShipping({ regionName: "", provinceName: "", cityName: "" })
      setIsAddDialogOpen(false)
      const res = await sellerShopApi.getAllSettings()
      if (res.data.settings.shipping) setShippingSettings(res.data.settings.shipping)
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to add shipping location")
    } finally {
      setIsSaving(null)
    }
  }

  const handleUpdateShipping = async () => {
    if (!editingShipping) return

    // Auto-calculate shipping fee based on region
    const getShippingFeeByRegion = (region: string): number => {
      const regionLower = region.toLowerCase()
      if (regionLower.includes("metro manila") || regionLower.includes("ncr")) {
        return 30
      } else if (regionLower.includes("luzon")) {
        return 60
      } else if (regionLower.includes("visayas")) {
        return 100
      } else if (regionLower.includes("mindanao")) {
        return 130
      } else {
        return 130 // Default to highest rate
      }
    }

    const calculatedShippingFee = getShippingFeeByRegion(editingShipping.regionName)

    setIsSaving(`shipping-${editingShipping.id}`)
    try {
      await sellerShopApi.updateShippingSetting(editingShipping.id, {
        regionName: editingShipping.regionName,
        provinceName: editingShipping.provinceName,
        cityName: editingShipping.cityName,
        shippingFee: calculatedShippingFee,
        isActive: editingShipping.isActive,
      })
      toast.success(`Shipping location updated with ₱${calculatedShippingFee} fee`)
      setEditingShipping(null)
      const res = await sellerShopApi.getAllSettings()
      if (res.data.settings.shipping) setShippingSettings(res.data.settings.shipping)
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update shipping location")
    } finally {
      setIsSaving(null)
    }
  }

  const handleToggleShippingActive = async (setting: ShippingSetting) => {
    setIsSaving(`shipping-toggle-${setting.id}`)
    try {
      await sellerShopApi.updateShippingSetting(setting.id, {
        isActive: !setting.isActive,
      })
      toast.success(setting.isActive ? "Location disabled" : "Location enabled")
      const res = await sellerShopApi.getAllSettings()
      if (res.data.settings.shipping) setShippingSettings(res.data.settings.shipping)
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update status")
    } finally {
      setIsSaving(null)
    }
  }

  const handleDeleteShipping = async (id: number) => {
    if (!confirm("Are you sure you want to delete this shipping location?")) return

    setIsSaving(`shipping-delete-${id}`)
    try {
      await sellerShopApi.deleteShippingSetting(id)
      toast.success("Shipping location deleted")
      const res = await sellerShopApi.getAllSettings()
      if (res.data.settings.shipping) setShippingSettings(res.data.settings.shipping)
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to delete shipping location")
    } finally {
      setIsSaving(null)
    }
  }

  const handleUseGeolocation = async () => {
    if (!navigator.geolocation) {
      toast.error("Geolocation is not supported by your browser")
      return
    }

    setIsSaving("geolocation")
    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0,
        })
      })

      const { latitude, longitude } = position.coords
      
      // Use OpenStreetMap Nominatim API for reverse geocoding (free)
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&addressdetails=1&country=Philippines`,
        {
          headers: {
            'User-Agent': 'Yamada-Ecommerce/1.0',
          },
        }
      )

      if (!response.ok) {
        throw new Error("Failed to fetch location data")
      }

      const data = await response.json()
      const address = data.address

      // Extract location components and map to Philippine regions
      let regionName = ""
      let provinceName = ""
      let cityName = ""

      // Map Philippine administrative divisions to regions
      const regionMap: { [key: string]: string } = {
        "National Capital Region": "Metro Manila",
        "NCR": "Metro Manila",
        "Metro Manila": "Metro Manila",
        "Calabarzon": "Luzon",
        "Mimaropa": "Luzon",
        "Bicol Region": "Luzon",
        "Cagayan Valley": "Luzon",
        "Central Luzon": "Luzon",
        "Ilocos Region": "Luzon",
        "Cordillera Administrative Region": "Luzon",
        "Western Visayas": "Visayas",
        "Central Visayas": "Visayas",
        "Eastern Visayas": "Visayas",
        "Northern Mindanao": "Mindanao",
        "Davao Region": "Mindanao",
        "Soccsksargen": "Mindanao",
        "Caraga": "Mindanao",
        "Bangsamoro": "Mindanao",
        "Zamboanga Peninsula": "Mindanao",
      }

      // Set region based on state/province
      if (address.state) {
        const stateUpper = address.state.toUpperCase()
        for (const [key, value] of Object.entries(regionMap)) {
          if (stateUpper.includes(key.toUpperCase())) {
            regionName = value
            break
          }
        }
      }

      // Fallback region detection based on common Philippine locations
      if (!regionName) {
        const locationString = `${address.city || ""} ${address.province || ""} ${address.state || ""}`.toLowerCase()
        if (locationString.includes("manila") || locationString.includes("quezon") || locationString.includes("makati") || locationString.includes("pasig")) {
          regionName = "Metro Manila"
        } else if (locationString.includes("cebu") || locationString.includes("iloilo") || locationString.includes("bacolod")) {
          regionName = "Visayas"
        } else if (locationString.includes("davao") || locationString.includes("cagayan") || locationString.includes("mindanao")) {
          regionName = "Mindanao"
        } else {
          regionName = "Luzon" // Default fallback
        }
      }

      provinceName = address.state || address.province || ""
      cityName = address.city || address.town || address.village || ""

      setNewShipping({
        ...newShipping,
        regionName,
        provinceName,
        cityName,
      })

      toast.success("Location detected successfully!")
    } catch (error: any) {
      console.error("Geolocation error:", error)
      if (error.code === 1) {
        toast.error("Location access denied. Please enable location permissions.")
      } else if (error.code === 2) {
        toast.error("Unable to determine your location. Please try again.")
      } else if (error.code === 3) {
        toast.error("Location request timed out. Please try again.")
      } else {
        toast.error("Failed to detect location. Please enter manually.")
      }
    } finally {
      setIsSaving(null)
    }
  }

  const handleUseGeolocationForEdit = async () => {
    if (!navigator.geolocation) {
      toast.error("Geolocation is not supported by your browser")
      return
    }

    if (!editingShipping) return

    setIsSaving("geolocation-edit")
    try {
      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0,
        })
      })

      const { latitude, longitude } = position.coords
      
      // Use OpenStreetMap Nominatim API for reverse geocoding (free)
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&addressdetails=1&country=Philippines`,
        {
          headers: {
            'User-Agent': 'Yamada-Ecommerce/1.0',
          },
        }
      )

      if (!response.ok) {
        throw new Error("Failed to fetch location data")
      }

      const data = await response.json()
      const address = data.address

      // Extract location components and map to Philippine regions
      let regionName = ""
      let provinceName = ""
      let cityName = ""

      // Map Philippine administrative divisions to regions
      const regionMap: { [key: string]: string } = {
        "National Capital Region": "Metro Manila",
        "NCR": "Metro Manila",
        "Metro Manila": "Metro Manila",
        "Calabarzon": "Luzon",
        "Mimaropa": "Luzon",
        "Bicol Region": "Luzon",
        "Cagayan Valley": "Luzon",
        "Central Luzon": "Luzon",
        "Ilocos Region": "Luzon",
        "Cordillera Administrative Region": "Luzon",
        "Western Visayas": "Visayas",
        "Central Visayas": "Visayas",
        "Eastern Visayas": "Visayas",
        "Northern Mindanao": "Mindanao",
        "Davao Region": "Mindanao",
        "Soccsksargen": "Mindanao",
        "Caraga": "Mindanao",
        "Bangsamoro": "Mindanao",
        "Zamboanga Peninsula": "Mindanao",
      }

      // Set region based on state/province
      if (address.state) {
        const stateUpper = address.state.toUpperCase()
        for (const [key, value] of Object.entries(regionMap)) {
          if (stateUpper.includes(key.toUpperCase())) {
            regionName = value
            break
          }
        }
      }

      // Fallback region detection based on common Philippine locations
      if (!regionName) {
        const locationString = `${address.city || ""} ${address.province || ""} ${address.state || ""}`.toLowerCase()
        if (locationString.includes("manila") || locationString.includes("quezon") || locationString.includes("makati") || locationString.includes("pasig")) {
          regionName = "Metro Manila"
        } else if (locationString.includes("cebu") || locationString.includes("iloilo") || locationString.includes("bacolod")) {
          regionName = "Visayas"
        } else if (locationString.includes("davao") || locationString.includes("cagayan") || locationString.includes("mindanao")) {
          regionName = "Mindanao"
        } else {
          regionName = "Luzon" // Default fallback
        }
      }

      provinceName = address.state || address.province || ""
      cityName = address.city || address.town || address.village || ""

      setEditingShipping({
        ...editingShipping,
        regionName,
        provinceName,
        cityName,
      })

      toast.success("Location detected successfully!")
    } catch (error: any) {
      console.error("Geolocation error:", error)
      if (error.code === 1) {
        toast.error("Location access denied. Please enable location permissions.")
      } else if (error.code === 2) {
        toast.error("Unable to determine your location. Please try again.")
      } else if (error.code === 3) {
        toast.error("Location request timed out. Please try again.")
      } else {
        toast.error("Failed to detect location. Please enter manually.")
      }
    } finally {
      setIsSaving(null)
    }
  }

  // Fetch Philippine locations
  const fetchPhilippineLocations = async () => {
    try {
      const response = await fetch('/api/philippine-locations/all')
      const data = await response.json()
      setPhilippineLocations(data)
      setRegions(Object.keys(data))
    } catch (error) {
      console.error('Failed to fetch Philippine locations:', error)
    }
  }

  // Handle region selection
  const handleRegionChange = (region: string) => {
    setSelectedRegion(region)
    setSelectedProvince("")
    setSelectedCity("")
    
    if (philippineLocations && philippineLocations[region]) {
      const provinceList = Object.keys(philippineLocations[region].provinces)
      setProvinces(provinceList)
      setCities([])
    }
  }

  // Handle province selection
  const handleProvinceChange = (province: string) => {
    setSelectedProvince(province)
    setSelectedCity("")
    
    if (philippineLocations && selectedRegion && philippineLocations[selectedRegion].provinces[province]) {
      const cityList = philippineLocations[selectedRegion].provinces[province].cities
      setCities(cityList)
    }
  }

  // Handle city selection
  const handleCityChange = (city: string) => {
    setSelectedCity(city)
    
    // Update the new shipping form
    setNewShipping({
      ...newShipping,
      regionName: selectedRegion,
      provinceName: selectedProvince,
      cityName: city,
    })
  }

  // Handle copying existing location
  const handleCopyExistingLocation = (setting: ShippingSetting) => {
    setNewShipping({
      ...newShipping,
      regionName: setting.regionName,
      provinceName: setting.provinceName,
      cityName: setting.cityName,
    })
    
    // Update dropdown selections if the location exists in Philippine locations
    if (philippineLocations && philippineLocations[setting.regionName]) {
      setSelectedRegion(setting.regionName)
      if (philippineLocations[setting.regionName].provinces[setting.provinceName]) {
        setSelectedProvince(setting.provinceName)
        const cities = philippineLocations[setting.regionName].provinces[setting.provinceName].cities
        setCities(cities)
        if (cities.includes(setting.cityName)) {
          setSelectedCity(setting.cityName)
        }
      }
    }
    
    setIsCopyDialogOpen(false)
    toast.success("Location copied successfully!")
  }

  // Load Philippine locations on component mount
  useEffect(() => {
    fetchPhilippineLocations()
  }, [])

  // Payment handler
  const handleUpdatePayment = async () => {
    setIsSaving("payment")
    try {
      await sellerShopApi.updatePaymentSettings({ codEnabled: paymentSettings.codEnabled })
      setOriginalPayment(paymentSettings)
      toast.success("Payment settings saved successfully")
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update payment settings")
    } finally {
      setIsSaving(null)
    }
  }

  // Order handler
  const handleUpdateOrder = async () => {
    setIsSaving("order")
    try {
      await sellerShopApi.updateOrderSettings({
        allowCancellation: orderSettings.allowCancellation,
        maxCancellationHours: orderSettings.maxCancellationHours,
        allowReturns: orderSettings.allowReturns,
        returnPeriodDays: orderSettings.returnPeriodDays,
      })
      setOriginalOrder(orderSettings)
      toast.success("Order settings saved successfully")
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update order settings")
    } finally {
      setIsSaving(null)
    }
  }

  // Customization handler
  const handleUpdateCustomization = async () => {
    setIsSaving("customization")
    try {
      await sellerShopApi.updateShopCustomization({
        announcement: customization.announcement,
        primaryColor: customization.primaryColor,
        themeMode: customization.themeMode,
      })
      setOriginalCustomization(customization)
      toast.success("Shop customization saved successfully")
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update customization")
    } finally {
      setIsSaving(null)
    }
  }

  // Chat handler
  const handleUpdateChat = async () => {
    setIsSaving("chat")
    try {
      await sellerShopApi.updateChatSettings({
        autoReplyEnabled: chatSettings.autoReplyEnabled,
        autoReplyMessage: chatSettings.autoReplyMessage,
      })
      setOriginalChat(chatSettings)
      toast.success("Chat settings saved successfully")
    } catch (err: any) {
      toast.error(err?.response?.data?.msg || "Failed to update chat settings")
    } finally {
      setIsSaving(null)
    }
  }

  const colorOptions = [
    { name: "Blue", value: "#3b82f6", class: "bg-blue-500" },
    { name: "Purple", value: "#8b5cf6", class: "bg-purple-500" },
    { name: "Pink", value: "#ec4899", class: "bg-pink-500" },
    { name: "Red", value: "#ef4444", class: "bg-red-500" },
    { name: "Orange", value: "#f97316", class: "bg-orange-500" },
    { name: "Green", value: "#22c55e", class: "bg-green-500" },
    { name: "Teal", value: "#14b8a6", class: "bg-teal-500" },
    { name: "Indigo", value: "#6366f1", class: "bg-indigo-500" },
  ]

  return (
    <TooltipProvider>
      <div className="max-w-6xl mx-auto p-6 space-y-8">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="space-y-2"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-primary/70 flex items-center justify-center shadow-lg">
              <Icon name="cog-6-tooth" className="text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-3xl font-bold tracking-tight">Shop operations</h1>
              <p className="text-muted-foreground">
                Shipping, payments, order policies, appearance, and chat auto-reply.{" "}
                <a href="/seller/branding" className="text-primary hover:underline">
                  Edit shop branding
                </a>
              </p>
            </div>
          </div>
        </motion.div>

        {error && (
          <div className="p-3 rounded-lg bg-destructive/10 text-destructive text-sm flex items-center gap-2">
            <Icon name="exclamation-circle" />
            {error}
          </div>
        )}
        {success && (
          <div className="p-3 rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-sm flex items-center gap-2">
            <Icon name="check-circle" />
            {success}
          </div>
        )}

        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid grid-cols-5 w-full max-w-5xl p-1 bg-muted/50 rounded-xl">
            {[
              { id: "shipping", icon: "truck", label: "Shipping" },
              { id: "payment", icon: "credit-card", label: "Payment" },
              { id: "order", icon: "clipboard-document-list", label: "Orders" },
              { id: "appearance", icon: "swatch", label: "Appearance" },
              { id: "chat", icon: "chat-bubble-left-right", label: "Auto-Reply" },
            ].map((tab) => (
              <TabsTrigger
                key={tab.id}
                value={tab.id}
                className={cn(
                  "flex items-center gap-2 rounded-lg py-2.5 px-4 transition-all",
                  "data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-foreground",
                  "hover:text-foreground/80"
                )}
              >
                <Icon name={tab.icon} size="sm" />
                <span className="hidden sm:inline font-medium">{tab.label}</span>
                {hasChanges[tab.id] && (
                  <span className="w-2 h-2 rounded-full bg-amber-500 ml-1" />
                )}
              </TabsTrigger>
            ))}
          </TabsList>

          <AnimatePresence mode="wait">
            {/* Shipping Tab */}
            <TabsContent value="shipping" className="mt-6">
              <motion.div
                variants={containerVariants}
                initial="hidden"
                animate="visible"
                className="space-y-6"
              >
                {/* Shop Address & Shipping Info */}
                <motion.div variants={itemVariants}>
                  <Card className="border-none shadow-lg">
                    <CardHeader className="pb-4">
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center shadow-md">
                          <Icon name="map-pin" className="text-white" />
                        </div>
                        <div>
                          <CardTitle className="text-xl">Shop Location & Shipping</CardTitle>
                          <CardDescription>Shipping fees are automatically calculated based on your shop location</CardDescription>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-6">
                      {/* Shop Address */}
                      <div className="p-4 bg-muted/30 rounded-xl">
                        <div className="flex items-center gap-2 mb-3">
                          <Icon name="store" size="sm" className="text-blue-600" />
                          <h3 className="font-semibold">Shop Address</h3>
                        </div>
                        {address ? (
                          <div className="space-y-1 text-sm">
                            <p className="font-medium">{address.streetAddress}</p>
                            <p>{address.barangayName}, {address.municipalityName}</p>
                            <p>{address.provinceName}, {address.regionName} {address.postalCode}</p>
                          </div>
                        ) : (
                          <p className="text-sm text-muted-foreground">No address available</p>
                        )}
                      </div>

                      {/* Shipping Fee Calculation */}
                      <div className="p-4 bg-blue-50 rounded-xl border border-blue-200">
                        <div className="flex items-center gap-2 mb-3">
                          <Icon name="truck" size="sm" className="text-blue-600" />
                          <h3 className="font-semibold">Automatic Shipping Calculation</h3>
                        </div>
                        <div className="space-y-3 text-sm">
                          <div className="flex items-center justify-between">
                            <span className="text-muted-foreground">Based on your location:</span>
                            <Badge variant="secondary" className="bg-blue-100 text-blue-700">
                              {address?.regionName || "Unknown Region"}
                            </Badge>
                          </div>
                          <div className="grid grid-cols-2 gap-4 mt-4">
                            <div className="text-center p-3 bg-white rounded-lg border">
                              <div className="font-semibold text-lg text-blue-600">₱30</div>
                              <div className="text-xs text-muted-foreground">Metro Manila</div>
                            </div>
                            <div className="text-center p-3 bg-white rounded-lg border">
                              <div className="font-semibold text-lg text-blue-600">₱60</div>
                              <div className="text-xs text-muted-foreground">Luzon</div>
                            </div>
                            <div className="text-center p-3 bg-white rounded-lg border">
                              <div className="font-semibold text-lg text-blue-600">₱100</div>
                              <div className="text-xs text-muted-foreground">Visayas</div>
                            </div>
                            <div className="text-center p-3 bg-white rounded-lg border">
                              <div className="font-semibold text-lg text-blue-600">₱130</div>
                              <div className="text-xs text-muted-foreground">Mindanao</div>
                            </div>
                          </div>
                          <div className="mt-4 p-3 bg-green-50 rounded-lg border border-green-200">
                            <div className="flex items-center gap-2 text-green-700">
                              <Icon name="check-circle" size="sm" />
                              <span className="font-medium">Free shipping for orders over ₱2,000</span>
                            </div>
                          </div>
                        </div>
                      </div>

                      {/* Additional Shipping Locations */}
                      <div>
                        <div className="flex items-center justify-between mb-4">
                          <div className="flex items-center gap-2">
                            <Icon name="plus-circle" size="sm" className="text-blue-600" />
                            <h3 className="font-semibold">Additional Shipping Locations</h3>
                          </div>
                          <Button
                            onClick={() => setIsAddDialogOpen(true)}
                            size="sm"
                            className="shadow-md hover:shadow-lg transition-shadow"
                          >
                            <Icon name="plus" size="sm" className="mr-2" />
                            Add Location
                          </Button>
                        </div>
                        
                        <AnimatePresence mode="popLayout">
                          {shippingSettings.length === 0 ? (
                            <motion.div
                              initial={{ opacity: 0, scale: 0.95 }}
                              animate={{ opacity: 1, scale: 1 }}
                              className="text-center py-8 bg-muted/30 rounded-xl border-2 border-dashed border-muted"
                            >
                              <div className="w-12 h-12 rounded-full bg-muted mx-auto flex items-center justify-center mb-3">
                                <Icon name="map-pin" className="text-muted-foreground/50" />
                              </div>
                              <h4 className="font-medium text-muted-foreground">No additional locations</h4>
                              <p className="text-sm text-muted-foreground/70 mt-1">Add extra shipping locations if needed</p>
                            </motion.div>
                          ) : (
                            <div className="space-y-2">
                              {shippingSettings.map((setting, index) => (
                                <motion.div
                                  key={setting.id}
                                  layout
                                  initial={{ opacity: 0, y: 10 }}
                                  animate={{ opacity: 1, y: 0 }}
                                  exit={{ opacity: 0, scale: 0.95 }}
                                  transition={{ delay: index * 0.05 }}
                                  className={cn(
                                    "flex items-center justify-between p-3 rounded-lg border transition-all duration-200",
                                    setting.isActive
                                      ? "border-border bg-card hover:border-primary/30"
                                      : "border-muted bg-muted/30 opacity-70"
                                  )}
                                >
                                  <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center">
                                      <Icon name="map-pin" size="sm" className="text-blue-600" />
                                    </div>
                                    <div>
                                      <div className="font-medium text-sm">{setting.cityName}</div>
                                      <div className="text-xs text-muted-foreground">
                                        {setting.provinceName}, {setting.regionName}
                                      </div>
                                    </div>
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <Badge variant="secondary" className="text-xs">
                                      ₱{setting.shippingFee.toFixed(2)}
                                    </Badge>
                                    <Button
                                      variant="ghost"
                                      size="sm"
                                      onClick={() => setEditingShipping(setting)}
                                      className="h-6 w-6 p-0"
                                    >
                                      <Icon name="pencil" size="sm" />
                                    </Button>
                                    <Button
                                      variant="ghost"
                                      size="sm"
                                      onClick={() => handleDeleteShipping(setting.id)}
                                      className="h-6 w-6 p-0 text-destructive hover:text-destructive"
                                    >
                                      <Icon name="trash" size="sm" />
                                    </Button>
                                  </div>
                                </motion.div>
                              ))}
                            </div>
                          )}
                        </AnimatePresence>
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              </motion.div>
            </TabsContent>

            {/* Payment Tab */}
            <TabsContent value="payment" className="mt-6">
              <motion.div variants={containerVariants} initial="hidden" animate="visible" className="max-w-2xl">
                <motion.div variants={itemVariants}>
                  <Card className="border-none shadow-lg">
                    <CardHeader>
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-green-500 to-green-600 flex items-center justify-center shadow-md">
                          <Icon name="credit-card" className="text-white" />
                        </div>
                        <div>
                          <CardTitle className="text-xl">Payment Methods</CardTitle>
                          <CardDescription>Configure accepted payment options</CardDescription>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-6">
                      <div className={cn(
                        "flex items-center justify-between p-5 rounded-xl border-2 transition-all duration-300",
                        paymentSettings.codEnabled
                          ? "border-green-200 bg-green-50/50"
                          : "border-muted bg-muted/30"
                      )}>
                        <div className="flex items-center gap-4">
                          <div className={cn(
                            "w-14 h-14 rounded-xl flex items-center justify-center transition-colors duration-300",
                            paymentSettings.codEnabled ? "bg-green-500" : "bg-muted"
                          )}>
                            <Icon name="banknotes" className={cn(
                              "transition-colors duration-300",
                              paymentSettings.codEnabled ? "text-white" : "text-muted-foreground"
                            )} />
                          </div>
                          <div>
                            <h4 className="font-semibold text-lg">Cash on Delivery (COD)</h4>
                            <p className="text-sm text-muted-foreground">Allow customers to pay when they receive the order</p>
                          </div>
                        </div>
                        <Switch
                          checked={paymentSettings.codEnabled}
                          onCheckedChange={(checked) =>
                            setPaymentSettings({ ...paymentSettings, codEnabled: checked })
                          }
                          className="data-[state=checked]:bg-green-500"
                        />
                      </div>

                      <div className="flex justify-end gap-3 pt-4">
                        {hasChanges.payment && (
                          <Button variant="outline" onClick={() => setPaymentSettings(originalPayment)}>
                            <Icon name="arrow-uturn-left" size="sm" className="mr-2" />
                            Reset
                          </Button>
                        )}
                        <Button
                          onClick={handleUpdatePayment}
                          disabled={isSaving === "payment" || !hasChanges.payment}
                          className="min-w-[120px]"
                        >
                          {isSaving === "payment" ? (
                            <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                          ) : (
                            <Icon name="check" size="sm" className="mr-2" />
                          )}
                          Save Changes
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              </motion.div>
            </TabsContent>

            {/* Orders Tab */}
            <TabsContent value="order" className="mt-6">
              <motion.div variants={containerVariants} initial="hidden" animate="visible" className="max-w-2xl space-y-6">
                <motion.div variants={itemVariants}>
                  <Card className="border-none shadow-lg">
                    <CardHeader>
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-amber-500 to-amber-600 flex items-center justify-center shadow-md">
                          <Icon name="clipboard-document-list" className="text-white" />
                        </div>
                        <div>
                          <CardTitle className="text-xl">Order Rules</CardTitle>
                          <CardDescription>Configure cancellation and return policies</CardDescription>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-8">
                      {/* Cancellation */}
                      <div className="space-y-4">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-amber-100 flex items-center justify-center">
                            <Icon name="x-circle" size="sm" className="text-amber-600" />
                          </div>
                          <h4 className="font-semibold">Order Cancellation</h4>
                        </div>
                        <div className={cn(
                          "p-5 rounded-xl border-2 transition-all duration-300",
                          orderSettings.allowCancellation
                            ? "border-amber-200 bg-amber-50/30"
                            : "border-muted bg-muted/30"
                        )}>
                          <div className="flex items-center justify-between mb-4">
                            <div>
                              <p className="font-medium">Allow Order Cancellation</p>
                              <p className="text-sm text-muted-foreground">Let customers cancel orders within a time limit</p>
                            </div>
                            <Switch
                              checked={orderSettings.allowCancellation}
                              onCheckedChange={(checked) =>
                                setOrderSettings({ ...orderSettings, allowCancellation: checked })
                              }
                              className="data-[state=checked]:bg-amber-500"
                            />
                          </div>
                          <AnimatePresence>
                            {orderSettings.allowCancellation && (
                              <motion.div
                                initial={{ height: 0, opacity: 0 }}
                                animate={{ height: "auto", opacity: 1 }}
                                exit={{ height: 0, opacity: 0 }}
                                className="overflow-hidden"
                              >
                                <Separator className="mb-4" />
                                <div className="space-y-3">
                                  <Label className="text-sm">Maximum Cancellation Window</Label>
                                  <div className="flex items-center gap-3">
                                    <Input
                                      type="number"
                                      min={1}
                                      max={72}
                                      value={orderSettings.maxCancellationHours}
                                      onChange={(e) =>
                                        setOrderSettings({
                                          ...orderSettings,
                                          maxCancellationHours: parseInt(e.target.value) || 24,
                                        })
                                      }
                                      className="w-24"
                                    />
                                    <span className="text-muted-foreground">hours</span>
                                  </div>
                                </div>
                              </motion.div>
                            )}
                          </AnimatePresence>
                        </div>
                      </div>

                      <Separator />

                      {/* Returns */}
                      <div className="space-y-4">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center">
                            <Icon name="arrow-uturn-left" size="sm" className="text-purple-600" />
                          </div>
                          <h4 className="font-semibold">Returns & Refunds</h4>
                        </div>
                        <div className={cn(
                          "p-5 rounded-xl border-2 transition-all duration-300",
                          orderSettings.allowReturns
                            ? "border-purple-200 bg-purple-50/30"
                            : "border-muted bg-muted/30"
                        )}>
                          <div className="flex items-center justify-between mb-4">
                            <div>
                              <p className="font-medium">Allow Returns</p>
                              <p className="text-sm text-muted-foreground">Let customers return items for refund</p>
                            </div>
                            <Switch
                              checked={orderSettings.allowReturns}
                              onCheckedChange={(checked) =>
                                setOrderSettings({ ...orderSettings, allowReturns: checked })
                              }
                              className="data-[state=checked]:bg-purple-500"
                            />
                          </div>
                          <AnimatePresence>
                            {orderSettings.allowReturns && (
                              <motion.div
                                initial={{ height: 0, opacity: 0 }}
                                animate={{ height: "auto", opacity: 1 }}
                                exit={{ height: 0, opacity: 0 }}
                                className="overflow-hidden"
                              >
                                <Separator className="mb-4" />
                                <div className="space-y-3">
                                  <Label className="text-sm">Return Period</Label>
                                  <div className="flex items-center gap-3">
                                    <Input
                                      type="number"
                                      min={1}
                                      max={30}
                                      value={orderSettings.returnPeriodDays}
                                      onChange={(e) =>
                                        setOrderSettings({
                                          ...orderSettings,
                                          returnPeriodDays: parseInt(e.target.value) || 7,
                                        })
                                      }
                                      className="w-24"
                                    />
                                    <span className="text-muted-foreground">days after delivery</span>
                                  </div>
                                </div>
                              </motion.div>
                            )}
                          </AnimatePresence>
                        </div>
                      </div>

                      <div className="flex justify-end gap-3 pt-4">
                        {hasChanges.order && (
                          <Button variant="outline" onClick={() => setOrderSettings(originalOrder)}>
                            <Icon name="arrow-uturn-left" size="sm" className="mr-2" />
                            Reset
                          </Button>
                        )}
                        <Button
                          onClick={handleUpdateOrder}
                          disabled={isSaving === "order" || !hasChanges.order}
                          className="min-w-[120px]"
                        >
                          {isSaving === "order" ? (
                            <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                          ) : (
                            <Icon name="check" size="sm" className="mr-2" />
                          )}
                          Save Changes
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              </motion.div>
            </TabsContent>

            {/* Appearance Tab */}
            <TabsContent value="appearance" className="mt-6">
              <motion.div variants={containerVariants} initial="hidden" animate="visible" className="max-w-2xl space-y-6">
                <motion.div variants={itemVariants}>
                  <Card className="border-none shadow-lg">
                    <CardHeader>
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-pink-500 to-pink-600 flex items-center justify-center shadow-md">
                          <Icon name="swatch" className="text-white" />
                        </div>
                        <div>
                          <CardTitle className="text-xl">Shop Appearance</CardTitle>
                          <CardDescription>Customize your store's visual identity</CardDescription>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-8">
                      <div className="space-y-3">
                        <Label className="text-base font-medium flex items-center gap-2">
                          <Icon name="megaphone" size="sm" />
                          Shop Announcement
                        </Label>
                        <textarea
                          className="w-full min-h-[100px] p-4 rounded-xl border-2 bg-background resize-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                          placeholder="e.g., 🎉 Free shipping on orders over ₱1,000! Limited time offer..."
                          value={customization.announcement || ""}
                          onChange={(e) => setCustomization({ ...customization, announcement: e.target.value })}
                        />
                        <p className="text-xs text-muted-foreground">
                          This announcement will be displayed at the top of your shop page
                        </p>
                      </div>

                      <Separator />

                      <div className="space-y-4">
                        <Label className="text-base font-medium flex items-center gap-2">
                          <Icon name="paint-brush" size="sm" />
                          Brand Color
                        </Label>
                        <div className="flex flex-wrap gap-3">
                          {colorOptions.map((color) => (
                            <Tooltip key={color.value}>
                              <TooltipTrigger asChild>
                                <button
                                  onClick={() => setCustomization({ ...customization, primaryColor: color.value })}
                                  className={cn(
                                    "w-10 h-10 rounded-xl transition-all duration-200",
                                    color.class,
                                    customization.primaryColor === color.value
                                      ? "ring-4 ring-offset-2 ring-primary scale-110"
                                      : "hover:scale-105"
                                  )}
                                />
                              </TooltipTrigger>
                              <TooltipContent>{color.name}</TooltipContent>
                            </Tooltip>
                          ))}
                        </div>
                        <div className="flex items-center gap-3">
                          <input
                            type="color"
                            value={customization.primaryColor}
                            onChange={(e) => setCustomization({ ...customization, primaryColor: e.target.value })}
                            className="w-12 h-12 rounded-lg cursor-pointer border-2"
                          />
                          <Input
                            value={customization.primaryColor}
                            onChange={(e) => setCustomization({ ...customization, primaryColor: e.target.value })}
                            className="w-32 font-mono"
                          />
                        </div>
                      </div>

                      <Separator />

                      <div className="space-y-4">
                        <Label className="text-base font-medium flex items-center gap-2">
                          <Icon name="sun" size="sm" />
                          Theme Mode
                        </Label>
                        <div className="grid grid-cols-2 gap-4">
                          <button
                            onClick={() => setCustomization({ ...customization, themeMode: "light" })}
                            className={cn(
                              "flex flex-col items-center gap-3 p-5 rounded-xl border-2 transition-all duration-300",
                              customization.themeMode === "light"
                                ? "border-primary bg-primary/5"
                                : "border-muted bg-muted/30 hover:border-muted-foreground/30"
                            )}
                          >
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-amber-100 to-amber-50 flex items-center justify-center">
                              <Icon name="sun" className="text-amber-500" />
                            </div>
                            <span className={cn("font-medium", customization.themeMode === "light" && "text-primary")}>Light Mode</span>
                          </button>
                          <button
                            onClick={() => setCustomization({ ...customization, themeMode: "dark" })}
                            className={cn(
                              "flex flex-col items-center gap-3 p-5 rounded-xl border-2 transition-all duration-300",
                              customization.themeMode === "dark"
                                ? "border-primary bg-primary/5"
                                : "border-muted bg-muted/30 hover:border-muted-foreground/30"
                            )}
                          >
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-slate-700 to-slate-800 flex items-center justify-center">
                              <Icon name="moon" className="text-slate-300" />
                            </div>
                            <span className={cn("font-medium", customization.themeMode === "dark" && "text-primary")}>Dark Mode</span>
                          </button>
                        </div>
                      </div>

                      <div className="flex justify-end gap-3 pt-4">
                        {hasChanges.appearance && (
                          <Button variant="outline" onClick={() => setCustomization(originalCustomization)}>
                            <Icon name="arrow-uturn-left" size="sm" className="mr-2" />
                            Reset
                          </Button>
                        )}
                        <Button
                          onClick={handleUpdateCustomization}
                          disabled={isSaving === "customization" || !hasChanges.appearance}
                          className="min-w-[120px]"
                        >
                          {isSaving === "customization" ? (
                            <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                          ) : (
                            <Icon name="check" size="sm" className="mr-2" />
                          )}
                          Save Changes
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              </motion.div>
            </TabsContent>

            {/* Chat Tab */}
            <TabsContent value="chat" className="mt-6">
              <motion.div variants={containerVariants} initial="hidden" animate="visible" className="max-w-2xl">
                <motion.div variants={itemVariants}>
                  <Card className="border-none shadow-lg">
                    <CardHeader>
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-indigo-500 to-indigo-600 flex items-center justify-center shadow-md">
                          <Icon name="chat-bubble-left-right" className="text-white" />
                        </div>
                        <div>
                          <CardTitle className="text-xl">Auto-Reply Chat</CardTitle>
                          <CardDescription>Set up automatic responses to customer messages</CardDescription>
                        </div>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-6">
                      <div className={cn(
                        "p-5 rounded-xl border-2 transition-all duration-300",
                        chatSettings.autoReplyEnabled
                          ? "border-indigo-200 bg-indigo-50/30"
                          : "border-muted bg-muted/30"
                      )}>
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div className={cn(
                              "w-10 h-10 rounded-lg flex items-center justify-center transition-colors",
                              chatSettings.autoReplyEnabled ? "bg-indigo-500" : "bg-muted"
                            )}>
                              <Icon name="bolt" size="sm" className={chatSettings.autoReplyEnabled ? "text-white" : "text-muted-foreground"} />
                            </div>
                            <div>
                              <p className="font-medium">Enable Auto-Reply</p>
                              <p className="text-sm text-muted-foreground">Automatically respond to new customer messages</p>
                            </div>
                          </div>
                          <Switch
                            checked={chatSettings.autoReplyEnabled}
                            onCheckedChange={(checked) =>
                              setChatSettings({ ...chatSettings, autoReplyEnabled: checked })
                            }
                            className="data-[state=checked]:bg-indigo-500"
                          />
                        </div>
                      </div>

                      <AnimatePresence>
                        {chatSettings.autoReplyEnabled && (
                          <motion.div
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: "auto", opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            className="overflow-hidden space-y-4"
                          >
                            <div className="space-y-3">
                              <Label className="flex items-center gap-2">
                                <Icon name="document-text" size="sm" />
                                Auto-Reply Message
                              </Label>
                              <textarea
                                className="w-full min-h-[140px] p-4 rounded-xl border-2 bg-background resize-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all"
                                value={chatSettings.autoReplyMessage}
                                onChange={(e) =>
                                  setChatSettings({ ...chatSettings, autoReplyMessage: e.target.value })
                                }
                                placeholder="Enter your auto-reply message..."
                              />
                              <p className="text-xs text-muted-foreground">
                                This message will be sent automatically when a customer starts a chat
                              </p>
                            </div>
                          </motion.div>
                        )}
                      </AnimatePresence>

                      <div className="flex justify-end gap-3 pt-4">
                        {hasChanges.chat && (
                          <Button variant="outline" onClick={() => setChatSettings(originalChat)}>
                            <Icon name="arrow-uturn-left" size="sm" className="mr-2" />
                            Reset
                          </Button>
                        )}
                        <Button
                          onClick={handleUpdateChat}
                          disabled={isSaving === "chat" || !hasChanges.chat}
                          className="min-w-[120px]"
                        >
                          {isSaving === "chat" ? (
                            <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                          ) : (
                            <Icon name="check" size="sm" className="mr-2" />
                          )}
                          Save Changes
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                </motion.div>
              </motion.div>
            </TabsContent>
          </AnimatePresence>
        </Tabs>

        {/* Add Shipping Dialog */}
        <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Icon name="plus-circle" />
                Add Shipping Location
              </DialogTitle>
              <DialogDescription>Add a new shipping location (fee will be calculated automatically based on region)</DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="flex items-center justify-between">
                <div className="text-sm text-muted-foreground">
                  Choose location method
                </div>
                <div className="flex gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={handleUseGeolocation}
                    disabled={isLoading}
                    className="flex items-center gap-2"
                  >
                    <Icon name="location-crosshairs" size="sm" />
                    {isLoading ? "Detecting..." : "Use My Location"}
                  </Button>
                  {shippingSettings.length > 0 && (
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => setIsCopyDialogOpen(true)}
                      className="flex items-center gap-2"
                    >
                      <Icon name="copy" size="sm" />
                      Copy Existing
                    </Button>
                  )}
                </div>
              </div>
              
              <Tabs defaultValue="dropdown" className="w-full">
                <TabsList className="grid w-full grid-cols-2">
                  <TabsTrigger value="dropdown">Select from List</TabsTrigger>
                  <TabsTrigger value="manual">Manual Entry</TabsTrigger>
                </TabsList>
                
                <TabsContent value="dropdown" className="space-y-4">
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-2">
                      <Label>Region</Label>
                      <Select value={selectedRegion} onValueChange={handleRegionChange}>
                        <SelectTrigger>
                          <SelectValue placeholder="Select region" />
                        </SelectTrigger>
                        <SelectContent>
                          {regions.map((region) => (
                            <SelectItem key={region} value={region}>
                              {region}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label>Province</Label>
                      <Select value={selectedProvince} onValueChange={handleProvinceChange} disabled={!selectedRegion}>
                        <SelectTrigger>
                          <SelectValue placeholder="Select province" />
                        </SelectTrigger>
                        <SelectContent>
                          {provinces.map((province) => (
                            <SelectItem key={province} value={province}>
                              {province}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label>City</Label>
                      <Select value={selectedCity} onValueChange={handleCityChange} disabled={!selectedProvince}>
                        <SelectTrigger>
                          <SelectValue placeholder="Select city" />
                        </SelectTrigger>
                        <SelectContent>
                          {cities.map((city) => (
                            <SelectItem key={city} value={city}>
                              {city}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                </TabsContent>
                
                <TabsContent value="manual" className="space-y-4">
                  <div className="grid grid-cols-3 gap-4">
                    <div className="space-y-2">
                      <Label>Region</Label>
                      <Input
                        placeholder="e.g., NCR"
                        value={newShipping.regionName}
                        onChange={(e) => setNewShipping({ ...newShipping, regionName: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Province</Label>
                      <Input
                        placeholder="e.g., Manila"
                        value={newShipping.provinceName}
                        onChange={(e) => setNewShipping({ ...newShipping, provinceName: e.target.value })}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>City</Label>
                      <Input
                        placeholder="e.g., Quezon City"
                        value={newShipping.cityName}
                        onChange={(e) => setNewShipping({ ...newShipping, cityName: e.target.value })}
                      />
                    </div>
                  </div>
                </TabsContent>
              </Tabs>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>Cancel</Button>
              <Button onClick={handleAddShipping} disabled={isSaving === "shipping-add"}>
                {isSaving === "shipping-add" ? (
                  <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                ) : (
                  <Icon name="plus" size="sm" className="mr-2" />
                )}
                Add Location
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Edit Shipping Dialog */}
        <Dialog open={!!editingShipping} onOpenChange={() => setEditingShipping(null)}>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Icon name="pencil-square" />
                Edit Shipping Location
              </DialogTitle>
              <DialogDescription>Update location details (shipping fee is calculated automatically)</DialogDescription>
            </DialogHeader>
            {editingShipping && (
              <div className="space-y-4 py-4">
                <div className="flex items-center justify-between">
                  <div className="text-sm text-muted-foreground">
                    Enter location details manually or use geolocation
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => handleUseGeolocationForEdit()}
                    disabled={isLoading}
                    className="flex items-center gap-2"
                  >
                    <Icon name="location-crosshairs" size="sm" />
                    {isLoading ? "Detecting..." : "Use My Location"}
                  </Button>
                </div>
                <div className="grid grid-cols-3 gap-4">
                  <div className="space-y-2">
                    <Label>Region</Label>
                    <Input
                      value={editingShipping.regionName}
                      onChange={(e) => setEditingShipping({ ...editingShipping, regionName: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>Province</Label>
                    <Input
                      value={editingShipping.provinceName}
                      onChange={(e) => setEditingShipping({ ...editingShipping, provinceName: e.target.value })}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>City</Label>
                    <Input
                      value={editingShipping.cityName}
                      onChange={(e) => setEditingShipping({ ...editingShipping, cityName: e.target.value })}
                    />
                  </div>
                </div>
                <div className="flex items-center gap-3 p-3 bg-muted/50 rounded-lg">
                  <Switch
                    checked={editingShipping.isActive}
                    onCheckedChange={(checked) => setEditingShipping({ ...editingShipping, isActive: checked })}
                  />
                  <Label className="cursor-pointer">Location Active</Label>
                </div>
              </div>
            )}
            <DialogFooter>
              <Button variant="outline" onClick={() => setEditingShipping(null)}>Cancel</Button>
              <Button onClick={handleUpdateShipping} disabled={!!isSaving && isSaving.startsWith("shipping-")}>
                {!!isSaving && isSaving.startsWith("shipping-") ? (
                  <Icon name="arrow-path" className="animate-spin mr-2" size="sm" />
                ) : (
                  <Icon name="check" size="sm" className="mr-2" />
                )}
                Save Changes
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Copy Existing Location Dialog */}
        <Dialog open={isCopyDialogOpen} onOpenChange={setIsCopyDialogOpen}>
          <DialogContent className="sm:max-w-lg">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <Icon name="copy" />
                Copy Existing Location
              </DialogTitle>
              <DialogDescription>Select an existing shipping location to copy</DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4 max-h-96 overflow-y-auto">
              {shippingSettings.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  No existing locations found
                </div>
              ) : (
                shippingSettings.map((setting) => (
                  <div
                    key={setting.id}
                    className="flex items-center justify-between p-3 border rounded-lg hover:bg-muted/50 cursor-pointer transition-colors"
                    onClick={() => handleCopyExistingLocation(setting)}
                  >
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center">
                        <Icon name="map-pin" size="sm" className="text-blue-600" />
                      </div>
                      <div>
                        <div className="font-medium">{setting.cityName}</div>
                        <div className="text-sm text-muted-foreground">
                          {setting.provinceName}, {setting.regionName}
                        </div>
                      </div>
                    </div>
                    <div className="text-right">
                      <Badge variant="secondary" className="font-semibold text-primary">
                        ₱{setting.shippingFee.toFixed(2)}
                      </Badge>
                    </div>
                  </div>
                ))
              )}
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setIsCopyDialogOpen(false)}>
                Cancel
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </TooltipProvider>
  )
}
