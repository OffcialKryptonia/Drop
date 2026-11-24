import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { guard, audit } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { quoteRide } from "../lib/ride-pricing";
import { computeFare } from "../lib/fare";
import { userCurrency } from "../lib/currency";
import { getSetting } from "../lib/driver-application";
import { chargeCancellationFee } from "../lib/ride-settlement";
import { overridePickup, pickupSettings } from "../lib/pickup";
import { pushLater, pushNearbyDrivers } from "../lib/push";
import { notify } from "../lib/push-delivery";

export const adminRideRoutes = new Hono<AppEnv>();

const point = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  address: z.string().trim().min(2).max(300),
});
const trip = z.object({ pickup: point, dropoff: point });
const estimateSchema = trip;
const createSchema = trip.extend({
  passenger_id: z.coerce.number().int().positive(),
  service_id: z.coerce.number().int().positive(),
  payment_method: z.enum(["cash", "wallet", "card", "virtual_account"]),
  option_ids: z.array(z.coerce.number().int().positive()).max(20).default([]),
  idempotency_key: z.string().uuid(),
});
const SELECT = `select r.*, s.name as service_name, s.category as service_category,
       rider.display_name as passenger_name, rider.username as passenger_username,
       rider.country_code as passenger_country_code, rider.contact_number as passenger_contact_number,
       driver.display_name as driver_name, admin.display_name as admin_name
  from app.ride_requests r
  join app.services s on s.id = r.service_id
  join app.users rider on rider.id = r.rider_id
  left join app.users driver on driver.id = r.driver_id
  left join app.users admin on admin.id = r.booked_by_admin_id`;
const shape = (r: Record<string, unknown>) => ({
  id: Number(r.id), status: r.status, booking_source: r.booking_source || "passenger",
  passenger: { id: Number(r.rider_id), name: r.passenger_name, username: r.passenger_username,
    phone: [r.passenger_country_code, r.passenger_contact_number].filter(Boolean).join("") },
  admin: r.booked_by_admin_id ? { id: Number(r.booked_by_admin_id), name: r.admin_name } : null,
  driver: r.driver_id ? { id: Number(r.driver_id), name: r.driver_name } : null,
  service: { id: Number(r.service_id), name: r.service_name, category: r.service_category },
  pickup: { lat: Number(r.pickup_lat), lng: Number(r.pickup_lng), address: r.pickup_address },
  dropoff: { lat: Number(r.dropoff_lat), lng: Number(r.dropoff_lng), address: r.dropoff_address },
  distance: Number(r.distance), distance_unit: r.distance_unit, duration_minutes: Number(r.duration_minutes),
  fare: Number(r.fare), currency: r.currency, payment_method: r.payment_method,
  created_at: r.created_at, expires_at: r.expires_at, cancelled_at: r.cancelled_at,
});

adminRideRoutes.get("/admin/order-ride/users", ...guard("ride_order add"), async (c) => {
  const q = (c.req.query("q") ?? "").trim();
  if (q.length < 2) return c.json({ data: [] });
  const digits = q.replace(/\\D/g, "");
  const rows = (await c.get("db").query(
    `select id, display_name, username, email, country_code, contact_number, user_type, active_mode, status
       from app.users
      where deleted_at is null and user_type in ('rider','driver')
        and (display_name ilike $1 or username ilike $1 or email ilike $1
             or ($2 <> '' and app.phone_digits(country_code, contact_number) like $3))
      order by display_name limit 20`,
    [`%${q.replace(/[%_]/g, "")}%`, digits.length >= 4 ? digits : "", `%${digits.replace(/^0+/, "")}%`],
  )).rows;
  return c.json({ data: rows });
});

