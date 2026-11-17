import { haversineKm, MILE_PER_KM } from "./routing";

type Row = Record<string, unknown>;

/**
 * Live "how long until..." for an open ride, from the driver's last known position.
 * accepted -> to the pickup, in_progress -> to the drop-off, anything else -> null (no countdown to show).
 * It is an estimate (straight line stretched for roads, at the speed this trip was quoted at), not turn-by-turn.
 */
export function rideEta(r: Row, now = Date.now()) {
  const status = String(r.status);
  if (status !== "accepted" && status !== "in_progress") return null;
  const lat = Number(r.driver_lat);
  const lng = Number(r.driver_lng);
  if (r.driver_lat == null || r.driver_lng == null || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  const toPickup = status === "accepted";
  const target = toPickup ? { lat: Number(r.pickup_lat), lng: Number(r.pickup_lng) } : { lat: Number(r.dropoff_lat), lng: Number(r.dropoff_lng) };
  if (!Number.isFinite(target.lat) || !Number.isFinite(target.lng)) return null;

  const unit = r.distance_unit === "mi" ? "mi" : "km";
  const quotedKm = unit === "mi" ? Number(r.distance) / MILE_PER_KM : Number(r.distance);
  const quotedMin = Number(r.duration_minutes);
  const kmh = quotedKm > 0 && quotedMin > 0 ? Math.min(45, Math.max(18, quotedKm / (quotedMin / 60))) : 30;

  const km = Math.round(haversineKm({ lat, lng }, target) * 1.3 * 100) / 100;
  const minutes = km < 0.05 ? 0 : Math.max(1, Math.round((km / kmh) * 60));
  const at = r.driver_location_at ? new Date(r.driver_location_at as string).getTime() : NaN;
  return {
    target: toPickup ? "pickup" : "dropoff",
    minutes,
    distance: Math.round((unit === "mi" ? km * MILE_PER_KM : km) * 10) / 10,
    distance_unit: unit,
    arrive_at: new Date(now + minutes * 60_000).toISOString(),
    stale: !Number.isFinite(at) || now - at > 90_000, // the driver's phone has not reported for 90 s
    source: "estimate" as const,
  };
}
