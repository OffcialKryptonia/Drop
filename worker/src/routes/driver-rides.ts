import { etaSettings, rideEta } from "../lib/eta";
import { driverReceipt } from "../lib/receipt";
import { Hono, type Context } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireWebOrBearer } from "../auth/web-or-bearer";
import { computeCommission, type CommissionRule } from "../lib/commission";
import { driverOnlineBlock, requireApprovedDriver } from "../lib/roles";
import { getSetting } from "../lib/driver-application";
import { voidExtrasForRide } from "../lib/extras";
import { extraTypes, extrasSettings } from "../lib/extras";
import { chatUnread } from "../lib/chat";
import { driverPickupFlags, issuePickupCode, pickupSettings, startAllowedSql, verifyPickup } from "../lib/pickup";
import { completeRide } from "../lib/ride-settlement";
import { pushLater, pushRideEvent } from "../lib/push";
import { driverBidList, driverPreferences } from "./ride-bids";
import { AIRPORT_COLS, AIRPORT_JOIN, airportView } from "../lib/airports";

export const driverRideRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

/** Approved driver, currently in Driver mode. */
const driverMode = async (c: C, next: () => Promise<void>) => {
  if (c.get("user").active_mode !== "driver") return c.json({ status: false, code: "not_in_driver_mode", message: "Switch to Driver mode first." }, 409);
  await next();
};
const mw = [withDb, requireWebOrBearer, requireApprovedDriver, driverMode] as const;

const POINT = "extensions.st_setsrid(extensions.st_makepoint(r.pickup_lng, r.pickup_lat), 4326)::extensions.geography";

type Row = Record<string, unknown>;
const request = (r: Row, rule: CommissionRule) => {
  const fare = Number(r.fare);
  const commission = Number(computeCommission(rule, fare));
  const km = Number(r.pickup_m ?? 0) / 1000;
  return {
    id: Number(r.id),
    status: r.status,
    airport: airportView(r, true),
    fare,
    commission,
    earning: Math.round((fare - commission) * 100) / 100,
    payment_method: r.payment_method,
    pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
    dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
    stops: Array.isArray(r.stops) ? r.stops : [],
    distance: Number(r.distance),
    distance_unit: r.distance_unit,
    duration_minutes: Number(r.duration_minutes),
    pickup_distance_km: Math.round(km * 10) / 10,
    pickup_eta_minutes: Math.max(1, Math.round(km * 1.3 * 2)),
    eta: rideEta(r),
    options: r.options,
    // No phone number: the passenger is reached through in-app chat and calls, which keep both numbers private.
    rider: { first_name: r.rider_first_name ?? null },
    expires_at: r.expires_at,
    seconds_left: r.expires_at ? Math.max(0, Math.round((new Date(r.expires_at as string).getTime() - Date.now()) / 1000)) : null,
  };
};

/** The driver's open ride (accepted, arrived or in progress), if any. */
async function activeOf(c: C) {
  return (
    await c.get("db").query(
      `select r.*, ${AIRPORT_COLS}, u.first_name as rider_first_name, u.contact_number as rider_contact_number,
              du.latitude as driver_lat, du.longitude as driver_lng, du.last_location_update_at as driver_location_at,
              coalesce((select jsonb_agg(jsonb_build_object('id', st.id, 'sequence', st.sequence, 'lat', st.lat, 'lng', st.lng,
                'address', st.address, 'status', st.status, 'arrived_at', st.arrived_at, 'completed_at', st.completed_at) order by st.sequence)
                from app.ride_request_stops st where st.ride_request_id = r.id), '[]'::jsonb) as stops
         from app.ride_requests r join app.users u on u.id = r.rider_id
         ${AIRPORT_JOIN}
         left join app.users du on du.id = r.driver_id
        where r.driver_id = $1 and r.status in ('accepted', 'arrived', 'in_progress') order by r.id desc limit 1`,
      [c.get("user").id],
    )
  ).rows[0] as Row | undefined;
}

const shapeActive = async (c: C, active: Row) => ({
  ...request(active, await ruleOf(c, active.service_id)),
  ...(await driverPickupFlags(c.get("db"), Number(active.id))),
  chat_unread: await chatUnread(c.get("db"), Number(active.id), c.get("user").id, c.get("user").id),
});

