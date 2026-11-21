import { Hono, type Context } from "hono";
import { z } from "zod";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireWebOrBearer } from "../auth/web-or-bearer";
import { readBody, validationFailed } from "../lib/legacy";
import { currencyInfo, userCurrency } from "../lib/currency";
import { quoteRide } from "../lib/ride-pricing";
import { computeFare } from "../lib/fare";
import { computeCommission, type CommissionRule } from "../lib/commission";
import { getSetting } from "../lib/driver-application";
import { driverOnlineBlock, requireApprovedDriver } from "../lib/roles";
import { issuePickupCode } from "../lib/pickup";
import { pushLater } from "../lib/push";
import { photoUrl } from "../serializers/user";
import { guard, audit } from "../lib/permissions";
import {
  LIVE, SELECTABLE, biddingSettings, checkOffer, limitsFor, logEvent, normalizeSettings,
  pushBidEvent, pushNewBid, round2, transition, type Action, type BidSettings, type RespStatus,
} from "../lib/bidding";

export const rideBidRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
type Row = Record<string, unknown>;

const OPEN_RIDE = ["searching", "accepted", "arrived", "in_progress"];

const passengerOnly = async (c: C, next: () => Promise<void>) => {
  const me = c.get("user");
  if (me.user_type !== "rider" && me.user_type !== "driver") return c.json({ message: "Forbidden" }, 403);
  if (me.active_mode !== "rider") return c.json({ status: false, code: "not_in_passenger_mode", message: "Switch to Passenger mode to bid for a ride." }, 409);
  await next();
};
const driverMode = async (c: C, next: () => Promise<void>) => {
  if (c.get("user").active_mode !== "driver") return c.json({ status: false, code: "not_in_driver_mode", message: "Switch to Driver mode first." }, 409);
  await next();
};
const riderMw = [withDb, requireWebOrBearer, passengerOnly] as const;
const driverMw = [withDb, requireWebOrBearer, requireApprovedDriver, driverMode] as const;

const fail = (c: C, status: 400 | 403 | 404 | 409 | 410 | 422 | 429, code: string, message: string, extra: Record<string, unknown> = {}) =>
  c.json({ status: false, code, message, ...extra }, status);

const point = z.object({
  lat: z.coerce.number({ error: "The latitude is required." }).min(-90).max(90),
  lng: z.coerce.number({ error: "The longitude is required." }).min(-180).max(180),
  address: z.string().trim().max(300).optional(),
});
const createSchema = z.object({
  pickup: point, dropoff: point, stops: z.array(point).max(20).default([]),
  service_id: z.coerce.number().int().positive({ error: "Choose a ride type." }),
  payment_method: z.enum(["cash", "wallet", "card", "virtual_account"], { error: "Choose how you will pay." }),
  option_ids: z.array(z.coerce.number().int().positive()).max(20).default([]),
  offer: z.union([z.number(), z.string()]),
  client_key: z.string().trim().min(8).max(64).optional(),
});

const idParam = (c: C, name = "id") => {
  const n = Number(c.req.param(name));
  return Number.isInteger(n) && n > 0 ? n : 0;
};
const secondsLeft = (t: unknown) => (t ? Math.max(0, Math.round((new Date(t as string).getTime() - Date.now()) / 1000)) : null);

/** Runs `fn` in one transaction and rolls back on any error. */
async function tx<T>(db: Client, fn: () => Promise<T>): Promise<T> {
  await db.query("begin");
  try { const r = await fn(); await db.query("commit"); return r; }
  catch (e) { await db.query("rollback").catch(() => undefined); throw e; }
}

/* ------------------------------------------------------------------------------------------------
 * Views
 * ---------------------------------------------------------------------------------------------- */

const limitsOfBid = (s: BidSettings, b: Row) => limitsFor(s, Number(b.estimate_fare), b.region_id == null ? null : Number(b.region_id), Number(b.service_id));

function responseView(r: Row, s: BidSettings, bid: Row, limits: ReturnType<typeof limitsFor>) {
  const status = r.status as RespStatus;
  const live = LIVE.includes(status);
  const roundsLeft = Math.max(0, s.max_rounds - Number(r.rounds));
  const km = r.dist_m == null ? null : Math.round((Number(r.dist_m) / 1000) * 10) / 10;
  return {
    id: Number(r.id),
    status,
    amount: Number(r.amount),
    rounds: Number(r.rounds),
    rounds_left: roundsLeft,
    expires_at: r.expires_at,
    seconds_left: secondsLeft(r.expires_at),
    selectable: SELECTABLE.includes(status) && new Date(r.expires_at as string).getTime() > Date.now(),
    can_accept: status === "counteroffered",
    can_reject: live && status !== "rider_revised",
    can_revise: status === "counteroffered" && roundsLeft > 0 && limits.enabled,
    waiting_on: status === "rider_revised" ? "driver" : live ? "rider" : null,
    driver: {
      id: Number(r.driver_id),
      name: [r.first_name, r.last_name].filter(Boolean).join(" "),
      profile_image: photoUrl({ id: r.driver_id, profile_image_key: r.profile_image_key }),
      rating: r.rating == null ? null : Number(r.rating),
      rating_count: Number(r.rating_count ?? 0),
      completed_rides: Number(r.completed ?? 0),
      vehicle: { type: r.service_name ?? null, make: r.vehicle_make ?? null, model: r.vehicle_model ?? null, colour: r.vehicle_colour ?? null, plate: r.vehicle_plate ?? null },
      distance_km: km,
      eta_minutes: km == null ? null : Math.max(1, Math.round(km * 1.3 * 2)),
    },
  };
}

