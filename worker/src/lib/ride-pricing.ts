import type { Client } from "pg";
import type { Bindings } from "../env";
import { computeFare, type FareBreakdown } from "./fare";
import { MILE_PER_KM, routeBetween, type LatLng, type Route } from "./routing";
import { iconKeyFor } from "../routes/map-icons";
import { getSetting } from "./driver-application";
import { activeRules, airportFare, pickPriceRule, resolveAirportTrip, type Airport, type AirportDirection, type AirportFareBreakdown, type PriceRule } from "./airports";

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
  fare_breakdown: FareBreakdown | AirportFareBreakdown;
  drivers_nearby: number;
  pickup_eta_minutes: number | null;
};

export type Quote =
  | { ok: false; code: string; message: string }
  | {
      ok: true;
      region: { id: number; name: string | null; distance_unit: "km" | "mile"; timezone: string; currency: string };
      route: Route;
      distance: number;
      options: { id: number; name: string; price: number }[];
      ride_types: RideTypeQuote[];
      airport: { airport: Airport; direction: AirportDirection; rules: PriceRule[] } | null;
    };

export async function regionAt(db: Client, p: LatLng) {
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
export async function quoteRide(db: Client, env: Bindings, pickup: LatLng, dropoff: LatLng, stops: LatLng[] = [], airportReq?: { id: number; direction: unknown }): Promise<Quote> {
  // Airport booking: the server decides which end is the airport and that the other end is in the airport's active zone.
  let airportCtx: { airport: Airport; direction: AirportDirection; rules: PriceRule[] } | null = null;
  if (airportReq) {
    const trip = await resolveAirportTrip(db, { airportId: airportReq.id, direction: airportReq.direction, pickup, dropoff });
    if (!trip.ok) return { ok: false, code: trip.code, message: trip.message };
    airportCtx = { airport: trip.airport, direction: trip.direction, rules: await activeRules(db, trip.airport.id) };
  }
  // The zone end of an airport trip defines the region; the airport end lies inside the same region by validation.
  const regionPoint = airportCtx ? (airportCtx.direction === "drop" ? pickup : dropoff) : pickup;
  const region = await regionAt(db, regionPoint);
  if (!region) return { ok: false, code: "outside_service_area", message: "DROP is not available at your pickup location yet." };
  const routePoints = [pickup, ...stops, dropoff];
  if (airportCtx && stops.length) return { ok: false, code: "airport_no_stops", message: "Additional stops are not available on airport rides." };
  for (const stop of stops) {
    const stopRegion = await regionAt(db, stop);
    if (!stopRegion || stopRegion.id !== region.id) return { ok: false, code: "dropoff_outside_area", message: "Every route stop must be inside the same service area as your pickup." };
  }
  const dropRegion = airportCtx ? region : await regionAt(db, dropoff);
  if (!dropRegion || dropRegion.id !== region.id) return { ok: false, code: "dropoff_outside_area", message: "That drop-off is outside our service area." };

  const legs: Route[] = [];
  for (let i = 0; i < routePoints.length - 1; i++) legs.push(await routeBetween(env, routePoints[i], routePoints[i + 1], db));
  const route: Route = {
    distance_km: Math.round(legs.reduce((sum, leg) => sum + leg.distance_km, 0) * 1000) / 1000,
    duration_minutes: legs.reduce((sum, leg) => sum + leg.duration_minutes, 0),
    source: legs.every((leg) => leg.source === legs[0].source)
      ? legs[0].source
      : legs.some((leg) => leg.source === "estimate") ? "estimate"
      : legs.some((leg) => leg.source === "osrm") ? "osrm" : "google",
  };
  if (route.distance_km < 0.05) return { ok: false, code: "same_place", message: "Pickup and drop-off are the same place." };
  const distance = Math.round(route.distance_km * (region.distance_unit === "mile" ? MILE_PER_KM : 1) * 1000) / 1000;

  const services = (
    await db.query(
      `select id, name, name_i18n, category, icon_url, photo_url, capacity, badge, description, payment_methods, cancellation_fee,
              base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive
         from app.services s
        where s.region_id = $1 and s.status and s.deleted_at is null and $3 = any(s.booking_modes)
          and (s.working_hours is null or case
                when (s.working_hours->>'from')::time <= (s.working_hours->>'to')::time
                  then (now() at time zone $2)::time between (s.working_hours->>'from')::time and (s.working_hours->>'to')::time
                else (now() at time zone $2)::time >= (s.working_hours->>'from')::time or (now() at time zone $2)::time <= (s.working_hours->>'to')::time end)
        order by s.sort_order, s.id`,
      [region.id, region.timezone, airportCtx ? "airport" : "now"],
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
    const breakdown = airportCtx
      ? airportFare(s, distance, route.duration_minutes, 0, pickPriceRule(airportCtx.rules, Number(s.id), airportCtx.direction), airportCtx.airport.default_surcharge)
      : computeFare(s, distance, route.duration_minutes);
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

  return { ok: true, region: { id: Number(region.id), name: region.name, distance_unit: region.distance_unit, timezone: region.timezone, currency: String(region.currency).trim() }, route, distance, options, ride_types, airport: airportCtx };
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
  // Drivers working this region who are online right now, wherever they are in it.
  const inRegion = new Map<number, number>((await db.query(
    `select p.service_id, count(*)::int as n from app.users u join app.driver_profiles p on p.user_id = u.id
      where u.is_online and u.active_mode = 'driver' and u.status = 'active' and p.status = 'approved'
        and u.last_location_update_at > now() - interval '5 minutes' and p.service_id = any($1::bigint[]) group by p.service_id`,
    [services.map((s) => s.id)])).rows.map((r) => [Number(r.service_id), r.n as number]));
  return {
    ok: true as const,
    ride_types: services.map((s) => ({
      id: Number(s.id), name: s.name, name_i18n: s.name_i18n, category: s.category, icon_url: s.icon_url, photo_url: s.photo_url,
      map_icon: iconKeyFor(s.category, s.map_icon_key), capacity: s.capacity, badge: s.badge, drivers_nearby: n.get(Number(s.id)) ?? 0, drivers_in_region: inRegion.get(Number(s.id)) ?? 0,
    })),
  };
}