const ruleOf = async (c: C, serviceId: unknown) =>
  ((await c.get("db").query("select commission_type, admin_commission from app.services where id = $1", [serviceId])).rows[0] ?? { commission_type: null, admin_commission: 0 }) as CommissionRule;

/** What the driver home polls: the open ride, or the nearest searching requests for the driver's ride type. */
driverRideRoutes.get("/driver/requests", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const active = await activeOf(c);
  const etaOn = (await etaSettings(db)).driver;
  const hideEta = <T extends object>(x: T) => (etaOn ? x : { ...x, eta: null, pickup_eta_minutes: null });
  if (active) {
    // The "Add extra charge" button only shows while the feature is on and the admin has at least one active charge type.
    const extrasOn = (await extrasSettings(db)).enabled && (await extraTypes(db, true)).length > 0;
    return c.json({ status: true, active: { ...hideEta(await shapeActive(c, active)), extras_enabled: extrasOn }, requests: [], bids: [], preferences: await driverPreferences(db, me.id) });
  }

  const st = (await db.query("select is_online from app.users where id = $1", [me.id])).rows[0];
  if (!st?.is_online) return c.json({ status: false, code: "not_online", message: "Go online to see ride requests." }, 409);

  const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
  const rows = (
    await db.query(
      `select r.*, ${AIRPORT_COLS}, u.first_name as rider_first_name, extensions.st_distance(du.location, ${POINT}) as pickup_m,
              coalesce((select jsonb_agg(jsonb_build_object('id', st.id, 'sequence', st.sequence, 'lat', st.lat, 'lng', st.lng,
                'address', st.address, 'status', st.status, 'arrived_at', st.arrived_at, 'completed_at', st.completed_at) order by st.sequence)
                from app.ride_request_stops st where st.ride_request_id = r.id), '[]'::jsonb) as stops
         from app.ride_requests r
         ${AIRPORT_JOIN}
         join app.users u on u.id = r.rider_id
         join app.users du on du.id = $1
         join app.driver_profiles p on p.user_id = $1
        where r.status = 'searching' and r.expires_at > now() and r.service_id = p.service_id and r.rider_id <> $1
          and du.location is not null and extensions.st_dwithin(du.location, ${POINT}, $2)
          and not exists (select 1 from app.ride_request_declines d where d.request_id = r.id and d.driver_id = $1)
        order by pickup_m limit 10`,
      [me.id, radius],
    )
  ).rows;
  const prof = (await db.query("select service_id from app.driver_profiles where user_id = $1", [me.id])).rows[0];
  const rule = await ruleOf(c, prof?.service_id);
  // Two independent switches: a driver with standard requests OFF sees none; bids come only if passenger bids are ON (or a negotiation is already running).
  const preferences = await driverPreferences(db, me.id);
  return c.json({
    status: true, active: null, preferences,
    requests: preferences.accepts_standard ? rows.map((r) => hideEta(request(r, rule))) : [],
    bids: await driverBidList(db, me.id),
  });
});

/** First driver to accept wins: one atomic update decides, everyone else gets 'no longer available'. */
driverRideRoutes.post("/driver/requests/:id/accept", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ status: false, code: "request_gone", message: "This request is no longer available." }, 404);

  const u = (await db.query("select u.is_online, p.service_id, p.accepts_standard from app.users u join app.driver_profiles p on p.user_id = u.id where u.id = $1", [me.id])).rows[0];
  if (!u?.is_online) return c.json({ status: false, code: "not_online", message: "Go online to accept rides." }, 409);
  if (u.accepts_standard === false) return c.json({ status: false, code: "standard_requests_off", message: "Standard ride requests are turned off in your settings." }, 403);
  const block = await driverOnlineBlock(db, me.id, u.service_id);
  if (block) return c.json({ status: false, ...block }, 403);

  try {
    await db.query("begin");
    const r = await db.query(
      `update app.ride_requests r set status = 'accepted', driver_id = $1, accepted_at = now()
        where r.id = $2 and r.status = 'searching' and r.expires_at > now() and r.rider_id <> $1 and r.service_id = $3 returning r.id, r.rider_id`,
      [me.id, id, u.service_id],
    );
    if (!r.rowCount) {
      await db.query("rollback");
      return c.json({ status: false, code: "request_gone", message: "This request is no longer available." }, 409);
    }
    await db.query("update app.users set is_available = false where id = $1", [me.id]);
    // Do not accept a ride if pickup-code issuance fails while the feature is enabled.
    // Keeping acceptance and code issuance in the same transaction prevents an accepted ride
    // from silently bypassing the pickup verification requirement.
    await issuePickupCode(db, c.env.SETTINGS_ENCRYPTION_KEY, id);
    await db.query("commit");
    pushLater(c, pushRideEvent(db, c.env, Number(r.rows[0].rider_id), "accepted", id));
  } catch (e) {
    await db.query("rollback").catch(() => {});
    if ((e as { code?: string }).code === "23505") return c.json({ status: false, code: "already_on_ride", message: "Finish your current ride first." }, 409);
    throw e;
  }
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? await shapeActive(c, active) : null });
});