/** The passenger's whole picture of one bid: the offer, every live driver response, and the negotiation history. */
async function riderBidView(db: Client, bidId: number, riderId: number) {
  const b = (await db.query("select * from app.ride_bids where id = $1 and rider_id = $2", [bidId, riderId])).rows[0] as Row | undefined;
  if (!b) return null;
  const s = await biddingSettings(db);
  const limits = limitsOfBid(s, b);
  // A bid past its time reads as expired straight away; the minute sweep only tidies the database up afterwards.
  const open = b.status === "open" && new Date(b.expires_at as string).getTime() > Date.now();
  const shownStatus = b.status === "open" && !open ? "expired" : b.status;
  const rows = (await db.query(
    `select r.*, u.first_name, u.last_name, u.profile_image_key, p.vehicle_make, p.vehicle_model, p.vehicle_colour, p.vehicle_plate, sv.name as service_name,
            extensions.st_distance(u.location, extensions.st_setsrid(extensions.st_makepoint($3, $2), 4326)::extensions.geography) as dist_m,
            (select round(avg(rating)::numeric, 1) from app.ride_ratings where driver_id = r.driver_id) as rating,
            (select count(*)::int from app.ride_ratings where driver_id = r.driver_id) as rating_count,
            (select count(*)::int from app.ride_requests where driver_id = r.driver_id and status = 'completed') as completed
       from app.ride_bid_responses r
       join app.users u on u.id = r.driver_id
       left join app.driver_profiles p on p.user_id = r.driver_id
       left join app.services sv on sv.id = p.service_id
      where r.bid_id = $1 and r.status = any($4)
      order by r.amount asc, r.id asc`,
    [bidId, b.pickup_lat, b.pickup_lng, open ? LIVE : [...LIVE, "selected"]],
  )).rows;
  const declined = Number((await db.query("select count(*)::int as n from app.ride_bid_responses where bid_id = $1 and status in ('declined')", [bidId])).rows[0].n);
  const history = (await db.query("select id, response_id, actor_role, action, amount, note, created_at from app.ride_bid_events where bid_id = $1 order by id", [bidId])).rows
    .map((e) => ({ id: Number(e.id), response_id: e.response_id == null ? null : Number(e.response_id), by: e.actor_role, action: e.action, amount: e.amount == null ? null : Number(e.amount), note: e.note, at: e.created_at }));
  return {
    id: Number(b.id),
    status: shownStatus,
    close_reason: b.close_reason ?? (shownStatus === "expired" ? "timeout" : null),
    service_id: Number(b.service_id),
    currency: currencyInfo(b.currency as string),
    pickup: { lat: b.pickup_lat, lng: b.pickup_lng, address: b.pickup_address },
    dropoff: { lat: b.dropoff_lat, lng: b.dropoff_lng, address: b.dropoff_address },
    stops: Array.isArray(b.stops) ? b.stops : [],
    distance: Number(b.distance),
    distance_unit: b.distance_unit,
    duration_minutes: Number(b.duration_minutes),
    payment_method: b.payment_method,
    estimate_fare: Number(b.estimate_fare),
    offer_fare: Number(b.offer_fare),
    agreed_fare: b.agreed_fare == null ? null : Number(b.agreed_fare),
    ride_request_id: b.ride_request_id == null ? null : Number(b.ride_request_id),
    limits: { min: limits.min, max: limits.max },
    max_rounds: s.max_rounds,
    rounds_used: Number(b.rounds_used),
    can_revise: open && Number(b.rounds_used) < s.max_rounds && limits.enabled,
    expires_at: b.expires_at,
    seconds_left: open ? secondsLeft(b.expires_at) : 0,
    created_at: b.created_at,
    declined_count: declined,
    responses: rows.map((r) => responseView(r, s, b, limits)),
    history,
  };
}

const ruleOf = async (db: Client, serviceId: unknown) =>
  ((await db.query("select commission_type, admin_commission from app.services where id = $1", [serviceId])).rows[0] ?? { commission_type: null, admin_commission: 0 }) as CommissionRule;

/**
 * Open bids this driver may answer, plus every negotiation they are already part of.
 * Eligibility reuses the standard-request rules (online, free, right ride type, inside the pickup radius) plus "passenger bids" being ON.
 * A driver who switched bids OFF still sees threads they already started, so an agreement is never silently dropped.
 */
export async function driverBidList(db: Client, driverId: number): Promise<Row[]> {
  const s = await biddingSettings(db);
  if (!s.enabled) return [];
  const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
  const rows = (await db.query(
    `select b.*, u.first_name as rider_first_name,
            extensions.st_distance(du.location, extensions.st_setsrid(extensions.st_makepoint(b.pickup_lng, b.pickup_lat), 4326)::extensions.geography) as pickup_m,
            (select count(*)::int from app.ride_requests where rider_id = b.rider_id and status = 'completed') as rider_trips,
            rr.id as r_id, rr.status as r_status, rr.amount as r_amount, rr.rounds as r_rounds, rr.expires_at as r_expires_at
       from app.ride_bids b
       join app.users u on u.id = b.rider_id
       join app.users du on du.id = $1
       join app.driver_profiles p on p.user_id = $1
       left join app.ride_bid_responses rr on rr.bid_id = b.id and rr.driver_id = $1
      where b.status = 'open' and b.expires_at > now() and b.service_id = p.service_id and b.rider_id <> $1
        and ((rr.id is null and p.accepts_bids and du.is_online and du.location is not null
              and extensions.st_dwithin(du.location, extensions.st_setsrid(extensions.st_makepoint(b.pickup_lng, b.pickup_lat), 4326)::extensions.geography, $2))
             or rr.status = any($3))
      order by pickup_m limit 10`, [driverId, radius, LIVE])).rows;
  const rule = rows.length ? await ruleOf(db, rows[0].service_id) : { commission_type: null, admin_commission: 0 };
  return rows.map((b) => {
    const limits = limitsOfBid(s, b);
    const km = Number(b.pickup_m ?? 0) / 1000;
    const status = (b.r_status ?? null) as RespStatus | null;
    const current = status ? Number(b.r_amount) : Number(b.offer_fare);
    const commission = Number(computeCommission(rule, current));
    const roundsLeft = Math.max(0, s.max_rounds - Number(b.r_rounds ?? 0));
    return {
      id: Number(b.id),
      currency: currencyInfo(b.currency as string),
      offer_fare: Number(b.offer_fare),
      estimate_fare: Number(b.estimate_fare),
      pickup: { lat: b.pickup_lat, lng: b.pickup_lng, address: b.pickup_address },
      dropoff: { lat: b.dropoff_lat, lng: b.dropoff_lng, address: b.dropoff_address },
      stops: Array.isArray(b.stops) ? b.stops : [],
      distance: Number(b.distance),
      distance_unit: b.distance_unit,
      duration_minutes: Number(b.duration_minutes),
      pickup_distance_km: Math.round(km * 10) / 10,
      pickup_eta_minutes: Math.max(1, Math.round(km * 1.3 * 2)),
      payment_method: b.payment_method,
      options: b.options,
      rider: { first_name: b.rider_first_name ?? null, completed_trips: Number(b.rider_trips ?? 0) },
      limits: { min: limits.min, max: limits.max },
      commission,
      earning: round2(current - commission),
      expires_at: b.expires_at,
      seconds_left: secondsLeft(b.expires_at),
      thread: status ? {
        id: Number(b.r_id), status, amount: Number(b.r_amount), rounds: Number(b.r_rounds), rounds_left: roundsLeft,
        expires_at: b.r_expires_at, seconds_left: secondsLeft(b.r_expires_at),
        my_turn: status === "rider_revised",
        can_counter: roundsLeft > 0 && limits.enabled && (status === "rider_revised"),
      } : null,
      can_counter: !status && limits.enabled && s.max_rounds > 0,
    };
  });
}

