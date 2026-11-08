import { Hono, type Context } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { computeCommission, type CommissionRule } from "../lib/commission";
import { driverOnlineBlock, requireApprovedDriver } from "../lib/roles";
import { getSetting } from "../lib/driver-application";
import { completeRide } from "../lib/ride-settlement";

export const driverRideRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;

/** Approved driver, currently in Driver mode. */
const driverMode = async (c: C, next: () => Promise<void>) => {
  if (c.get("user").active_mode !== "driver") return c.json({ status: false, code: "not_in_driver_mode", message: "Switch to Driver mode first." }, 409);
  await next();
};
const mw = [withDb, requireAuth, requireApprovedDriver, driverMode] as const;

const POINT = "extensions.st_setsrid(extensions.st_makepoint(r.pickup_lng, r.pickup_lat), 4326)::extensions.geography";

type Row = Record<string, unknown>;
const request = (r: Row, rule: CommissionRule) => {
  const fare = Number(r.fare);
  const commission = Number(computeCommission(rule, fare));
  const km = Number(r.pickup_m ?? 0) / 1000;
  return {
    id: Number(r.id),
    status: r.status,
    fare,
    commission,
    earning: Math.round((fare - commission) * 100) / 100,
    payment_method: r.payment_method,
    pickup: { lat: r.pickup_lat, lng: r.pickup_lng, address: r.pickup_address },
    dropoff: { lat: r.dropoff_lat, lng: r.dropoff_lng, address: r.dropoff_address },
    distance: Number(r.distance),
    distance_unit: r.distance_unit,
    duration_minutes: Number(r.duration_minutes),
    pickup_distance_km: Math.round(km * 10) / 10,
    pickup_eta_minutes: Math.max(1, Math.round(km * 1.3 * 2)),
    options: r.options,
    rider: { first_name: r.rider_first_name ?? null, contact_number: r.status === "searching" ? null : (r.rider_contact_number ?? null) },
    expires_at: r.expires_at,
    seconds_left: r.expires_at ? Math.max(0, Math.round((new Date(r.expires_at as string).getTime() - Date.now()) / 1000)) : null,
  };
};

/** The driver's open ride (accepted, arrived or in progress), if any. */
async function activeOf(c: C) {
  return (
    await c.get("db").query(
      `select r.*, u.first_name as rider_first_name, u.contact_number as rider_contact_number
         from app.ride_requests r join app.users u on u.id = r.rider_id
        where r.driver_id = $1 and r.status in ('accepted', 'arrived', 'in_progress') order by r.id desc limit 1`,
      [c.get("user").id],
    )
  ).rows[0] as Row | undefined;
}

const ruleOf = async (c: C, serviceId: unknown) =>
  ((await c.get("db").query("select commission_type, admin_commission from app.services where id = $1", [serviceId])).rows[0] ?? { commission_type: null, admin_commission: 0 }) as CommissionRule;