/** Not interested: the request is hidden from this driver only. */
driverRideRoutes.post("/driver/requests/:id/decline", ...mw, async (c) => {
  const id = Number(c.req.param("id"));
  if (Number.isInteger(id) && id > 0) {
    await c.get("db").query(
      "insert into app.ride_request_declines (request_id, driver_id) select $1, $2 where exists (select 1 from app.ride_requests where id = $1) on conflict do nothing",
      [id, c.get("user").id],
    );
  }
  return c.json({ status: true });
});

const notYours = (c: C) => c.json({ status: false, code: "wrong_state", message: "This ride is not in the right state for that." }, 409);
const idOf = (c: C) => Number(c.req.param("id"));

/** Move a ride one step forward, only if it is this driver's and in the expected state. */
async function step(c: C, from: string, to: string, stamp: string) {
  const db = c.get("db");
  const guarded = to === "in_progress";
  const r = await db.query(
    `update app.ride_requests set status = $3, ${stamp} = now() where id = $1 and driver_id = $2 and status = $4${guarded ? ` and ${startAllowedSql(5)}` : ""} returning id, rider_id`,
    guarded ? [idOf(c), c.get("user").id, to, from, (await pickupSettings(db)).enabled] : [idOf(c), c.get("user").id, to, from],
  );
  if (!r.rowCount) {
    if (guarded) {
      const flags = await driverPickupFlags(db, idOf(c));
      if (flags.pickup_required) return c.json({ status: false, code: "pickup_not_verified", message: "Enter the passenger’s pickup code before starting the trip." }, 409);
    }
    return notYours(c);
  }
  if (to === "arrived" || to === "in_progress") pushLater(c, pushRideEvent(db, c.env, Number(r.rows[0].rider_id), to === "arrived" ? "arrived" : "started", idOf(c)));
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? await shapeActive(c, active) : null });
}

/** Driver types the passenger's four-digit pickup code. The server never sends the correct code to the driver app. */
driverRideRoutes.post("/driver/rides/:id/verify-pickup", ...mw, async (c) => {
  const body = await c.req.json<{ code?: unknown }>().catch((): { code?: unknown } => ({}));
  const code = String(body.code ?? "").trim();
  if (!/^\d{4}$/.test(code)) return c.json({ status: false, code: "bad_format", message: "Enter the four-digit code." }, 422);
  const result = await verifyPickup(c.get("db"), idOf(c), c.get("user").id, code);
  if (!result.ok) return c.json({ status: false, code: result.code, message: result.message, attempts_left: result.attempts_left ?? null, retry_after_seconds: result.retry_after_seconds ?? null }, result.code === "wrong_state" ? 409 : 422);
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? await shapeActive(c, active) : null });
});

/** Driver is at the pickup point. */
driverRideRoutes.post("/driver/rides/:id/arrived", ...mw, (c) => step(c, "accepted", "arrived", "arrived_at"));
/** Passenger is in the car: trip starts. */
driverRideRoutes.post("/driver/rides/:id/start", ...mw, (c) => step(c, "arrived", "in_progress", "started_at"));