/* ------------------------------------------------------------------------------------------------
 * Passenger: create and read
 * ---------------------------------------------------------------------------------------------- */

/** Limits for the booking screen, per ride type, so the app can show the allowed range before the passenger types anything. */
export async function biddingForEstimate(db: Client, regionId: number, rideTypes: { id: number; fare: number }[]) {
  const s = await biddingSettings(db);
  return {
    enabled: s.enabled,
    max_rounds: s.max_rounds,
    bid_expiry_seconds: s.bid_expiry_seconds,
    per_type: Object.fromEntries(rideTypes.map((t) => {
      const l = limitsFor(s, t.fare, regionId, t.id);
      return [String(t.id), { enabled: l.enabled, min: l.min, max: l.max, reason: l.reason ?? null }];
    })),
  };
}

rideBidRoutes.post("/ride/bids", ...riderMw, async (c) => {
  const p = createSchema.safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { bid: [p.error.issues[0].message] });
  const db = c.get("db");
  const me = c.get("user");
  const s = await biddingSettings(db);
  if (!s.enabled) return fail(c, 403, "bidding_disabled", "Fare bidding is not available right now. You can book a standard ride.");

  await db.query("update app.ride_bids set status = 'expired', close_reason = 'timeout', closed_at = now() where rider_id = $1 and status = 'open' and expires_at < now()", [me.id]);

  if (p.data.client_key) {
    const same = (await db.query("select id from app.ride_bids where rider_id = $1 and client_key = $2", [me.id, p.data.client_key])).rows[0];
    if (same) return c.json({ status: true, data: await riderBidView(db, Number(same.id), me.id), duplicate: true });
  }
  await db.query("update app.ride_requests set status = 'expired' where rider_id = $1 and status = 'searching' and expires_at < now()", [me.id]);
  if ((await db.query("select 1 from app.ride_requests where rider_id = $1 and status = any($2) limit 1", [me.id, OPEN_RIDE])).rowCount)
    return fail(c, 409, "already_has_ride", "You already have a ride in progress.");
  const live = Number((await db.query("select count(*)::int as n from app.ride_bids where rider_id = $1 and status = 'open'", [me.id])).rows[0].n);
  if (live >= s.max_active_bids) return fail(c, 409, "bid_in_progress", "You already have a bid open. Cancel it first or wait for it to finish.");
  const hour = Number((await db.query("select count(*)::int as n from app.ride_bids where rider_id = $1 and created_at > now() - interval '1 hour'", [me.id])).rows[0].n);
  if (hour >= s.max_bids_per_hour) return fail(c, 429, "bid_rate_limited", "You have sent a lot of bids. Please wait a little before trying again.");
  const cancelled = Number((await db.query("select count(*)::int as n from app.ride_bids where rider_id = $1 and status = 'cancelled' and created_at > now() - interval '1 day'", [me.id])).rows[0].n);
  if (cancelled >= s.max_cancelled_per_day) return fail(c, 429, "bid_cancel_limit", "Too many cancelled bids today. Please book a standard ride or try again later.");

  const maxStops = Math.max(0, Math.min(20, await getSetting(db, "ride_max_additional_stops", 3)));
  if (p.data.stops.length > maxStops) return validationFailed(c, { stops: [`You can add up to ${maxStops} additional stop(s) to this trip.`] });
  const q = await quoteRide(db, c.env, p.data.pickup, p.data.dropoff, p.data.stops);
  if (!q.ok) return c.json({ status: false, code: q.code, message: q.message }, 422);
  const type = q.ride_types.find((t) => t.id === p.data.service_id);
  if (!type) return fail(c, 422, "ride_type_unavailable", "That ride type is not available for this trip right now.");
  if (!type.payment_methods.includes(p.data.payment_method)) return validationFailed(c, { payment_method: ["That payment method is not available for this ride type."] });

  const chosen = [...new Set(p.data.option_ids)].map((id) => q.options.find((o) => o.id === id));
  if (chosen.some((o) => !o)) return validationFailed(c, { option_ids: ["One of the extras is not available."] });
  const options = chosen as { id: number; name: string; price: number }[];
  const svc = (await db.query("select base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive from app.services where id = $1", [type.id])).rows[0];
  const estimate = computeFare(svc, q.distance, q.route.duration_minutes, options.reduce((a, o) => a + o.price, 0)).total;

  const limits = limitsFor(s, estimate, q.region.id, type.id);
  if (!limits.enabled) return fail(c, 422, "bidding_unavailable", limits.reason ?? "Bidding is not available for this trip.");
  const offer = checkOffer(p.data.offer, limits, q.region.currency);
  if (!offer.ok) return fail(c, 422, offer.code, offer.message, { limits: { min: limits.min, max: limits.max } });

  if (p.data.payment_method === "wallet") {
    if ((await userCurrency(db, me.id)) !== q.region.currency) return fail(c, 422, "wallet_currency", `Your wallet is in ${await userCurrency(db, me.id)}, but this ride is priced in ${q.region.currency}. Choose cash.`);
    const bal = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [me.id])).rows[0]?.balance ?? 0);
    if (bal < offer.amount) return fail(c, 422, "insufficient_wallet", `Your wallet balance is too low for this offer. Offer ${offer.amount}, balance ${bal}.`);
  }

  let bidId = 0;
  try {
    bidId = await tx(db, async () => {
      const ins = await db.query(
        `insert into app.ride_bids (rider_id, service_id, region_id, pickup_lat, pickup_lng, pickup_address, dropoff_lat, dropoff_lng, dropoff_address, stops,
                distance, distance_unit, duration_minutes, route_source, currency, payment_method, options, estimate_fare, offer_fare, client_key, expires_at)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20, now() + make_interval(secs => $21)) returning id`,
        [me.id, type.id, q.region.id, p.data.pickup.lat, p.data.pickup.lng, p.data.pickup.address ?? null, p.data.dropoff.lat, p.data.dropoff.lng, p.data.dropoff.address ?? null,
          JSON.stringify(p.data.stops.map((x) => ({ lat: x.lat, lng: x.lng, address: x.address ?? null }))),
          q.distance, q.region.distance_unit, q.route.duration_minutes, q.route.source, q.region.currency, p.data.payment_method, JSON.stringify(options),
          estimate, offer.amount, p.data.client_key ?? null, s.bid_expiry_seconds],
      );
      const id = Number(ins.rows[0].id);
      await logEvent(db, id, null, "rider", me.id, "offered", offer.amount);
      return id;
    });
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return fail(c, 409, "bid_in_progress", "You already sent this bid.");
    throw e;
  }
  pushLater(c, pushNewBid(db, c.env, bidId));
  return c.json({ status: true, data: await riderBidView(db, bidId, me.id) }, 201);
});

