"use client"

import { useEffect, useState } from "react"
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet"
import L from "leaflet"
import "leaflet/dist/leaflet.css"
import { storesApi, type StoreWithCoords } from "@/lib/api"
import { Icon } from "@/components/ui/icon"
import Link from "next/link"

const storeIcon = new L.DivIcon({
  className: "",
  html: `<div style="width:28px;height:28px;background:#c97a8c;border:3px solid white;border-radius:50%;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 6px rgba(0,0,0,0.3);color:white;font-size:14px;font-weight:bold;">S</div>`,
  iconSize: [28, 28],
  iconAnchor: [14, 14],
})

const userIcon = new L.DivIcon({
  className: "",
  html: `<div style="width:16px;height:16px;background:#2e2e2e;border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
  iconSize: [16, 16],
  iconAnchor: [8, 8],
})

function RecenterMap({ center }: { center: [number, number] }) {
  const map = useMap()
  useEffect(() => {
    map.setView(center, map.getZoom())
  }, [map, center])
  return null
}

export function StoreLocatorMap() {
  const [stores, setStores] = useState<StoreWithCoords[]>([])
  const [loading, setLoading] = useState(true)
  const [userPos, setUserPos] = useState<[number, number] | null>(null)
  const [searchQuery, setSearchQuery] = useState("")

  useEffect(() => {
    const load = async () => {
      try {
        const res = await storesApi.withCoordinates()
        setStores(res.data.stores ?? [])
      } catch {
        setStores([])
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const handleLocateMe = () => {
    if (!navigator.geolocation) return
    navigator.geolocation.getCurrentPosition(
      (pos) => setUserPos([pos.coords.latitude, pos.coords.longitude]),
      () => {},
    )
  }

  const filtered = searchQuery.trim()
    ? stores.filter(
        (s) =>
          s.storeName.toLowerCase().includes(searchQuery.toLowerCase()) ||
          (s.address && s.address.toLowerCase().includes(searchQuery.toLowerCase())),
      )
    : stores

  const center: [number, number] = userPos || (filtered.length > 0
    ? [filtered[0].latitude, filtered[0].longitude]
    : [14.5995, 120.9842])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 bg-muted/30 rounded-xl border text-sm text-muted-foreground">
        Loading stores…
      </div>
    )
  }

  if (stores.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 bg-muted/30 rounded-xl border text-sm text-muted-foreground">
        <div className="text-center">
          <Icon name="store" className="mx-auto mb-2 text-muted-foreground/50" size="lg" />
          <p>No stores with location data yet</p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <input
          type="text"
          placeholder="Search stores or area…"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="flex-1 px-4 py-2 border rounded-xl text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary/30"
        />
        <button
          type="button"
          onClick={handleLocateMe}
          className="px-3 py-2 border rounded-xl text-sm hover:bg-muted flex items-center gap-1.5 shrink-0"
        >
          <Icon name="crosshair" size="sm" />
          Near me
        </button>
      </div>
      <div className="relative rounded-xl overflow-hidden border">
        <MapContainer
          center={center}
          zoom={12}
          className="h-80 w-full"
          zoomControl={true}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <RecenterMap center={center} />
          {filtered.map((store) => (
            <Marker
              key={store.id}
              position={[store.latitude, store.longitude]}
              icon={storeIcon}
            >
              <Popup>
                <div className="text-sm min-w-[160px]">
                  <Link
                    href={`/store/${store.id}`}
                    className="font-semibold text-primary hover:underline block mb-1"
                  >
                    {store.storeName}
                  </Link>
                  {store.tagline && (
                    <p className="text-xs text-muted-foreground mb-1">{store.tagline}</p>
                  )}
                  {store.address && (
                    <p className="text-xs text-muted-foreground">{store.address}</p>
                  )}
                  <Link
                    href={`/store/${store.id}`}
                    className="text-xs text-primary font-medium hover:underline mt-1 inline-block"
                  >
                    Visit store →
                  </Link>
                </div>
              </Popup>
            </Marker>
          ))}
          {userPos && (
            <Marker position={userPos} icon={userIcon}>
              <Popup>You are here</Popup>
            </Marker>
          )}
        </MapContainer>
      </div>
      <div className="text-xs text-muted-foreground text-center">
        Showing {filtered.length} of {stores.length} stores
      </div>
    </div>
  )
}