/** What the driver home polls: the open ride, or the nearest searching requests for the driver's ride type. */
driverRideRoutes.get("/driver/requests", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const active = await activeOf(c);
  if (active) return c.json({ status: true, active: request(active, await ruleOf(c, active.service_id)), requests: [] });

  const st = (await db.query("select is_online from app.users where id = $1", [me.id])).rows[0];
  if (!st?.is_online) return c.json({ status: false, code: "not_online", message: "Go online to see ride requests." }, 409);

  const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
  const rows = (
    await db.query(
      `select r.*, u.first_name as rider_first_name, extensions.st_distance(du.location, ${POINT}) as pickup_m
         from app.ride_requests r
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
  return c.json({ status: true, active: null, requests: rows.map((r) => request(r, rule)) });
});

/** First driver to accept wins: one atomic update decides, everyone else gets 'no longer available'. */
driverRideRoutes.post("/driver/requests/:id/accept", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ status: false, code: "request_gone", message: "This request is no longer available." }, 404);

  const u = (await db.query("select u.is_online, p.service_id from app.users u join app.driver_profiles p on p.user_id = u.id where u.id = $1", [me.id])).rows[0];
  if (!u?.is_online) return c.json({ status: false, code: "not_online", message: "Go online to accept rides." }, 409);
  const block = await driverOnlineBlock(db, me.id, u.service_id);
  if (block) return c.json({ status: false, ...block }, 403);

  try {
    await db.query("begin");
    const r = await db.query(
      `update app.ride_requests r set status = 'accepted', driver_id = $1, accepted_at = now()
        where r.id = $2 and r.status = 'searching' and r.expires_at > now() and r.rider_id <> $1 and r.service_id = $3 returning r.id`,
      [me.id, id, u.service_id],
    );
    if (!r.rowCount) {
      await db.query("rollback");
      return c.json({ status: false, code: "request_gone", message: "This request is no longer available." }, 409);
    }
    await db.query("update app.users set is_available = false where id = $1", [me.id]);
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => {});
    if ((e as { code?: string }).code === "23505") return c.json({ status: false, code: "already_on_ride", message: "Finish your current ride first." }, 409);
    throw e;
  }
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? request(active, await ruleOf(c, active.service_id)) : null });
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
  const r = await c.get("db").query(
    `update app.ride_requests set status = $3, ${stamp} = now() where id = $1 and driver_id = $2 and status = $4 returning id`,
    [idOf(c), c.get("user").id, to, from],
  );
  if (!r.rowCount) return notYours(c);
  const active = await activeOf(c);
  return c.json({ status: true, data: active ? request(active, await ruleOf(c, active.service_id)) : null });
}

/** Driver is at the pickup point. */
driverRideRoutes.post("/driver/rides/:id/arrived", ...mw, (c) => step(c, "accepted", "arrived", "arrived_at"));
/** Passenger is in the car: trip starts. */
driverRideRoutes.post("/driver/rides/:id/start", ...mw, (c) => step(c, "arrived", "in_progress", "started_at"));

/** Trip finished: pays the driver / takes commission and frees the driver for the next request. */
driverRideRoutes.post("/driver/rides/:id/complete", ...mw, async (c) => {
  const done = await completeRide(c.get("db"), idOf(c), c.get("user").id);
  if (!done) return notYours(c);
  return c.json({ status: true, data: { id: Number(done.id), status: done.status, fare: Number(done.fare), commission: Number(done.commission), earning: Math.round((Number(done.fare) - Number(done.commission)) * 100) / 100, paid_with: done.paid_with, collect_cash: done.paid_with === "cash" } });
});

/** Driver backs out before the trip starts: the request goes back to other drivers (not this one). No fee for the passenger. */
driverRideRoutes.post("/driver/rides/:id/cancel", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user").id;
  await db.query("begin");
  try {
    const r = await db.query(
      `update app.ride_requests set status = 'searching', driver_id = null, accepted_at = null, arrived_at = null,
              expires_at = now() + make_interval(secs => $3::int)
        where id = $1 and driver_id = $2 and status in ('accepted', 'arrived') returning id`,
      [idOf(c), me, await getSetting(db, "ride_request_expiry_seconds", 120)],
    );
    if (!r.rowCount) { await db.query("rollback"); return notYours(c); }
    await db.query("insert into app.ride_request_declines (request_id, driver_id) values ($1, $2) on conflict do nothing", [idOf(c), me]);
    await db.query("update app.users set is_available = true where id = $1", [me]);
    await db.query("commit");
  } catch (e) { await db.query("rollback").catch(() => {}); throw e; }
  return c.json({ status: true });
});

/** The driver's finished trips with what they earned. */
driverRideRoutes.get("/driver/rides/history", ...mw, async (c) => {
  const rows = (await c.get("db").query(
    `select id, status, fare, commission, paid_with, pickup_address, dropoff_address, distance, distance_unit, completed_at, cancellation_fee
       from app.ride_requests where driver_id = $1 and status = 'completed' order by id desc limit 50`, [c.get("user").id])).rows;
  return c.json({ status: true, data: rows.map((r) => ({ ...r, id: Number(r.id), fare: Number(r.fare), commission: Number(r.commission), earning: Math.round((Number(r.fare) - Number(r.commission)) * 100) / 100 })) });
});