/** The passenger's open bid, if any. */
rideBidRoutes.get("/ride/bids/current", ...riderMw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const b = (await db.query("select id from app.ride_bids where rider_id = $1 and status = 'open' and expires_at > now() order by id desc limit 1", [me.id])).rows[0];
  return c.json({ status: true, data: b ? await riderBidView(db, Number(b.id), me.id) : null });
});

/** One bid by id. Someone else's bid looks exactly like a bid that does not exist. */
rideBidRoutes.get("/ride/bids/:id", ...riderMw, async (c) => {
  const id = idParam(c);
  const v = id ? await riderBidView(c.get("db"), id, c.get("user").id) : null;
  return v ? c.json({ status: true, data: v }) : fail(c, 404, "bid_not_found", "Bid not found.");
});

/* ------------------------------------------------------------------------------------------------
 * Passenger: actions. Each one locks the bid row first, so two taps, two phones or a replay can never both win.
 * ---------------------------------------------------------------------------------------------- */

type Locked = { bid: Row; s: BidSettings };
class Stop extends Error { constructor(public res: { status: 403 | 404 | 409 | 410 | 422 | 429; code: string; message: string; extra?: Record<string, unknown> }) { super(res.code); } }
const stop = (status: 403 | 404 | 409 | 410 | 422 | 429, code: string, message: string, extra?: Record<string, unknown>) => new Stop({ status, code, message, extra });

/** Locks the passenger's own bid and insists it is still open. */
async function lockOpenBid(db: Client, bidId: number, riderId: number): Promise<Locked> {
  const bid = (await db.query("select * from app.ride_bids where id = $1 and rider_id = $2 for update", [bidId, riderId])).rows[0] as Row | undefined;
  if (!bid) throw stop(404, "bid_not_found", "Bid not found.");
  if (bid.status !== "open") throw stop(409, "bid_closed", bid.status === "confirmed" ? "This bid already has a driver." : "This bid is closed.");
  if (new Date(bid.expires_at as string).getTime() <= Date.now()) throw stop(410, "bid_expired", "This bid has expired. You can try again or book a standard ride.");
  return { bid, s: await biddingSettings(db) };
}

async function lockThread(db: Client, bidId: number, responseId: number): Promise<Row> {
  const r = (await db.query("select * from app.ride_bid_responses where id = $1 and bid_id = $2 for update", [responseId, bidId])).rows[0] as Row | undefined;
  if (!r) throw stop(404, "response_not_found", "That driver response was not found.");
  return r;
}

function expectMove(r: Row, action: Action): RespStatus {
  const to = transition(r.status as RespStatus, action);
  if (!to) throw stop(409, "wrong_state", "That response has changed. Please check again.");
  if (new Date(r.expires_at as string).getTime() <= Date.now() && LIVE.includes(r.status as RespStatus))
    throw stop(410, "offer_expired", "That offer has expired.");
  return to;
}

function guarded(c: C, fn: () => Promise<Response>) {
  return fn().catch((e) => {
    if (e instanceof Stop) return fail(c, e.res.status, e.res.code, e.res.message, e.res.extra ?? {});
    throw e;
  });
}

/** Cancel the bid. Drivers who were negotiating are told. */
rideBidRoutes.post("/ride/bids/:id/cancel", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c);
  const notify = await tx(db, async () => {
    const { bid } = await lockOpenBid(db, id, me.id);
    await db.query("update app.ride_bids set status = 'cancelled', close_reason = 'cancelled_by_rider', closed_at = now() where id = $1", [bid.id]);
    const ds = (await db.query("update app.ride_bid_responses set status = 'lost' where bid_id = $1 and status = any($2) returning driver_id", [bid.id, LIVE])).rows;
    await logEvent(db, id, null, "rider", me.id, "cancelled");
    return ds.map((d) => Number(d.driver_id));
  });
  pushLater(c, pushBidEvent(db, c.env, notify, "bid_cancelled", id));
  return c.json({ status: true, data: await riderBidView(db, id, me.id) });
}));

/** Raise or lower the whole bid (counts as one revision). Drivers who have not answered are told. */
rideBidRoutes.post("/ride/bids/:id/revise", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c);
  const body = await readBody(c);
  await tx(db, async () => {
    const { bid, s } = await lockOpenBid(db, id, me.id);
    if (Number(bid.rounds_used) >= s.max_rounds) throw stop(422, "rounds_exhausted", `You can change your offer up to ${s.max_rounds} time(s). Pick a driver or start a new bid.`);
    const limits = limitsOfBid(s, bid);
    if (!limits.enabled) throw stop(422, "bidding_unavailable", limits.reason ?? "Bidding is not available for this trip.");
    const offer = checkOffer(body.offer ?? body.amount, limits, String(bid.currency));
    if (!offer.ok) throw stop(422, offer.code, offer.message, { limits: { min: limits.min, max: limits.max } });
    if (offer.amount === Number(bid.offer_fare)) throw stop(422, "same_offer", "That is the same offer you already made.");
    await db.query("update app.ride_bids set offer_fare = $2, rounds_used = rounds_used + 1, expires_at = now() + make_interval(secs => $3) where id = $1", [id, offer.amount, s.bid_expiry_seconds]);
    await logEvent(db, id, null, "rider", me.id, "bid_revised", offer.amount);
    return { amount: offer.amount, currency: bid.currency };
  });
  pushLater(c, pushNewBid(db, c.env, id, "bid_raised"));
  return c.json({ status: true, data: await riderBidView(db, id, me.id) });
}));