adminRideRoutes.post("/admin/order-ride/estimate", ...guard("ride_order add"), async (c) => {
  const p = estimateSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { trip: [p.error.issues[0].message] });
  const q = await quoteRide(c.get("db"), c.env, p.data.pickup, p.data.dropoff);
  if (!q.ok) return c.json({ status: false, code: q.code, message: q.message }, 422);
  return c.json({
    status: true, region: { id: q.region.id, name: q.region.name, currency: q.region.currency },
    distance: q.distance, distance_unit: q.region.distance_unit, duration_minutes: q.route.duration_minutes,
    options: q.options, ride_types: q.ride_types,
  });
});

adminRideRoutes.post("/admin/order-ride", ...guard("ride_order add"), async (c) => {
  const p = createSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { booking: [p.error.issues[0].message] });
  const db = c.get("db"), admin = c.get("user"), d = p.data;

  const duplicate = (await db.query(`${SELECT} where r.admin_booking_key = $1`, [d.idempotency_key])).rows[0];
  if (duplicate) return c.json({ status: true, data: shape(duplicate), duplicate: true }, 200);

  const passenger = (await db.query(
    "select id, display_name, user_type, active_mode, status from app.users where id = $1 and deleted_at is null",
    [d.passenger_id],
  )).rows[0];
  if (!passenger || !["rider", "driver"].includes(passenger.user_type) || passenger.status !== "active" || passenger.active_mode !== "rider") {
    return c.json({ status: false, code: "passenger_ineligible", message: "This account is not currently eligible to book a ride. The passenger must be active and in Passenger mode." }, 422);
  }

  await db.query("update app.ride_requests set status = 'expired' where rider_id = $1 and status = 'searching' and expires_at < now()", [d.passenger_id]);
  const open = (await db.query(
    "select id, status from app.ride_requests where rider_id = $1 and status in ('searching','accepted','arrived','in_progress') order by id desc limit 1",
    [d.passenger_id],
  )).rows[0];
  if (open) return c.json({ status: false, code: "already_has_ride", message: `This passenger already has an active ride (#${open.id}, ${open.status}).` }, 409);

  const q = await quoteRide(db, c.env, d.pickup, d.dropoff);
  if (!q.ok) return c.json({ status: false, code: q.code, message: q.message }, 422);
  const type = q.ride_types.find((t) => t.id === d.service_id);
  if (!type) return c.json({ status: false, code: "ride_type_unavailable", message: "That ride type is not available for this trip right now." }, 422);
  if (!type.payment_methods.includes(d.payment_method)) return validationFailed(c, { payment_method: ["That payment method is not available for this ride type."] });

  const chosen = [...new Set(d.option_ids)].map((id) => q.options.find((o) => o.id === id));
  if (chosen.some((o) => !o)) return validationFailed(c, { option_ids: ["One of the extras is not available."] });
  const options = chosen as { id: number; name: string; price: number }[];
  const optionsTotal = options.reduce((sum, o) => sum + o.price, 0);
  const svc = (await db.query("select base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive from app.services where id = $1", [type.id])).rows[0];
  const fare = computeFare(svc, q.distance, q.route.duration_minutes, optionsTotal);

  if (d.payment_method === "wallet") {
    const currency = await userCurrency(db, d.passenger_id);
    if (currency !== q.region.currency) return c.json({ status: false, code: "wallet_currency", message: `The passenger wallet is in ${currency}, but this ride is priced in ${q.region.currency}. Choose another payment method.` }, 422);
    const balance = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [d.passenger_id])).rows[0]?.balance ?? 0);
    if (balance < fare.total) return c.json({ status: false, code: "insufficient_wallet", message: `The passenger wallet balance is insufficient. Fare ${fare.total}, balance ${balance}.` }, 422);
  }

  const expiry = await getSetting(db, "ride_request_expiry_seconds", 120);
  let rideId: number;
  try {
    await db.query("begin");
    const ins = await db.query(
      `insert into app.ride_requests
        (rider_id, service_id, region_id, pickup_lat, pickup_lng, pickup_address, dropoff_lat, dropoff_lng, dropoff_address,
         distance, distance_unit, duration_minutes, route_source, fare, fare_breakdown, options, payment_method, expires_at, currency,
         booking_source, booked_by_admin_id, admin_booking_key)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,now()+make_interval(secs => $18),$19,'admin',$20,$21)
       returning id`,
      [d.passenger_id, type.id, q.region.id, d.pickup.lat, d.pickup.lng, d.pickup.address, d.dropoff.lat, d.dropoff.lng, d.dropoff.address,
        q.distance, q.region.distance_unit, q.route.duration_minutes, q.route.source, fare.total, JSON.stringify(fare), JSON.stringify(options),
        d.payment_method, expiry, q.region.currency, admin.id, d.idempotency_key],
    );
    rideId = Number(ins.rows[0].id);
    await db.query(
      "insert into app.admin_audit (admin_id, action, target, detail) values ($1,'admin_ride_created',$2,$3)",
      [admin.id, String(rideId), JSON.stringify({ passenger_id: d.passenger_id, booking_source: "admin", service_id: type.id })],
    );
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") {
      const prior = (await db.query(`${SELECT} where r.admin_booking_key = $1`, [d.idempotency_key])).rows[0];
      if (prior) return c.json({ status: true, data: shape(prior), duplicate: true }, 200);
      return c.json({ status: false, code: "already_has_ride", message: "This passenger already has an active ride. Refresh and check their current booking." }, 409);
    }
    throw e;
  }
  const row = (await db.query(`${SELECT} where r.id = $1`, [rideId])).rows[0];
  pushLater(c, Promise.all([
    pushNearbyDrivers(db, c.env, rideId),
    notify(db, c.env, { key: "passenger.ride_booked_by_support", userIds: [Number(d.passenger_id)], rideId, data: { type: "ride", event: "admin_booked", ride_id: String(rideId) } }),
  ]));
  return c.json({ status: true, data: shape(row) }, 201);
});

