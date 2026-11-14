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

/** Decodes a Google/OSRM encoded polyline (precision 5) into [lat, lng] pairs. */
export function decodePolyline(encoded: string): [number, number][] {
  const out: [number, number][] = [];
  let i = 0, lat = 0, lng = 0;
  while (i < encoded.length) {
    for (const axis of [0, 1]) {
      let shift = 0, result = 0, b: number;
      do {
        b = encoded.charCodeAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && i < encoded.length);
      const delta = result & 1 ? ~(result >> 1) : result >> 1;
      if (axis === 0) lat += delta; else lng += delta;
    }
    out.push([lat / 1e5, lng / 1e5]);
  }
  return out;
}

/** Thins a long line to at most `max` points so the phone draws it quickly. */
function thin(points: [number, number][], max = 300): [number, number][] {
  if (points.length <= max) return points;
  const step = (points.length - 1) / (max - 1);
  return Array.from({ length: max }, (_, k) => points[Math.round(k * step)]);
}

async function googleLine(env: Bindings, a: LatLng, b: LatLng): Promise<[number, number][] | null> {
  const key = env.GOOGLE_MAPS_SERVER_KEY;
  if (!key) return null;
  try {
    const res = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Goog-Api-Key": key, "X-Goog-FieldMask": "routes.polyline.encodedPolyline" },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: a.lat, longitude: a.lng } } },
        destination: { location: { latLng: { latitude: b.lat, longitude: b.lng } } },
        travelMode: "DRIVE",
      }),
      signal: AbortSignal.timeout(4000),
    });
    if (!res.ok) return null;
    const enc = ((await res.json()) as { routes?: { polyline?: { encodedPolyline?: string } }[] }).routes?.[0]?.polyline?.encodedPolyline;
    return enc ? decodePolyline(enc) : null;
  } catch {
    return null;
  }
}

async function osrmLine(baseUrl: string, a: LatLng, b: LatLng): Promise<[number, number][] | null> {
  try {
    const url = `${baseUrl.replace(/\/+$/, "")}/route/v1/driving/${a.lng},${a.lat};${b.lng},${b.lat}?overview=full&geometries=polyline`;
    const res = await fetch(url, { headers: { "User-Agent": "DROP-ride-hailing/1.0 (officialkryptonia.workers.dev)" }, signal: AbortSignal.timeout(4000) });
    if (!res.ok) return null;
    const g = ((await res.json()) as { routes?: { geometry?: string }[] }).routes?.[0]?.geometry;
    return g ? decodePolyline(g) : null;
  } catch {
    return null;
  }
}

/** The road line between two points for drawing on the map. Falls back to a straight line if no routing service answers. */
export async function routeLine(env: Bindings, a: LatLng, b: LatLng, db?: Client): Promise<{ points: [number, number][]; road: boolean }> {
  const s = db ? await mapSettings(db, env) : null;
  const googleFirst = s ? s.active === "google" : true;
  const osrmUrl = s?.osm_routing_url ?? "https://router.project-osrm.org";
  const first = googleFirst ? await googleLine(env, a, b) : await osrmLine(osrmUrl, a, b);
  const pts = first ?? (googleFirst ? await osrmLine(osrmUrl, a, b) : await googleLine(env, a, b));
  if (pts && pts.length > 1) return { points: thin(pts), road: true };
  return { points: [[a.lat, a.lng], [b.lat, b.lng]], road: false };
}