/** Accept a driver's counteroffer. This agrees the fare; the passenger still has to pick the driver. */
rideBidRoutes.post("/ride/bids/:id/responses/:rid/accept", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c), rid = idParam(c, "rid");
  const driverId = await tx(db, async () => {
    const { s } = await lockOpenBid(db, id, me.id);
    const r = await lockThread(db, id, rid);
    const to = expectMove(r, "rider_accept");
    await db.query("update app.ride_bid_responses set status = $2, expires_at = now() + make_interval(secs => $3) where id = $1", [rid, to, s.offer_expiry_seconds]);
    await logEvent(db, id, rid, "rider", me.id, "counter_accepted", Number(r.amount));
    return { driver: Number(r.driver_id), amount: Number(r.amount) };
  });
  const b = (await db.query("select currency from app.ride_bids where id = $1", [id])).rows[0];
  pushLater(c, pushBidEvent(db, c.env, [driverId.driver], "rider_accepted_counter", id, { amount: driverId.amount, currency: b.currency }));
  return c.json({ status: true, data: await riderBidView(db, id, me.id) });
}));

rideBidRoutes.post("/ride/bids/:id/responses/:rid/reject", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c), rid = idParam(c, "rid");
  const driver = await tx(db, async () => {
    await lockOpenBid(db, id, me.id);
    const r = await lockThread(db, id, rid);
    const to = expectMove(r, "rider_reject");
    await db.query("update app.ride_bid_responses set status = $2 where id = $1", [rid, to]);
    await logEvent(db, id, rid, "rider", me.id, "response_rejected", Number(r.amount));
    return Number(r.driver_id);
  });
  pushLater(c, pushBidEvent(db, c.env, [driver], "counter_rejected", id));
  return c.json({ status: true, data: await riderBidView(db, id, me.id) });
}));

/** Counter one driver's counteroffer with the passenger's own number. */
rideBidRoutes.post("/ride/bids/:id/responses/:rid/revise", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c), rid = idParam(c, "rid");
  const body = await readBody(c);
  const out = await tx(db, async () => {
    const { bid, s } = await lockOpenBid(db, id, me.id);
    const r = await lockThread(db, id, rid);
    const to = expectMove(r, "rider_revise");
    if (Number(r.rounds) >= s.max_rounds) throw stop(422, "rounds_exhausted", `This negotiation allows ${s.max_rounds} counteroffer(s). Accept, reject or pick another driver.`);
    const limits = limitsOfBid(s, bid);
    if (!limits.enabled) throw stop(422, "bidding_unavailable", limits.reason ?? "Bidding is not available for this trip.");
    const offer = checkOffer(body.offer ?? body.amount, limits, String(bid.currency));
    if (!offer.ok) throw stop(422, offer.code, offer.message, { limits: { min: limits.min, max: limits.max } });
    if (offer.amount === Number(r.amount)) throw stop(422, "same_offer", "That is the amount already on the table. Use Accept instead.");
    await db.query("update app.ride_bid_responses set status = $2, amount = $3, rounds = rounds + 1, expires_at = least($5::timestamptz, now() + make_interval(secs => $4)) where id = $1",
      [rid, to, offer.amount, s.offer_expiry_seconds, bid.expires_at]);
    await logEvent(db, id, rid, "rider", me.id, "response_revised", offer.amount);
    return { driver: Number(r.driver_id), amount: offer.amount, currency: bid.currency };
  });
  pushLater(c, pushBidEvent(db, c.env, [out.driver], "rider_revised", id, { amount: out.amount, currency: out.currency }));
  return c.json({ status: true, data: await riderBidView(db, id, me.id) });
}));

/**
 * The passenger picks the driver. One transaction: the bid is locked, the driver is re-checked, the ride is created at the agreed fare,
 * every other response is closed. The existing one-open-ride-per-driver / per-rider indexes are the final word on a race.
 */
