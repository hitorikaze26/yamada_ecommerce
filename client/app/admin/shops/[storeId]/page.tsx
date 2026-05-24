"use client"

import Link from "next/link"
import { useEffect, useState } from "react"
import { useParams } from "next/navigation"
import { Icon } from "@/components/ui/icon"
import { adminApi } from "@/lib/api"
import { CATEGORIES } from "@/lib/types"

interface StoreDetail {
  id: number
  name: string
  email: string
  description: string
  country: string
  address: string
  phone: string
  user?: {
    id: number
    email: string
    givenName?: string
    surname?: string
  } | null
  seller?: {
    id: number
    fullName?: string
    country?: string
    province?: string
    city?: string
  } | null
  registration?: {
    id?: number
    purpose?: string
    tagline?: string
    categories?: string[]
    requestedAt?: string
    documents?: {
      dti?: string | null
      birTin?: string | null
      businessPermit?: string | null
    } | null
  } | null
}

export default function AdminStoreDetailPage() {
  const params = useParams<{ storeId: string }>()
  const storeId = Number(params.storeId)

  const [store, setStore] = useState<StoreDetail | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const resolveCategories = (ids: string[] | undefined): string => {
    if (!ids || ids.length === 0) return "-"
    const byId = new Map<string, string>(CATEGORIES.map((c) => [c.id, c.name]))
    return ids.map((id) => byId.get(id) ?? id).join(", ")
  }

  useEffect(() => {
    if (!storeId) return

    const fetchStore = async () => {
      try {
        setIsLoading(true)
        setError(null)
        const res = await adminApi.getStoreDetail(storeId)
        setStore(res.data.store)
      } catch (err: any) {
        const msg = err?.response?.data?.msg || "Failed to load store details."
        setError(msg)
      } finally {
        setIsLoading(false)
      }
    }

    void fetchStore()
  }, [storeId])

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <button onClick={() => history.back()} className="p-2 rounded-full hover:bg-muted">
          <Icon name="arrow-left" />
        </button>
        <div>
          <h1 className="text-3xl font-bold mb-1">Store Details</h1>
          <p className="text-muted-foreground text-sm">View full store and seller information.</p>
        </div>
      </div>

      {isLoading && <div className="bg-card border rounded-2xl p-4">Loading store...</div>}

      {error && !isLoading && (
        <div className="bg-destructive/10 text-destructive border border-destructive/30 rounded-2xl p-4 text-sm">
          {error}
        </div>
      )}

      {!isLoading && !error && store && (
        <div className="space-y-6">
          <div className="bg-card border rounded-2xl p-6 flex flex-col md:flex-row gap-6">
            <div className="w-16 h-16 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
              <Icon name="store" className="text-primary" />
            </div>
            <div className="space-y-1 flex-1">
              <h2 className="text-2xl font-semibold">{store.name}</h2>
              <p className="text-sm text-muted-foreground">ID: {store.id}</p>
              <p className="text-sm text-muted-foreground">Email: {store.email}</p>
              <p className="text-sm text-muted-foreground">Phone: {store.phone}</p>
              {store.registration?.id && (
                <p className="text-xs text-muted-foreground mt-2">
                  Registration ID: {store.registration.id} ·{" "}
                  <Link
                    href={`/admin/shops?registrationId=${store.registration.id}`}
                    className="underline hover:text-primary"
                  >
                    Open registration
                  </Link>
                </p>
              )}
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <div className="bg-card border rounded-2xl p-6 space-y-2 text-sm">
              <h3 className="text-lg font-semibold mb-2">Store Info</h3>
              <p>
                <span className="font-medium">Description:</span> {store.description}
              </p>
              <p>
                <span className="font-medium">Country:</span> {store.country}
              </p>
              <p>
                <span className="font-medium">Address:</span> {store.address}
              </p>
              {store.registration && (
                <div className="mt-4 space-y-1">
                  <p className="font-semibold text-xs text-muted-foreground">Registration</p>
                  <p>
                    <span className="font-medium">Purpose:</span> {store.registration.purpose}
                  </p>
                  <p>
                    <span className="font-medium">Tagline:</span> {store.registration.tagline}
                  </p>
                  <p>
                    <span className="font-medium">Categories:</span>{" "}
                    {resolveCategories(store.registration.categories)}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Requested at: {store.registration.requestedAt ?? "-"}
                  </p>
                </div>
              )}
            </div>

            <div className="bg-card border rounded-2xl p-6 space-y-2 text-sm">
              <h3 className="text-lg font-semibold mb-2">Seller Info</h3>
              <p>
                <span className="font-medium">Seller:</span> {store.seller?.fullName ?? "-"}
              </p>
              <p>
                <span className="font-medium">Location:</span> {store.seller?.city}, {store.seller?.province}, {store.seller?.country}
              </p>
              <p>
                <span className="font-medium">User:</span> {store.user?.givenName} {store.user?.surname} ({store.user?.email})
              </p>
              {store.registration?.documents && (
                <div className="mt-4 space-y-1">
                  <p className="font-semibold text-xs text-muted-foreground">Documents</p>
                  <ul className="text-xs space-y-0.5 text-muted-foreground">
                    <li>
                      DTI: {store.registration.documents.dti ? (
                        <a
                          href={store.registration.documents.dti}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="underline"
                        >
                          View
                        </a>
                      ) : (
                        "-"
                      )}
                    </li>
                    <li>
                      BIR TIN: {store.registration.documents.birTin ? (
                        <a
                          href={store.registration.documents.birTin}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="underline"
                        >
                          View
                        </a>
                      ) : (
                        "-"
                      )}
                    </li>
                    <li>
                      Business Permit: {store.registration.documents.businessPermit ? (
                        <a
                          href={store.registration.documents.businessPermit}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="underline"
                        >
                          View
                        </a>
                      ) : (
                        "-"
                      )}
                    </li>
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
