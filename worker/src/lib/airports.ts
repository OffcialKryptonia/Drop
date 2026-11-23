import type { Client } from "pg";
import { haversineKm, type LatLng } from "./routing";
import { regionAt } from "./ride-pricing";
import { computeFare, type FareBreakdown, type FareRule } from "./fare";

export type AirportDirection = "drop" | "pickup";
export const parseDirection = (v: unknown): AirportDirection | null => (v === "drop" || v === "pickup" ? v : null);

export type Airport = {
  id: number;
  region_id: number;
  name: string;
  iata_code: string | null;
  latitude: number | null;
  longitude: number | null;
  radius_m: number | null;
  has_geofence: boolean;
  terminals: unknown;
  pickup_instructions: string | null;
  default_surcharge: number;
  status: boolean;
};

export type PriceRule = {
  service_id: number | null;
  direction: AirportDirection | null;
  mode: "fixed" | "standard";
  fixed_price: number | null;
  surcharge: number;
};

/** Most specific active rule wins: service+direction, service only, direction only, then the airport-wide rule. */
export function pickPriceRule(rules: PriceRule[], serviceId: number, direction: AirportDirection): PriceRule | null {
  const score = (r: PriceRule) => {
    if (r.service_id !== null && r.service_id !== serviceId) return -1;
    if (r.direction !== null && r.direction !== direction) return -1;
    return (r.service_id !== null ? 2 : 0) + (r.direction !== null ? 1 : 0);
  };
  let best: PriceRule | null = null, bestScore = -1;
  for (const r of rules) {
    const s = score(r);
    if (s > bestScore) { best = r; bestScore = s; }
  }
  return best;
}

export type AirportFareBreakdown = FareBreakdown & {
  airport_surcharge: number;
  airport_fixed_price: number | null;
  airport_pricing: "fixed" | "standard";
};

const money = (v: number) => Math.round(v * 100) / 100;

/** Server-side airport fare. Fixed rules replace distance/time pricing; surcharge and chosen extras are added on top. */
export function airportFare(
  svc: FareRule,
  distance: number,
  durationMinutes: number,
  optionsTotal: number,
  rule: PriceRule | null,
  defaultSurcharge: number,
): AirportFareBreakdown {
  const surcharge = money(rule ? rule.surcharge : defaultSurcharge);
  if (rule?.mode === "fixed" && rule.fixed_price !== null) {
    const fixed = money(rule.fixed_price);
    return {
      base_fare: fixed, distance_charge: 0, time_charge: 0, options_total: money(optionsTotal), minimum_fare_applied: false,
      total: money(fixed + surcharge + optionsTotal), airport_surcharge: surcharge, airport_fixed_price: fixed, airport_pricing: "fixed",
    };
  }
  const std = computeFare(svc, distance, durationMinutes, optionsTotal);
  return { ...std, total: money(std.total + surcharge), airport_surcharge: surcharge, airport_fixed_price: null, airport_pricing: "standard" };
}

export type AirportTripError = {
  ok: false;
  code:
    | "airport_unavailable" | "airport_inactive" | "airport_region_inactive" | "airport_direction_invalid"
    | "airport_to_airport" | "airport_endpoint_invalid" | "outside_service_area" | "airport_region_mismatch";
  message: string;
};
export type AirportTrip = { ok: true; airport: Airport; direction: AirportDirection; zone: LatLng; zoneRegionId: number };

const COLS = `a.id, a.region_id, a.name, a.iata_code, a.latitude, a.longitude, a.radius_m, a.terminals, a.pickup_instructions,
              a.default_surcharge, a.status, (a.geofence is not null) as has_geofence`;

export async function loadAirport(db: Client, id: number): Promise<Airport | null> {
  const r = (await db.query(`select ${COLS} from app.airports a where a.id = $1 and a.deleted_at is null`, [id])).rows[0];
  return r ? { ...r, id: Number(r.id), region_id: Number(r.region_id), latitude: r.latitude === null ? null : Number(r.latitude), longitude: r.longitude === null ? null : Number(r.longitude), default_surcharge: Number(r.default_surcharge) } : null;
}

/** True when the point lies in the airport's geofence polygon, else within its radius of the airport point. */
export async function pointInAirport(db: Client, airportId: number, p: LatLng): Promise<boolean> {
  const r = await db.query(
    `select case when a.geofence is not null then extensions.st_covers(a.geofence, pt.g)
                 when a.radius_m is not null and a.location is not null then extensions.st_dwithin(a.location, pt.g, a.radius_m)
                 else false end as inside
       from app.airports a, (select extensions.st_setsrid(extensions.st_makepoint($3, $2), 4326)::extensions.geography as g) pt
      where a.id = $1 and a.deleted_at is null`,
    [airportId, p.lat, p.lng],
  );
  return r.rows[0]?.inside === true;
}

