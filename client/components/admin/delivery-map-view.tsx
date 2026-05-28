"use client"

import { useState } from "react"
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from "react-leaflet"
import L from "leaflet"
import "leaflet/dist/leaflet.css"
import type { ActiveDeliveryDto } from "@/lib/api"
import Link from "next/link"

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
  html: `<div style="width:16px;height:16px;background:#c97a8c;border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
  iconSize: [16, 16],
  iconAnchor: [8, 8],
})

interface DeliveryMapViewProps {
  deliveries: ActiveDeliveryDto[]
}

function FitBounds({ positions }: { positions: [number, number][] }) {
  const map = useMap()
  if (positions.length === 0) {
    map.setView([14.5995, 120.9842], 12)
    return null
  }
  if (positions.length === 1) {
    map.setView(positions[0], 14)
    return null
  }
  const bounds = L.latLngBounds(positions.map((p) => L.latLng(p[0], p[1])))
  map.fitBounds(bounds, { padding: [40, 40], maxZoom: 16 })
  return null
}

export function DeliveryMapView({ deliveries }: DeliveryMapViewProps) {
  const allPositions: [number, number][] = []
  deliveries.forEach((d) => {
    if (d.riderLocation) {
      allPositions.push([d.riderLocation.latitude, d.riderLocation.longitude])
    }
    if (d.destination) {
      allPositions.push([d.destination.latitude, d.destination.longitude])
    }
  })

  const statusBadgeColor = (status: string) => {
    switch (status) {
      case "transit": return "text-purple-600"
      case "pickup": return "text-blue-600"
      default: return "text-amber-600"
    }
  }

  return (
    <div className="rounded-xl overflow-hidden border">
      <MapContainer
        center={[14.5995, 120.9842]}
        zoom={11}
        className="h-96 w-full"
        zoomControl={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBounds positions={allPositions} />
        {deliveries.map((d) => {
          if (!d.riderLocation || !d.destination) return null
          const riderPos: [number, number] = [d.riderLocation.latitude, d.riderLocation.longitude]
          const destPos: [number, number] = [d.destination.latitude, d.destination.longitude]
          return (
            <span key={d.deliveryId}>
              <Polyline
                positions={[riderPos, destPos]}
                pathOptions={{
                  color: "#c97a8c",
                  weight: 2,
                  opacity: 0.4,
                  dashArray: "6 4",
                }}
              />
              <Marker position={riderPos} icon={riderIcon}>
                <Popup>
                  <div className="text-sm min-w-[140px]">
                    <p className="font-semibold">{d.rider?.name ?? "Rider"}</p>
                    <p className={`text-xs font-medium mt-0.5 capitalize ${statusBadgeColor(d.status)}`}>
                      {d.status}
                    </p>
                    <p className="text-xs text-muted-foreground mt-1">Order #{d.orderId}</p>
                    {d.distanceKm > 0 && (
                      <p className="text-xs text-muted-foreground">{d.distanceKm.toFixed(1)} km</p>
                    )}
                    <Link
                      href={`/admin/orders`}
                      className="text-xs text-primary font-medium hover:underline mt-1 inline-block"
                    >
                      View details →
                    </Link>
                  </div>
                </Popup>
              </Marker>
              <Marker position={destPos} icon={destIcon}>
                <Popup>
                  <div className="text-sm">
                    <p className="font-medium">{d.buyer?.name ?? "Buyer"}</p>
                    <p className="text-xs text-muted-foreground">Delivery destination</p>
                  </div>
                </Popup>
              </Marker>
            </span>
          )
        })}
      </MapContainer>
    </div>
  )
}
