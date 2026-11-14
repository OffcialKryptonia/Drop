import { iconKeyFor } from "./map-icons";
import { Hono, type Context } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { currencyInfo, userCurrency } from "../lib/currency";
import { readBody, validationFailed } from "../lib/legacy";
import { quoteRide } from "../lib/ride-pricing";
import { computeFare } from "../lib/fare";
import { getSetting } from "../lib/driver-application";
import { chargeCancellationFee } from "../lib/ride-settlement";

export const rideRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

/** Passengers only: a rider-type account that is currently in Passenger mode. */
const passengerOnly = async (c: C, next: () => Promise<void>) => {
  const me = c.get("user");
  if (me.user_type !== "rider" && me.user_type !== "driver") return c.json({ message: "Forbidden" }, 403);
  if (me.active_mode !== "rider") return c.json({ status: false, code: "not_in_passenger_mode", message: "Switch to Passenger mode to request a ride." }, 409);
  await next();
};
const mw = [withDb, requireAuth, passengerOnly] as const;

const point = z.object({
  lat: z.coerce.number({ error: "The latitude is required." }).min(-90).max(90),
  lng: z.coerce.number({ error: "The longitude is required." }).min(-180).max(180),
  address: z.string().trim().max(300).optional(),
});
const tripSchema = z.object({ pickup: point, dropoff: point });
const requestSchema = tripSchema.extend({
  service_id: z.coerce.number().int().positive({ error: "Choose a ride type." }),
  payment_method: z.enum(["cash", "wallet", "card", "virtual_account"], { error: "Choose how you will pay." }),
  option_ids: z.array(z.coerce.number().int().positive()).max(20).default([]),
});

const OPEN = ["searching", "accepted", "arrived", "in_progress"];

type Row = Record<string, unknown>;
const ride = (r: Row) => ({
  id: Number(r.id),
  status: r.status,
  service: { id: Number(r.service_id), name: r.service_name ?? null, category: r.service_category ?? null, map_icon: iconKeyFor(r.service_category as string, r.service_map_icon as string) },
  pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
  dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
  distance: Number(r.distance),
  distance_unit: r.distance_unit,
  duration_minutes: Number(r.duration_minutes),
  fare: Number(r.fare),
  currency: currencyInfo(r.currency as string),
  fare_breakdown: r.fare_breakdown,
  options: r.options,
  payment_method: r.payment_method,
  cancellation_fee: Number(r.cancellation_fee ?? 0),
  paid_with: r.paid_with ?? null,
  completed_at: r.completed_at ?? null,
  expires_at: r.expires_at,
  created_at: r.created_at,
  driver: r.driver_id
    ? {
        id: Number(r.driver_id),
        name: [r.driver_first_name, r.driver_last_name].filter(Boolean).join(" "),
        contact_number: r.driver_contact_number ?? null,
        vehicle: { make: r.vehicle_make, model: r.vehicle_model, colour: r.vehicle_colour, plate: r.vehicle_plate },
        location: r.driver_lat == null ? null : { lat: r.driver_lat, lng: r.driver_lng, updated_at: r.driver_location_at },
      }
    : null,
});

/** One ride with its service name and, once accepted, the driver's details and live position. */
const RIDE_SELECT = `select r.*, s.name as service_name, s.category as service_category, s.map_icon_key as service_map_icon,
       du.first_name as driver_first_name, du.last_name as driver_last_name, du.contact_number as driver_contact_number,
       du.latitude as driver_lat, du.longitude as driver_lng, du.last_location_update_at as driver_location_at,
       p.vehicle_make, p.vehicle_model, p.vehicle_colour, p.vehicle_plate
  from app.ride_requests r
  join app.services s on s.id = r.service_id
  left join app.users du on du.id = r.driver_id
  left join app.driver_profiles p on p.user_id = r.driver_id`;

/** A request nobody accepted in time becomes 'expired'. (A scheduled sweep arrives with matching.) */
const expireStale = (c: C) =>
  c.get("db").query("update app.ride_requests set status = 'expired' where rider_id = $1 and status = 'searching' and expires_at < now()", [c.get("user").id]);

const currentOf = async (c: C) =>
  (
    await c.get("db").query(
      `${RIDE_SELECT} where r.rider_id = $1 and r.status = any($2) order by r.id desc limit 1`,
      [c.get("user").id, OPEN],
    )
  ).rows[0] ?? null;

/** Prices for every ride type available for this trip, with nearby drivers and pickup time. Nothing is saved. */
rideRoutes.post("/ride/estimate", ...mw, async (c) => {
  const p = tripSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { trip: [p.error.issues[0].message] });
  const q = await quoteRide(c.get("db"), c.env, p.data.pickup, p.data.dropoff);
  if (!q.ok) return c.json({ status: false, code: q.code, message: q.message }, 422);
  return c.json({
    status: true,
    region: { id: q.region.id, name: q.region.name },
    currency: currencyInfo(q.region.currency),
    distance: q.distance,
    distance_unit: q.region.distance_unit,
    duration_minutes: q.route.duration_minutes,
    route_source: q.route.source,
    options: q.options,
    ride_types: q.ride_types,
  });
});