/** Active airports containing a point (used to reject airport-to-airport trips regardless of what the client claims). */
export async function airportsContaining(db: Client, p: LatLng): Promise<number[]> {
  const r = await db.query(
    `select a.id from app.airports a, (select extensions.st_setsrid(extensions.st_makepoint($2, $1), 4326)::extensions.geography as g) pt
      where a.deleted_at is null and a.status
        and case when a.geofence is not null then extensions.st_covers(a.geofence, pt.g)
                 when a.radius_m is not null and a.location is not null then extensions.st_dwithin(a.location, pt.g, a.radius_m) else false end`,
    [p.lat, p.lng],
  );
  return r.rows.map((x) => Number(x.id));
}

/**
 * Validates an airport booking. Exactly one endpoint is the configured, active airport; the other is inside the
 * active DROP service region the airport belongs to. Everything is decided here, never by the app.
 */
export async function resolveAirportTrip(db: Client, input: { airportId: number; direction: unknown; pickup: LatLng; dropoff: LatLng }): Promise<AirportTrip | AirportTripError> {
  const direction = parseDirection(input.direction);
  if (!direction) return { ok: false, code: "airport_direction_invalid", message: "Choose Airport Drop or Airport Pickup." };
  const airport = await loadAirport(db, input.airportId);
  if (!airport) return { ok: false, code: "airport_unavailable", message: "That airport is not available." };
  if (!airport.status) return { ok: false, code: "airport_inactive", message: "Airport rides are not available at this airport right now." };
  const region = (await db.query("select status from app.regions where id = $1", [airport.region_id])).rows[0];
  if (!region?.status) return { ok: false, code: "airport_region_inactive", message: "DROP is not operating in this airport's service area right now." };

  const airportEnd = direction === "drop" ? input.dropoff : input.pickup;
  const zoneEnd = direction === "drop" ? input.pickup : input.dropoff;
  if (!(await pointInAirport(db, airport.id, airportEnd)))
    return { ok: false, code: "airport_endpoint_invalid", message: direction === "drop" ? "The drop-off must be at the airport." : "The pickup must be at the airport." };
  if ((await airportsContaining(db, zoneEnd)).length)
    return { ok: false, code: "airport_to_airport", message: "Airport-to-airport rides are not supported. The other end of the trip must be in a DROP service zone." };
  const zone = await regionAt(db, zoneEnd);
  if (!zone) return { ok: false, code: "outside_service_area", message: "The other end of an airport trip must be inside an active DROP service area." };
  if (Number(zone.id) !== airport.region_id) return { ok: false, code: "airport_region_mismatch", message: "That location is not in this airport's service area." };
  return { ok: true, airport, direction, zone: zoneEnd, zoneRegionId: Number(zone.id) };
}

export async function activeRules(db: Client, airportId: number): Promise<PriceRule[]> {
  return (await db.query("select service_id, direction, mode, fixed_price, surcharge from app.airport_prices where airport_id = $1 and status", [airportId])).rows.map((r) => ({
    service_id: r.service_id === null ? null : Number(r.service_id),
    direction: r.direction,
    mode: r.mode,
    fixed_price: r.fixed_price === null ? null : Number(r.fixed_price),
    surcharge: Number(r.surcharge ?? 0),
  }));
}

/** Plain-metre guard used only for admin sanity checks. */
export const metresBetween = (a: LatLng, b: LatLng) => haversineKm(a, b) * 1000;

/** Columns and join that put an airport's details on a ride row (alias `ap`). */
export const AIRPORT_COLS = `ap.name as airport_name, ap.iata_code as airport_iata, ap.pickup_instructions as airport_instructions, ap.terminals as airport_terminals`;
export const AIRPORT_JOIN = `left join app.airports ap on ap.id = r.airport_id`;

/** Airport details as shown on a ride. Drivers get the flight details without the passenger's phone number. */
export function airportView(r: Record<string, unknown>, forDriver: boolean) {
  if (r.airport_id == null) return null;
  const direction = r.airport_direction as AirportDirection;
  const flight = (r.flight ?? null) as Record<string, unknown> | null;
  let shown: unknown = flight;
  if (forDriver && flight) { const { contact_phone, ...rest } = flight; shown = { ...rest, has_contact: Boolean(contact_phone) }; }
  return {
    id: Number(r.airport_id),
    name: r.airport_name ?? null,
    iata_code: r.airport_iata ?? null,
    direction,
    label: direction === "drop" ? "Airport Drop" : "Airport Pickup",
    pickup_instructions: r.airport_instructions ?? null,
    flight: shown,
    flight_tracking: false,
  };
}