adminRideRoutes.get("/admin/order-rides", ...guard("ride_order list"), async (c) => {
  const q = (c.req.query("q") ?? "").trim();
  const status = (c.req.query("status") ?? "").trim();
  const rows = (await c.get("db").query(
    `${SELECT}
      where r.booking_source = 'admin'
        and ($1 = '' or r.id::text = $1 or rider.display_name ilike $2 or rider.username ilike $2
             or rider.email ilike $2 or rider.contact_number ilike $2)
        and ($3 = '' or r.status = $3)
      order by r.created_at desc limit 100`,
    [q, `%${q.replace(/[%_]/g, "")}%`, status],
  )).rows;
  return c.json({ data: rows.map(shape) });
});

adminRideRoutes.post("/admin/order-rides/:id/cancel", ...guard("ride_order edit"), async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isSafeInteger(id) || id <= 0) return c.json({ message: "Invalid ride ID." }, 422);
  const body = await readBody(c);
  const reason = typeof body.reason === "string" ? body.reason.trim().slice(0, 300) : "";
  if (reason.length < 3) return validationFailed(c, { reason: ["Enter a cancellation reason."] });
  const db = c.get("db");
  const before = (await db.query("select * from app.ride_requests where id = $1 and booking_source = 'admin'", [id])).rows[0];
  if (!before) return c.json({ message: "Admin booking not found." }, 404);
  if (!["searching", "accepted", "arrived"].includes(before.status)) return c.json({ message: "This ride can no longer be cancelled from Admin.", status: 409 }, 409);
  const changed = await db.query(
    "update app.ride_requests set status='cancelled', cancelled_by='admin', cancel_reason=$2, cancelled_at=now() where id=$1 and status=$3 returning id, driver_id",
    [id, reason, before.status],
  );
  if (!changed.rowCount) return c.json({ message: "The ride status changed. Refresh and try again.", status: 409 }, 409);
  let fee = 0;
  if (changed.rows[0].driver_id) {
    fee = await chargeCancellationFee(db, { ...before, status_before: before.status }, await getSetting(db, "ride_cancel_grace_seconds", 120));
    await db.query("update app.users set is_available=true where id=$1 and is_online", [changed.rows[0].driver_id]);
    pushLater(c, notify(db, c.env, { key: "driver.ride_cancelled_by_admin", userIds: [Number(changed.rows[0].driver_id)], rideId: id, data: { type: "ride", event: "admin_cancelled", ride_id: String(id) } }));
  }
  await audit(c, "admin_ride_cancelled", String(id), { passenger_id: Number(before.rider_id), reason, cancellation_fee: fee });
  pushLater(c, notify(db, c.env, { key: "passenger.ride_cancelled_by_admin", userIds: [Number(before.rider_id)], rideId: id, data: { type: "ride", event: "admin_cancelled", ride_id: String(id) } }));
  return c.json({ status: true, id, cancellation_fee: fee });
});