rideBidRoutes.post("/ride/bids/:id/select", ...riderMw, (c) => guarded(c, async () => {
  const db = c.get("db"), me = c.get("user"), id = idParam(c);
  const body = await readBody(c);
  const rid = Number(body.response_id);
  if (!Number.isInteger(rid) || rid <= 0) return validationFailed(c, { response_id: ["Choose a driver."] });

  let out: { rideId: number; driver: number; losers: number[]; amount: number; currency: string };
  try {
    out = await tx(db, async () => {
      const { bid } = await lockOpenBid(db, id, me.id);
      const r = await lockThread(db, id, rid);
      const to = expectMove(r, "select");
      const amount = Number(r.amount);
      const driverId = Number(r.driver_id);

      // The driver is checked again right now: online, free, approved, same ride type, wallet and documents in order.
      const d = (await db.query(
        `select u.is_online, u.is_available, u.status as user_status, p.status as profile_status, p.service_id
           from app.users u join app.driver_profiles p on p.user_id = u.id where u.id = $1 for update of u`, [driverId])).rows[0];
      if (!d || !d.is_online || !d.is_available || d.user_status !== "active" || d.profile_status !== "approved" || Number(d.service_id) !== Number(bid.service_id))
        throw stop(409, "driver_unavailable", "That driver is no longer available. Please choose another driver.");
      if (await driverOnlineBlock(db, driverId, Number(bid.service_id))) throw stop(409, "driver_unavailable", "That driver is no longer available. Please choose another driver.");
      if ((await db.query("select 1 from app.ride_requests where driver_id = $1 and status in ('accepted','arrived','in_progress') limit 1", [driverId])).rowCount)
        throw stop(409, "driver_unavailable", "That driver just took another ride. Please choose another driver.");
      if ((await db.query("select 1 from app.ride_requests where rider_id = $1 and status = any($2) limit 1", [me.id, OPEN_RIDE])).rowCount)
        throw stop(409, "already_has_ride", "You already have a ride in progress.");
      if (bid.payment_method === "wallet") {
        if ((await userCurrency(db, me.id)) !== String(bid.currency).trim()) throw stop(422, "wallet_currency", "Your wallet is in a different currency. Choose cash.");
        const bal = Number((await db.query("select balance from app.wallets where user_id = $1 and kind = 'rider'", [me.id])).rows[0]?.balance ?? 0);
        if (bal < amount) throw stop(422, "insufficient_wallet", `Your wallet balance is too low for this fare. Fare ${amount}, balance ${bal}.`);
      }

      const breakdown = {
        negotiated: true, estimate: Number(bid.estimate_fare), original_offer: null as number | null, agreed: amount,
        base_fare: amount, distance_charge: 0, time_charge: 0, options_total: 0, minimum_fare_applied: false, total: amount,
      };
      breakdown.original_offer = Number((await db.query("select amount from app.ride_bid_events where bid_id = $1 and action = 'offered' order by id limit 1", [id])).rows[0]?.amount ?? bid.offer_fare);
      const ride = (await db.query(
        `insert into app.ride_requests (rider_id, driver_id, service_id, region_id, status, accepted_at, pickup_lat, pickup_lng, pickup_address, dropoff_lat, dropoff_lng, dropoff_address,
                distance, distance_unit, duration_minutes, route_source, fare, fare_breakdown, options, payment_method, currency, bid_id)
         values ($1,$2,$3,$4,'accepted', now(), $5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20) returning id`,
        [me.id, driverId, bid.service_id, bid.region_id, bid.pickup_lat, bid.pickup_lng, bid.pickup_address, bid.dropoff_lat, bid.dropoff_lng, bid.dropoff_address,
          bid.distance, bid.distance_unit, bid.duration_minutes, bid.route_source, amount, JSON.stringify(breakdown), JSON.stringify(bid.options ?? []), bid.payment_method, String(bid.currency).trim(), id])).rows[0];
      const rideId = Number(ride.id);
      const stops = Array.isArray(bid.stops) ? (bid.stops as { lat: number; lng: number; address?: string | null }[]) : [];
      for (let i = 0; i < stops.length; i++)
        await db.query("insert into app.ride_request_stops (ride_request_id, sequence, lat, lng, address) values ($1,$2,$3,$4,$5)", [rideId, i + 1, stops[i].lat, stops[i].lng, stops[i].address ?? null]);
      await db.query("update app.users set is_available = false where id = $1", [driverId]);
      await issuePickupCode(db, c.env.SETTINGS_ENCRYPTION_KEY, rideId);

      await db.query("update app.ride_bids set status = 'confirmed', ride_request_id = $2, selected_driver_id = $3, agreed_fare = $4, close_reason = 'driver_selected', closed_at = now() where id = $1", [id, rideId, driverId, amount]);
      await db.query("update app.ride_bid_responses set status = $2 where id = $1", [rid, to]);
      const losers = (await db.query("update app.ride_bid_responses set status = 'lost' where bid_id = $1 and id <> $2 and status = any($3) returning driver_id", [id, rid, LIVE])).rows.map((x) => Number(x.driver_id));
      await logEvent(db, id, rid, "rider", me.id, "driver_selected", amount);
      return { rideId, driver: driverId, losers, amount, currency: String(bid.currency) };
    });
  } catch (e) {
    if ((e as { code?: string }).code === "23505") return fail(c, 409, "driver_unavailable", "That driver just took another ride, or you already have a ride. Please check again.");
    throw e;
  }
  pushLater(c, pushBidEvent(db, c.env, [out.driver], "driver_selected", id, { amount: out.amount, currency: out.currency }));
  pushLater(c, pushBidEvent(db, c.env, out.losers, "selection_lost", id));
  return c.json({ status: true, ride_id: out.rideId, data: await riderBidView(db, id, me.id) });
}));

/* ------------------------------------------------------------------------------------------------
 * Driver
 * ---------------------------------------------------------------------------------------------- */

export async function driverPreferences(db: Client, driverId: number) {
  const p = (await db.query("select accepts_standard, accepts_bids from app.driver_profiles where user_id = $1", [driverId])).rows[0];
  const s = await biddingSettings(db);
  return { accepts_standard: p?.accepts_standard !== false, accepts_bids: p?.accepts_bids === true, bidding_available: s.enabled };
}

rideBidRoutes.get("/driver/preferences", ...driverMw, async (c) => c.json({ status: true, data: await driverPreferences(c.get("db"), c.get("user").id) }));

/** Standard requests and passenger bids are two independent switches. Turning bids off never touches a ride or an agreement already made. */
rideBidRoutes.put("/driver/preferences", ...driverMw, async (c) => {
  const body = await readBody(c);
  const asBool = (v: unknown): boolean | null => (v === true || v === "true" || v === 1 || v === "1" ? true : v === false || v === "false" || v === 0 || v === "0" ? false : null);
  const std = asBool(body.accepts_standard), bids = asBool(body.accepts_bids);
  if (std === null && bids === null) return validationFailed(c, { preferences: ["Nothing to change."] });
  const db = c.get("db");
  await db.query("update app.driver_profiles set accepts_standard = coalesce($2, accepts_standard), accepts_bids = coalesce($3, accepts_bids) where user_id = $1", [c.get("user").id, std, bids]);
  return c.json({ status: true, data: await driverPreferences(db, c.get("user").id) });
});

rideBidRoutes.get("/driver/bids", ...driverMw, async (c) => {
  const db = c.get("db");
  const online = (await db.query("select is_online from app.users where id = $1", [c.get("user").id])).rows[0]?.is_online === true;
  return c.json({ status: true, bids: online ? await driverBidList(db, c.get("user").id) : [], preferences: await driverPreferences(db, c.get("user").id) });
});

