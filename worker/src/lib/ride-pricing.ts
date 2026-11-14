import type { Client } from "pg";
import type { Bindings } from "../env";
import { computeFare, type FareBreakdown } from "./fare";
import { MILE_PER_KM, routeBetween, type LatLng, type Route } from "./routing";
import { iconKeyFor } from "../routes/map-icons";
import { getSetting } from "./driver-application";

const POINT = (latParam: number, lngParam: number) => `extensions.st_setsrid(extensions.st_makepoint($${lngParam}, $${latParam}), 4326)::extensions.geography`;

export type RideTypeQuote = {
  id: number;
  name: string;
  name_i18n: unknown;
  category: string;
  icon_url: string | null;
  photo_url: string | null;
  capacity: number;
  badge: string | null;
  description: string | null;
  payment_methods: string[];
  cancellation_fee: number;
  fare: number;
  fare_breakdown: FareBreakdown;
  drivers_nearby: number;
  pickup_eta_minutes: number | null;
};

export type Quote =
  | { ok: false; code: "outside_service_area" | "dropoff_outside_area" | "same_place"; message: string }
  | {
      ok: true;
      region: { id: number; name: string | null; distance_unit: "km" | "mile"; timezone: string; currency: string };
      route: Route;
      distance: number;
      options: { id: number; name: string; price: number }[];
      ride_types: RideTypeQuote[];
    };

async function regionAt(db: Client, p: LatLng) {
  // A region with a drawn boundary must contain the point; one without a boundary covers everywhere (used last).
  return (
    await db.query(
      `select id, name, distance_unit, timezone, currency from app.regions
        where status and (boundary is null or extensions.st_covers(boundary, ${POINT(1, 2)}))
        order by (boundary is null), id limit 1`,
      [p.lat, p.lng],
    )
  ).rows[0] as { id: number; name: string | null; distance_unit: "km" | "mile"; timezone: string; currency: string } | undefined;
}

/** Everything the app needs to show prices for a trip, all from admin data. The server is the only place fares are computed. */
export async function quoteRide(db: Client, env: Bindings, pickup: LatLng, dropoff: LatLng): Promise<Quote> {
  const region = await regionAt(db, pickup);
  if (!region) return { ok: false, code: "outside_service_area", message: "DROP is not available at your pickup location yet." };
  const dropRegion = await regionAt(db, dropoff);
  if (!dropRegion || dropRegion.id !== region.id) return { ok: false, code: "dropoff_outside_area", message: "That drop-off is outside our service area." };

  const route = await routeBetween(env, pickup, dropoff, db);
  if (route.distance_km < 0.05) return { ok: false, code: "same_place", message: "Pickup and drop-off are the same place." };
  const distance = Math.round(route.distance_km * (region.distance_unit === "mile" ? MILE_PER_KM : 1) * 1000) / 1000;

  const services = (
    await db.query(
      `select id, name, name_i18n, category, icon_url, photo_url, capacity, badge, description, payment_methods, cancellation_fee,
              base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive
         from app.services s
        where s.region_id = $1 and s.status and s.deleted_at is null and 'now' = any(s.booking_modes)
          and (s.working_hours is null or case
                when (s.working_hours->>'from')::time <= (s.working_hours->>'to')::time
                  then (now() at time zone $2)::time between (s.working_hours->>'from')::time and (s.working_hours->>'to')::time
                else (now() at time zone $2)::time >= (s.working_hours->>'from')::time or (now() at time zone $2)::time <= (s.working_hours->>'to')::time end)
        order by s.sort_order, s.id`,
      [region.id, region.timezone],
    )
  ).rows;

  const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
  const near = (
    await db.query(
      `select p.service_id, count(*)::int as n, min(extensions.st_distance(u.location, ${POINT(1, 2)})) as nearest_m
         from app.users u join app.driver_profiles p on p.user_id = u.id
        where u.is_online and u.is_available and u.active_mode = 'driver' and u.status = 'active' and p.status = 'approved'
          and u.location is not null and u.last_location_update_at > now() - interval '5 minutes'
          and extensions.st_dwithin(u.location, ${POINT(1, 2)}, $3)
        group by p.service_id`,
      [pickup.lat, pickup.lng, radius],
    )
  ).rows;
  const nearBy = new Map<number, { n: number; nearest_m: number }>(near.map((r) => [Number(r.service_id), { n: r.n, nearest_m: Number(r.nearest_m) }]));

  const options = (await db.query("select id, name, price from app.service_options where status and deleted_at is null order by sort_order, id")).rows.map((o) => ({
    id: Number(o.id),
    name: o.name as string,
    price: Number(o.price),
  }));

  const ride_types: RideTypeQuote[] = services.map((s) => {
    const breakdown = computeFare(s, distance, route.duration_minutes);
    const nb = nearBy.get(Number(s.id));
    return {
      id: Number(s.id),
      name: s.name,
      name_i18n: s.name_i18n,
      category: s.category,
      icon_url: s.icon_url,
      photo_url: s.photo_url,
      capacity: s.capacity,
      badge: s.badge,
      description: s.description,
      payment_methods: s.payment_methods,
      cancellation_fee: Number(s.cancellation_fee ?? 0),
      fare: breakdown.total,
      fare_breakdown: breakdown,
      drivers_nearby: nb?.n ?? 0,
      pickup_eta_minutes: nb ? Math.max(1, Math.round(((nb.nearest_m / 1000) * 1.3 * 2))) : null, // 30 km/h = 2 minutes per km
    };
  });

  return { ok: true, region: { id: Number(region.id), name: region.name, distance_unit: region.distance_unit, timezone: region.timezone, currency: String(region.currency).trim() }, route, distance, options, ride_types };
}