// ---- Pickup code: settings, and authorising a trip start without the code ----

adminRideRoutes.get("/admin/pickup-settings", ...guard("pickup_code list"), async (c) => c.json({ data: await pickupSettings(c.get("db")) }));
adminRideRoutes.put("/admin/pickup-settings", ...guard("pickup_code edit"), async (c) => {
  const p = z.object({
    enabled: z.boolean(),
    expiry_minutes: z.coerce.number().int().min(10, "Use 10 to 720 minutes.").max(720, "Use 10 to 720 minutes."),
    max_attempts: z.coerce.number().int().min(3, "Use 3 to 10 tries.").max(10, "Use 3 to 10 tries."),
    lock_minutes: z.coerce.number().int().min(1, "Use 1 to 120 minutes.").max(120, "Use 1 to 120 minutes."),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { pickup: [p.error.issues[0].message] });
  await c.get("db").query("insert into app.settings (key, value) values ('pickup_code', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(p.data)]);
  await audit(c, "pickup_settings.update", "pickup_code", p.data);
  return c.json({ status: true, data: p.data });
});

/** Rides waiting for their pickup code (accepted or arrived). The code itself is never shown to admins. */
adminRideRoutes.get("/admin/pickup-rides", ...guard("pickup_code list"), async (c) => {
  const rows = (await c.get("db").query(
    `select r.id, r.status, r.booking_source, r.pickup_address, r.accepted_at, p.display_name as passenger_name, d.display_name as driver_name,
            c.verified_at, c.overridden_at, c.failed_attempts, c.total_failed, c.locked_until, c.expires_at
       from app.ride_requests r join app.users p on p.id = r.rider_id left join app.users d on d.id = r.driver_id
       left join app.ride_pickup_codes c on c.ride_request_id = r.id
      where r.status in ('accepted', 'arrived') order by r.id desc limit 50`)).rows;
  return c.json({ data: rows.map((r) => ({
    id: Number(r.id), status: r.status, booking_source: r.booking_source || "passenger", pickup: r.pickup_address, passenger: r.passenger_name, driver: r.driver_name,
    has_code: r.expires_at !== null, verified: !!r.verified_at, overridden: !!r.overridden_at,
    locked: !!(r.locked_until && new Date(r.locked_until as string).getTime() > Date.now()), failed: Number(r.total_failed ?? 0), expires_at: r.expires_at,
  })) });
});

adminRideRoutes.post("/admin/pickup-rides/:id/override", ...guard("pickup_code edit"), async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ status: false, message: "Ride not found." }, 404);
  const db = c.get("db");
  if (!(await overridePickup(db, id, c.get("user").id))) return c.json({ status: false, message: "This ride has no pending pickup code to override." }, 409);
  await audit(c, "pickup.override", `ride:${id}`, {});
  const r = (await db.query("select driver_id from app.ride_requests where id = $1", [id])).rows[0];
  if (r?.driver_id) pushLater(c, notify(db, c.env, { key: "driver.pickup_authorised", userIds: [Number(r.driver_id)], rideId: id, data: { type: "pickup_override", ride_id: String(id) } }));
  return c.json({ status: true, message: "The driver can now start the trip without the code." });
});