/** Can this driver start a NEW negotiation on this bid? Same eligibility as standard requests, plus the bids switch. */
async function mayStartThread(db: Client, driverId: number, bid: Row): Promise<{ ok: true } | { ok: false; code: string; message: string }> {
  const d = (await db.query(
    `select u.is_online, u.is_available, p.service_id, p.accepts_bids,
            (u.location is not null and extensions.st_dwithin(u.location, extensions.st_setsrid(extensions.st_makepoint($2, $3), 4326)::extensions.geography, $4)) as near
       from app.users u join app.driver_profiles p on p.user_id = u.id where u.id = $1`,
    [driverId, bid.pickup_lng, bid.pickup_lat, await getSetting(db, "nearby_driver_radius_m", 5000)])).rows[0];
  if (!d?.is_online) return { ok: false, code: "not_online", message: "Go online to answer bids." };
  if (!d.accepts_bids) return { ok: false, code: "bids_off", message: "Turn on Passenger bids in your settings to answer bids." };
  if (!d.is_available) return { ok: false, code: "already_on_ride", message: "Finish your current ride first." };
  if (Number(d.service_id) !== Number(bid.service_id)) return { ok: false, code: "wrong_ride_type", message: "This bid is for a different ride type." };
  if (!d.near) return { ok: false, code: "too_far", message: "This pickup is too far from you." };
  const block = await driverOnlineBlock(db, driverId, Number(bid.service_id));
  if (block) return { ok: false, code: block.code, message: block.message };
  return { ok: true };
}

async function driverAct(c: C, action: "driver_accept" | "driver_counter" | "driver_decline") {
  const db = c.get("db"), me = c.get("user"), id = idParam(c);
  const body = action === "driver_counter" ? await readBody(c) : {};
  const out = await tx(db, async () => {
    const bid = (await db.query("select * from app.ride_bids where id = $1 for update", [id])).rows[0] as Row | undefined;
    if (!bid || Number(bid.rider_id) === me.id) throw stop(404, "bid_not_found", "This bid is no longer available.");
    if (bid.status !== "open" || new Date(bid.expires_at as string).getTime() <= Date.now()) throw stop(409, "bid_closed", "This bid is no longer available.");
    const s = await biddingSettings(db);
    if (!s.enabled) throw stop(403, "bidding_disabled", "Fare bidding is not available right now.");
    const limits = limitsOfBid(s, bid);
    const t = (await db.query("select * from app.ride_bid_responses where bid_id = $1 and driver_id = $2 for update", [id, me.id])).rows[0] as Row | undefined;

    if (action !== "driver_decline") {
      if (!limits.enabled) throw stop(422, "bidding_unavailable", limits.reason ?? "Bidding is not available for this trip.");
      const me2 = (await db.query("select u.is_online from app.users u where u.id = $1", [me.id])).rows[0];
      if (!me2?.is_online) throw stop(409, "not_online", "Go online to answer bids.");
      if ((await db.query("select 1 from app.ride_requests where driver_id = $1 and status in ('accepted','arrived','in_progress') limit 1", [me.id])).rowCount)
        throw stop(409, "already_on_ride", "Finish your current ride first.");
    }
    const when = s.offer_expiry_seconds;

    if (!t) {
      // A first answer. Declining needs no eligibility (it just hides the bid); accepting or countering does.
      if (action !== "driver_decline") {
        const may = await mayStartThread(db, me.id, bid);
        if (!may.ok) throw stop(403, may.code, may.message);
      }
      const to = transition(null, action)!;
      let amount = Number(bid.offer_fare);
      let rounds = 0;
      if (action === "driver_counter") {
        const offer = checkOffer(body.amount ?? body.offer, limits, String(bid.currency));
        if (!offer.ok) throw stop(422, offer.code, offer.message, { limits: { min: limits.min, max: limits.max } });
        if (offer.amount === amount) throw stop(422, "same_offer", "That is the passenger's offer already. Use Accept.");
        amount = offer.amount; rounds = 1;
      }
      const ins = (await db.query(
        `insert into app.ride_bid_responses (bid_id, driver_id, status, amount, rounds, expires_at, pickup_m)
         values ($1,$2,$3,$4,$5, least($6::timestamptz, now() + make_interval(secs => $7)),
                 (select extensions.st_distance(du.location, extensions.st_setsrid(extensions.st_makepoint($8, $9), 4326)::extensions.geography) from app.users du where du.id = $2))
         on conflict (bid_id, driver_id) do nothing returning id`,
        [id, me.id, to, amount, rounds, bid.expires_at, when, bid.pickup_lng, bid.pickup_lat])).rows[0];
      if (!ins) throw stop(409, "already_responded", "You already answered this bid.");
      await logEvent(db, id, Number(ins.id), "driver", me.id, action === "driver_accept" ? "driver_accepted" : action === "driver_counter" ? "driver_countered" : "driver_declined", action === "driver_decline" ? null : amount);
      return { to, amount, currency: bid.currency, rider: Number(bid.rider_id), hidden: action === "driver_decline" };
    }

    // A thread already exists: the state machine decides what may happen next.
    const to = expectMove(t, action);
    let amount = Number(t.amount);
    let rounds = Number(t.rounds);
    if (action === "driver_counter") {
      if (rounds >= s.max_rounds) throw stop(422, "rounds_exhausted", `This negotiation allows ${s.max_rounds} counteroffer(s). Accept or decline.`);
      const offer = checkOffer(body.amount ?? body.offer, limits, String(bid.currency));
      if (!offer.ok) throw stop(422, offer.code, offer.message, { limits: { min: limits.min, max: limits.max } });
      if (offer.amount === amount) throw stop(422, "same_offer", "That is the amount already on the table. Use Accept.");
      amount = offer.amount; rounds += 1;
    }
    await db.query("update app.ride_bid_responses set status = $2, amount = $3, rounds = $4, expires_at = least($5::timestamptz, now() + make_interval(secs => $6)) where id = $1",
      [t.id, to, amount, rounds, bid.expires_at, s.offer_expiry_seconds]);
    await logEvent(db, id, Number(t.id), "driver", me.id, action === "driver_accept" ? "driver_accepted" : action === "driver_counter" ? "driver_countered" : "driver_declined", action === "driver_decline" ? null : amount);
    return { to, amount, currency: bid.currency, rider: Number(bid.rider_id), hidden: action === "driver_decline", withdrew: action === "driver_decline" };
  });
  if (!out.hidden) pushLater(c, pushBidEvent(c.get("db"), c.env, [out.rider], action === "driver_accept" ? "driver_accepted" : "driver_counteroffered", id, { amount: out.amount, currency: out.currency }));
  else if ((out as { withdrew?: boolean }).withdrew) pushLater(c, pushBidEvent(c.get("db"), c.env, [out.rider], "driver_withdrew", id));
  return c.json({ status: true, bids: await driverBidList(db, me.id) });
}