/** Ride types open at a pickup point, with nearby driver counts, for the home screen strip (no destination yet, so no fares). */
export async function listRideTypes(db: Client, pickup: LatLng) {
  const region = await regionAt(db, pickup);
  if (!region) return { ok: false as const, message: "DROP is not available at your location yet." };
  const services = (
    await db.query(
      `select id, name, name_i18n, category, icon_url, photo_url, map_icon_key, capacity, badge
         from app.services s
        where s.region_id = $1 and s.status and s.deleted_at is null and 'now' = any(s.booking_modes)
          and (s.working_hours is null or case
                when (s.working_hours->>'from')::time <= (s.working_hours->>'to')::time
                  then (now() at time zone $2)::time between (s.working_hours->>'from')::time and (s.working_hours->>'to')::time
                else (now() at time zone $2)::time >= (s.working_hours->>'from')::time or (now() at time zone $2)::time <= (s.working_hours->>'to')::time end)
        order by s.sort_order, s.id`,
      [region.id, region.timezone],
    )
  ).rows;
  const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
  const near = (
    await db.query(
      `select p.service_id, count(*)::int as n
         from app.users u join app.driver_profiles p on p.user_id = u.id
        where u.is_online and u.is_available and u.active_mode = 'driver' and u.status = 'active' and p.status = 'approved'
          and u.location is not null and u.last_location_update_at > now() - interval '5 minutes'
          and extensions.st_dwithin(u.location, ${POINT(1, 2)}, $3)
        group by p.service_id`,
      [pickup.lat, pickup.lng, radius],
    )
  ).rows;
  const n = new Map<number, number>(near.map((r) => [Number(r.service_id), r.n as number]));
  return {
    ok: true as const,
    ride_types: services.map((s) => ({
      id: Number(s.id), name: s.name, name_i18n: s.name_i18n, category: s.category, icon_url: s.icon_url, photo_url: s.photo_url,
      map_icon: iconKeyFor(s.category, s.map_icon_key), capacity: s.capacity, badge: s.badge, drivers_nearby: n.get(Number(s.id)) ?? 0,
    })),
  };
}