/** Driver stop progression is ordered and enforced by the server. */
driverRideRoutes.post("/driver/rides/:id/stops/:stopId/arrived", ...mw, async (c) => {
  const rideId = idOf(c), stopId = Number(c.req.param("stopId")), db = c.get("db"), driverId = c.get("user").id;
  if (!Number.isInteger(stopId) || stopId <= 0) return notYours(c);
  const result = await db.query(
    `update app.ride_request_stops st set status='arrived', arrived_at=now()
      where st.id=$1 and st.ride_request_id=$2 and st.status='pending'
        and exists (select 1 from app.ride_requests r where r.id=st.ride_request_id and r.driver_id=$3 and r.status='in_progress')
        and not exists (select 1 from app.ride_request_stops earlier
          where earlier.ride_request_id=st.ride_request_id and earlier.sequence<st.sequence and earlier.status<>'completed')
      returning st.id`,
    [stopId, rideId, driverId],
  );
  if (!result.rowCount) return c.json({ status:false, code:"stop_out_of_order", message:"Complete the previous stop before arriving at this one." },409);
  const active = await activeOf(c);
  return c.json({ status:true, data: active ? await shapeActive(c, active) : null });
});
driverRideRoutes.post("/driver/rides/:id/stops/:stopId/complete", ...mw, async (c) => {
  const rideId = idOf(c), stopId = Number(c.req.param("stopId")), db = c.get("db"), driverId = c.get("user").id;
  if (!Number.isInteger(stopId) || stopId <= 0) return notYours(c);
  const result = await db.query(
    `update app.ride_request_stops st set status='completed', completed_at=now()
      where st.id=$1 and st.ride_request_id=$2 and st.status='arrived'
        and exists (select 1 from app.ride_requests r where r.id=st.ride_request_id and r.driver_id=$3 and r.status='in_progress')
        and not exists (select 1 from app.ride_request_stops earlier
          where earlier.ride_request_id=st.ride_request_id and earlier.sequence<st.sequence and earlier.status<>'completed')
      returning st.id`,
    [stopId, rideId, driverId],
  );
  if (!result.rowCount) return c.json({ status:false, code:"stop_out_of_order", message:"Arrive at the current stop after completing the previous stop." },409);
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? await shapeActive(c, active) : null });
});

/** Trip finished: pays the driver / takes commission and frees the driver for the next request. */
driverRideRoutes.post("/driver/rides/:id/complete", ...mw, async (c) => {
  const remaining = Number((await c.get("db").query("select count(*)::int as n from app.ride_request_stops where ride_request_id=$1 and status<>'completed'", [idOf(c)])).rows[0]?.n ?? 0);
  if (remaining > 0) return c.json({ status:false, code:"stops_remaining", message:"Complete every additional stop before ending this trip." },409);
  const done = await completeRide(c.get("db"), idOf(c), c.get("user").id);
  if (!done) return notYours(c);
  const stops = (await c.get("db").query(
    "select id, sequence, lat, lng, address, status, arrived_at, completed_at from app.ride_request_stops where ride_request_id = $1 order by sequence",
    [idOf(c)],
  )).rows;
  pushLater(c, pushRideEvent(c.get("db"), c.env, Number(done.rider_id), "completed", Number(done.id), { fare: done.fare, currency: done.currency }));
  return c.json({ status: true, data: { id: Number(done.id), status: done.status, fare: Number(done.fare), commission: Number(done.commission), earning: Math.round((Number(done.fare) - Number(done.commission)) * 100) / 100, paid_with: done.paid_with, collect_cash: done.paid_with === "cash", stops } });
});