/** Request a ride. The fare is recomputed here and saved with the request; the phone never sets the price. */
rideRoutes.post("/ride/request", ...mw, async (c) => {
  const p = requestSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { request: [p.error.issues[0].message] });
  const db = c.get("db");
  const me = c.get("user");
  await expireStale(c);
  if (await currentOf(c)) return c.json({ status: false, code: "already_has_ride", message: "You already have a ride in progress." }, 409);

  const q = await quoteRide(db, c.env, p.data.pickup, p.data.dropoff);
  if (!q.ok) return c.json({ status: false, code: q.code, message: q.message }, 422);
  const type = q.ride_types.find((t) => t.id === p.data.service_id);
  if (!type) return c.json({ status: false, code: "ride_type_unavailable", message: "That ride type is not available for this trip right now." }, 422);
  if (!type.payment_methods.includes(p.data.payment_method)) return validationFailed(c, { payment_method: ["That payment method is not available for this ride type."] });

  const chosen = [...new Set(p.data.option_ids)].map((id) => q.options.find((o) => o.id === id));
  if (chosen.some((o) => !o)) return validationFailed(c, { option_ids: ["One of the extras is not available."] });
  const options = chosen as { id: number; name: string; price: number }[];
  const optionsTotal = options.reduce((s, o) => s + o.price, 0);

  const svc = (await db.query("select base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive from app.services where id = $1", [type.id])).rows[0];
  const fare = computeFare(svc, q.distance, q.route.duration_minutes, optionsTotal);

  if (p.data.payment_method === "wallet") {
    if ((await userCurrency(db, me.id)) !== q.region.currency) return c.json({ status: false, code: "wallet_currency", message: `Your wallet is in ${await userCurrency(db, me.id)}, but this ride is priced in ${q.region.currency}. Choose cash.` }, 422);
    const bal = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [me.id])).rows[0]?.balance ?? 0);
    if (bal < fare.total) return c.json({ status: false, code: "insufficient_wallet", message: `Your wallet balance is too low for this ride. Fare ${fare.total}, balance ${bal}.`, fare: fare.total, balance: bal }, 422);
  }

  const expiry = await getSetting(db, "ride_request_expiry_seconds", 120);
  try {
    const ins = await db.query(
      `insert into app.ride_requests (rider_id, service_id, region_id, pickup_lat, pickup_lng, pickup_address, dropoff_lat, dropoff_lng, dropoff_address,
              distance, distance_unit, duration_minutes, route_source, fare, fare_breakdown, options, payment_method, expires_at, currency)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17, now() + make_interval(secs => $18), $19)
       returning id`,
      [me.id, type.id, q.region.id, p.data.pickup.lat, p.data.pickup.lng, p.data.pickup.address ?? null, p.data.dropoff.lat, p.data.dropoff.lng, p.data.dropoff.address ?? null,
        q.distance, q.region.distance_unit, q.route.duration_minutes, q.route.source, fare.total, JSON.stringify(fare), JSON.stringify(options), p.data.payment_method, expiry, q.region.currency],
    );
    const row = (await db.query(`${RIDE_SELECT} where r.id = $1`, [ins.rows[0].id])).rows[0];
    return c.json({ status: true, data: ride(row) }, 201);
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return c.json({ status: false, code: "already_has_ride", message: "You already have a ride in progress." }, 409);
    throw e;
  }
});

/** The passenger's open ride request, if any. */
rideRoutes.get("/ride/current", ...mw, async (c) => {
  await expireStale(c);
  const row = await currentOf(c);
  return c.json({ status: true, data: row ? ride(row) : null });
});

/** Cancel the open request. After a driver has accepted, a late cancellation can cost the ride type's cancellation fee. */
rideRoutes.post("/ride/cancel", ...mw, async (c) => {
  const db = c.get("db");
  const body = await readBody(c);
  const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 300) || null : null;
  const before = (await db.query("select * from app.ride_requests where rider_id = $1 and status in ('searching', 'accepted', 'arrived') order by id desc limit 1", [c.get("user").id])).rows[0];
  if (!before) {
    const trip = (await db.query("select 1 from app.ride_requests where rider_id = $1 and status = 'in_progress'", [c.get("user").id])).rowCount;
    if (trip) return c.json({ status: false, code: "trip_in_progress", message: "Your trip has started. Ask the driver to end it." }, 409);
    return c.json({ status: false, code: "nothing_to_cancel", message: "There is no ride you can cancel right now." }, 409);
  }
  const r = await db.query(
    `update app.ride_requests set status = 'cancelled', cancelled_by = 'rider', cancel_reason = $3, cancelled_at = now()
      where id = $1 and rider_id = $2 and status = $4 returning id, driver_id`,
    [before.id, c.get("user").id, reason, before.status],
  );
  if (!r.rowCount) return c.json({ status: false, code: "nothing_to_cancel", message: "That ride just changed. Please check again." }, 409);
  let fee = 0;
  if (r.rows[0].driver_id) {
    fee = await chargeCancellationFee(db, { ...before, status_before: before.status }, await getSetting(db, "ride_cancel_grace_seconds", 120));
    // The driver who had accepted is free to take other requests again.
    await db.query("update app.users set is_available = true where id = $1 and is_online", [r.rows[0].driver_id]);
  }
  return c.json({ status: true, id: Number(r.rows[0].id), cancellation_fee: fee });
});

/** The passenger's finished and cancelled rides, newest first. */
rideRoutes.get("/ride/history", ...mw, async (c) => {
  const rows = (await c.get("db").query(
    `${RIDE_SELECT} where r.rider_id = $1 and r.status in ('completed', 'cancelled', 'expired') order by r.id desc limit 50`, [c.get("user").id])).rows;
  return c.json({ status: true, data: rows.map(ride) });
});