rideBidRoutes.post("/driver/bids/:id/accept", ...driverMw, (c) => guarded(c, () => driverAct(c, "driver_accept")));
rideBidRoutes.post("/driver/bids/:id/counter", ...driverMw, (c) => guarded(c, () => driverAct(c, "driver_counter")));
rideBidRoutes.post("/driver/bids/:id/decline", ...driverMw, (c) => guarded(c, () => driverAct(c, "driver_decline")));

/* ------------------------------------------------------------------------------------------------
 * Admin: settings and analytics. Admin only, permission "ride_bid".
 * ---------------------------------------------------------------------------------------------- */

rideBidRoutes.get("/admin/bid-settings", ...guard("ride_bid list"), async (c) => {
  const db = c.get("db");
  const regions = (await db.query("select id, name from app.regions where status order by id")).rows.map((r) => ({ id: Number(r.id), name: r.name }));
  const services = (await db.query("select id, name, region_id from app.services where deleted_at is null order by sort_order, id")).rows.map((r) => ({ id: Number(r.id), name: r.name, region_id: r.region_id == null ? null : Number(r.region_id) }));
  return c.json({ status: true, data: await biddingSettings(db), regions, services });
});

rideBidRoutes.put("/admin/bid-settings", ...guard("ride_bid edit"), async (c) => {
  const body = await readBody(c);
  const next = normalizeSettings(body);
  if (next.min_percent > 100 || next.max_percent < 100) return validationFailed(c, { limits: ["The lowest offer must be at most 100% and the highest at least 100% of the estimate."] });
  if (next.absolute_max > 0 && next.absolute_max < next.absolute_min) return validationFailed(c, { limits: ["The maximum fare cannot be below the minimum fare."] });
  const db = c.get("db");
  await db.query("insert into app.settings (key, value) values ('bidding', $1::jsonb) on conflict (key) do update set value = excluded.value", [JSON.stringify(next)]);
  await audit(c, "bid_settings_update", "bidding", { enabled: next.enabled, max_rounds: next.max_rounds, overrides: next.overrides.length });
  return c.json({ status: true, data: next });
});

rideBidRoutes.get("/admin/bids", ...guard("ride_bid list"), async (c) => {
  const db = c.get("db");
  const days = Math.max(1, Math.min(365, Number(c.req.query("days")) || 30));
  const sum = (await db.query(
    `select count(*)::int as total,
            count(*) filter (where status = 'confirmed')::int as confirmed,
            count(*) filter (where status = 'expired')::int as expired,
            count(*) filter (where status = 'cancelled')::int as cancelled,
            count(*) filter (where exists (select 1 from app.ride_bid_responses r where r.bid_id = b.id))::int as with_responses,
            round(avg(agreed_fare) filter (where status = 'confirmed'), 2) as avg_agreed,
            round(avg(estimate_fare) filter (where status = 'confirmed'), 2) as avg_estimate,
            round(avg(agreed_fare - estimate_fare) filter (where status = 'confirmed'), 2) as avg_difference,
            round(avg(extract(epoch from closed_at - created_at)) filter (where status = 'confirmed'))::int as avg_seconds_to_agree
       from app.ride_bids b where created_at > now() - make_interval(days => $1)`, [days])).rows[0];
  const responses = (await db.query(
    `select count(*)::int as total, count(distinct driver_id)::int as drivers,
            count(*) filter (where status = 'declined')::int as declined
       from app.ride_bid_responses where created_at > now() - make_interval(days => $1)`, [days])).rows[0];
  const rides = (await db.query(
    `select (bid_id is not null) as bidding, count(*)::int as booked, count(*) filter (where status = 'completed')::int as completed,
            count(*) filter (where status = 'cancelled' and cancelled_by = 'driver')::int as driver_cancelled,
            count(*) filter (where status = 'cancelled' and cancelled_by = 'rider')::int as rider_cancelled,
            round(avg(fare) filter (where status = 'completed'), 2) as avg_fare
       from app.ride_requests where created_at > now() - make_interval(days => $1) and booking_source = 'passenger' group by 1`, [days])).rows;
  const places = (await db.query(
    `select round(pickup_lat::numeric, 2) as lat, round(pickup_lng::numeric, 2) as lng, count(*)::int as bids
       from app.ride_bids where created_at > now() - make_interval(days => $1) group by 1, 2 order by bids desc limit 8`, [days])).rows;
  const recent = (await db.query(
    `select b.id, b.status, b.estimate_fare, b.offer_fare, b.agreed_fare, b.currency, b.pickup_address, b.dropoff_address, b.created_at, b.rounds_used,
            (select count(*)::int from app.ride_bid_responses r where r.bid_id = b.id) as responses
       from app.ride_bids b order by b.id desc limit 50`)).rows;
  const n = (v: unknown) => (v == null ? null : Number(v));
  const total = Number(sum.total);
  const byKind = (flag: boolean) => rides.find((r) => r.bidding === flag) ?? { booked: 0, completed: 0, driver_cancelled: 0, rider_cancelled: 0, avg_fare: null };
  return c.json({
    status: true,
    days,
    summary: {
      total, confirmed: sum.confirmed, expired: sum.expired, cancelled: sum.cancelled, with_responses: sum.with_responses,
      response_rate: total ? Math.round((Number(sum.with_responses) / total) * 100) : 0,
      conversion_rate: total ? Math.round((Number(sum.confirmed) / total) * 100) : 0,
      avg_agreed: n(sum.avg_agreed), avg_estimate: n(sum.avg_estimate), avg_difference: n(sum.avg_difference), avg_seconds_to_agree: n(sum.avg_seconds_to_agree),
      driver_responses: responses.total, responding_drivers: responses.drivers, driver_declines: responses.declined,
    },
    comparison: { standard: byKind(false), bidding: byKind(true) },
    popular_pickups: places.map((p) => ({ lat: Number(p.lat), lng: Number(p.lng), bids: p.bids })),
    recent: recent.map((r) => ({ ...r, id: Number(r.id), estimate_fare: Number(r.estimate_fare), offer_fare: Number(r.offer_fare), agreed_fare: n(r.agreed_fare), currency: String(r.currency).trim() })),
  });
});

