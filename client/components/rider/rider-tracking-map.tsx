"use client"

import { useEffect, useState, useRef, useCallback } from "react"
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from "react-leaflet"
import L from "leaflet"
import "leaflet/dist/leaflet.css"
import { riderTrackingSocket, type RiderLocationUpdate } from "@/lib/rider/rider-tracking-socket"
import { Icon } from "@/components/ui/icon"

// Fix default marker icon path issue with bundlers
const riderIcon = new L.Icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

const destIcon = new L.DivIcon({
  className: "",
  html: `<div style="width:20px;height:20px;background:#c97a8c;border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
})

interface RiderTrackingMapProps {
  orderId: number
  riderName?: string | null
  riderLatitude?: number | null
  riderLongitude?: number | null
  destLatitude?: number | null
  destLongitude?: number | null
  history?: { latitude: number; longitude: number }[]
  available?: boolean
}

function MapBoundsUpdater({ positions }: { positions: [number, number][] }) {
  const map = useMap()
  useEffect(() => {
    if (positions.length === 0) return
    if (positions.length === 1) {
      map.setView(positions[0], 15)
      return
    }
    const bounds = L.latLngBounds(positions.map((p) => L.latLng(p[0], p[1])))
    map.fitBounds(bounds, { padding: [50, 50], maxZoom: 17 })
  }, [map, positions])
  return null
}

export function RiderTrackingMap({
  orderId,
  riderName,
  riderLatitude,
  riderLongitude,
  destLatitude,
  destLongitude,
  history,
  available,
}: RiderTrackingMapProps) {
  const [livePos, setLivePos] = useState<{ lat: number; lng: number } | null>(
    riderLatitude != null && riderLongitude != null
      ? { lat: riderLatitude, lng: riderLongitude }
      : null,
  )
  const [pathHistory, setPathHistory] = useState<[number, number][]>([])
  const [socketConnected, setSocketConnected] = useState(false)
  const tokenRef = useRef<string | null>(null)

  useEffect(() => {
    if (typeof window === "undefined") return
    tokenRef.current = localStorage.getItem("yamada-access-token")
  }, [])

  const handleLocationUpdate = useCallback((data: RiderLocationUpdate) => {
    if (data.orderId !== orderId) return
    setLivePos({ lat: data.latitude, lng: data.longitude })
    setPathHistory((prev) => {
      const next: [number, number][] = [...prev, [data.latitude, data.longitude]]
      return next.slice(-100)
    })
  }, [orderId])

  useEffect(() => {
    if (!tokenRef.current || !available) return
    riderTrackingSocket.connect(tokenRef.current, handleLocationUpdate)
    riderTrackingSocket.subscribeOrder(orderId)
    setSocketConnected(true)

    return () => {
      // Don't disconnect on unmount — component might be inside a tab
    }
  }, [orderId, available, handleLocationUpdate])

  // Seed path history from props
  useEffect(() => {
    if (history && history.length > 0) {
      setPathHistory(history.map((p) => [p.latitude, p.longitude] as [number, number]))
    }
  }, [history])

  const riderPos: [number, number] | null = livePos
    ? [livePos.lat, livePos.lng]
    : riderLatitude != null && riderLongitude != null
      ? [riderLatitude, riderLongitude]
      : null

  const destPos: [number, number] | null =
    destLatitude != null && destLongitude != null
      ? [destLatitude, destLongitude]
      : null

  const allPositions: [number, number][] = [
    ...(riderPos ? [riderPos] : []),
    ...(destPos ? [destPos] : []),
  ]

  if (!available) {
    return (
      <div className="flex items-center justify-center h-48 bg-muted/30 rounded-xl border text-sm text-muted-foreground">
        <div className="text-center">
          <Icon name="map-pin" className="mx-auto mb-2 text-muted-foreground/50" size="lg" />
          <p>Rider location not available yet</p>
        </div>
      </div>
    )
  }

  return (
    <div className="relative rounded-xl overflow-hidden border">
      <MapContainer
        center={riderPos || destPos || [14.5995, 120.9842]}
        zoom={13}
        className="h-64 w-full"
        zoomControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <MapBoundsUpdater positions={allPositions} />
        {pathHistory.length > 1 && (
          <Polyline positions={pathHistory} pathOptions={{ color: "#c97a8c", weight: 3, opacity: 0.6 }} />
        )}
        {riderPos && (
          <Marker position={riderPos} icon={riderIcon}>
            <Popup>
              <div className="text-sm font-medium">
                {riderName || "Rider"}
                {socketConnected && (
                  <span className="ml-2 text-xs text-green-600">● Live</span>
                )}
              </div>
            </Popup>
          </Marker>
        )}
        {destPos && (
          <Marker position={destPos} icon={destIcon}>
            <Popup>
              <div className="text-sm font-medium">Delivery destination</div>
            </Popup>
          </Marker>
        )}
      </MapContainer>
    </div>
  )
}