/** Driver backs out before the trip starts: the request goes back to other drivers (not this one). No fee for the passenger. */
driverRideRoutes.post("/driver/rides/:id/cancel", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user").id;
  // A ride that came from a bid carries a negotiated fare for one specific passenger, so it must never go back to the open pool: it is cancelled.
  const fromBid = (await db.query("select bid_id from app.ride_requests where id = $1 and driver_id = $2 and status in ('accepted', 'arrived')", [idOf(c), me])).rows[0]?.bid_id != null;
  if (fromBid) {
    await db.query("begin");
    try {
      const r = await db.query(
        `update app.ride_requests set status = 'cancelled', cancelled_by = 'driver', cancel_reason = 'Driver cancelled after the fare was agreed', cancelled_at = now()
          where id = $1 and driver_id = $2 and status in ('accepted', 'arrived') returning id, rider_id`, [idOf(c), me]);
      if (!r.rowCount) { await db.query("rollback"); return notYours(c); }
      await db.query("update app.users set is_available = true where id = $1 and is_online", [me]);
      await voidExtrasForRide(db, idOf(c));
      await db.query("commit");
      pushLater(c, pushRideEvent(db, c.env, Number(r.rows[0].rider_id), "driver_cancelled", idOf(c)));
    } catch (e) { await db.query("rollback").catch(() => {}); throw e; }
    return c.json({ status: true });
  }
  await db.query("begin");
  try {
    const r = await db.query(
      `update app.ride_requests set status = 'searching', driver_id = null, accepted_at = null, arrived_at = null,
              expires_at = now() + make_interval(secs => $3::int)
        where id = $1 and driver_id = $2 and status in ('accepted', 'arrived') returning id, rider_id`,
      [idOf(c), me, await getSetting(db, "ride_request_expiry_seconds", 120)],
    );
    if (!r.rowCount) { await db.query("rollback"); return notYours(c); }
    await db.query("insert into app.ride_request_declines (request_id, driver_id) values ($1, $2) on conflict do nothing", [idOf(c), me]);
    await db.query("update app.users set is_available = true where id = $1", [me]);
    await voidExtrasForRide(db, idOf(c));
    await db.query("commit");
    pushLater(c, pushRideEvent(db, c.env, Number(r.rows[0].rider_id), "driver_cancelled", idOf(c)));
  } catch (e) { await db.query("rollback").catch(() => {}); throw e; }
  return c.json({ status: true });
});

/** The driver's finished trips with what they earned. */
driverRideRoutes.get("/driver/rides/history", ...mw, async (c) => {
  const rows = (await c.get("db").query(
    `select r.id, r.status, r.fare, r.commission, r.paid_with, r.pickup_address, r.dropoff_address, r.distance, r.distance_unit, r.completed_at, r.cancellation_fee,
            coalesce((select jsonb_agg(jsonb_build_object('id', st.id, 'sequence', st.sequence, 'lat', st.lat, 'lng', st.lng,
              'address', st.address, 'status', st.status, 'arrived_at', st.arrived_at, 'completed_at', st.completed_at) order by st.sequence)
              from app.ride_request_stops st where st.ride_request_id = r.id), '[]'::jsonb) as stops
       from app.ride_requests r where r.driver_id = $1 and r.status = 'completed' order by r.id desc limit 50`, [c.get("user").id])).rows;
  return c.json({ status: true, data: rows.map((r) => ({ ...r, id: Number(r.id), fare: Number(r.fare), commission: Number(r.commission), earning: Math.round((Number(r.fare) - Number(r.commission)) * 100) / 100 })) });
});

/** The driver's receipt for one finished trip: fare, DROP commission and what they earned. */
driverRideRoutes.get("/driver/rides/:id/receipt", ...mw, async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ status: false, message: "Trip not found." }, 404);
  const row = (await c.get("db").query(
    `select r.*, s.name as service_name, u.first_name as rider_first_name,
              coalesce((select jsonb_agg(jsonb_build_object('id', st.id, 'sequence', st.sequence, 'lat', st.lat, 'lng', st.lng,
                'address', st.address, 'status', st.status, 'arrived_at', st.arrived_at, 'completed_at', st.completed_at) order by st.sequence)
                from app.ride_request_stops st where st.ride_request_id = r.id), '[]'::jsonb) as stops
       from app.ride_requests r join app.services s on s.id = r.service_id join app.users u on u.id = r.rider_id
      where r.id = $1 and r.driver_id = $2 and r.status = 'completed'`, [id, c.get("user").id])).rows[0];
  if (!row) return c.json({ status: false, message: "No receipt for this trip yet." }, 404);
  const extras = (await c.get("db").query("select * from app.ride_extras where ride_request_id = $1 order by id", [id])).rows;
  return c.json({ status: true, data: driverReceipt(row, extras) });
});
