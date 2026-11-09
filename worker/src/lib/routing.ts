import type { Client } from "pg";
import type { Bindings } from "../env";
import { mapSettings, recordGoogleFailure } from "./maps";

export type LatLng = { lat: number; lng: number };
export type Route = { distance_km: number; duration_minutes: number; source: "google" | "osrm" | "estimate" };

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

async function googleRoute(env: Bindings, a: LatLng, b: LatLng): Promise<Route | null> {
  const key = env.GOOGLE_MAPS_SERVER_KEY;
  if (!key) return null;
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
    if (!res.ok) return null;
    const r = ((await res.json()) as { routes?: { distanceMeters?: number; duration?: string }[] }).routes?.[0];
    const seconds = Number(String(r?.duration ?? "").replace("s", ""));
    if (!r?.distanceMeters || !Number.isFinite(seconds)) return null;
    return { distance_km: Math.round(r.distanceMeters) / 1000, duration_minutes: Math.max(1, Math.round(seconds / 60)), source: "google" };
  } catch {
    return null;
  }
}

/** OpenStreetMap road routing (OSRM). The public demo server is for light use; the admin can point to another one. */
async function osrmRoute(baseUrl: string, a: LatLng, b: LatLng): Promise<Route | null> {
  try {
    const url = `${baseUrl.replace(/\/+$/, "")}/route/v1/driving/${a.lng},${a.lat};${b.lng},${b.lat}?overview=false`;
    const res = await fetch(url, { headers: { "User-Agent": "DROP-ride-hailing/1.0 (officialkryptonia.workers.dev)" }, signal: AbortSignal.timeout(4000) });
    if (!res.ok) return null;
    const r = ((await res.json()) as { routes?: { distance?: number; duration?: number }[] }).routes?.[0];
    if (!r?.distance || !Number.isFinite(r.duration)) return null;
    return { distance_km: Math.round(r.distance) / 1000, duration_minutes: Math.max(1, Math.round((r.duration as number) / 60)), source: "osrm" };
  } catch {
    return null;
  }
}

/**
 * Road distance and time from the chosen service, then the other one, then a straight-line estimate,
 * so a fare can always be quoted even when a map service is down.
 */
export async function routeBetween(env: Bindings, a: LatLng, b: LatLng, db?: Client): Promise<Route> {
  const s = db ? await mapSettings(db, env) : null;
  const googleFirst = s ? s.active === "google" : true;
  const osrmUrl = s?.osm_routing_url ?? "https://router.project-osrm.org";
  const tryGoogle = async () => {
    const r = await googleRoute(env, a, b);
    if (!r && env.GOOGLE_MAPS_SERVER_KEY && db) await recordGoogleFailure(db);
    return r;
  };
  const tryOsrm = () => osrmRoute(osrmUrl, a, b);
  const first = googleFirst ? await tryGoogle() : await tryOsrm();
  if (first) return first;
  const second = googleFirst ? await tryOsrm() : await tryGoogle();
  return second ?? estimateRoute(a, b);
}
