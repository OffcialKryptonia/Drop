import type { Bindings } from "../env";

export type LatLng = { lat: number; lng: number };
export type Route = { distance_km: number; duration_minutes: number; source: "google" | "estimate" };

export const MILE_PER_KM = 0.621371;

export function haversineKm(a: LatLng, b: LatLng): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Straight line stretched for roads, at city speed. Used when Google is not set up or does not answer. */
export function estimateRoute(a: LatLng, b: LatLng): Route {
  const km = haversineKm(a, b) * 1.3;
  return { distance_km: Math.round(km * 1000) / 1000, duration_minutes: Math.max(1, Math.round((km / 30) * 60)), source: "estimate" };
}

/** Road distance and time from Google when GOOGLE_MAPS_SERVER_KEY is set; otherwise (or on any failure) the estimate. */
export async function routeBetween(env: Bindings, a: LatLng, b: LatLng): Promise<Route> {
  const key = env.GOOGLE_MAPS_SERVER_KEY;
  if (!key) return estimateRoute(a, b);
  try {
    const res = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": key, "X-Goog-FieldMask": "routes.distanceMeters,routes.duration" },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: a.lat, longitude: a.lng } } },
        destination: { location: { latLng: { latitude: b.lat, longitude: b.lng } } },
        travelMode: "DRIVE",
      }),
      signal: AbortSignal.timeout(4000),
    });
    if (!res.ok) return estimateRoute(a, b);
    const r = ((await res.json()) as { routes?: { distanceMeters?: number; duration?: string }[] }).routes?.[0];
    const seconds = Number(String(r?.duration ?? "").replace("s", ""));
    if (!r?.distanceMeters || !Number.isFinite(seconds)) return estimateRoute(a, b);
    return { distance_km: Math.round(r.distanceMeters) / 1000, duration_minutes: Math.max(1, Math.round(seconds / 60)), source: "google" };
  } catch {
    return estimateRoute(a, b);
  }
}
