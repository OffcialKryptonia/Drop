import type { Client } from "pg";
import type { Bindings } from "../env";
import { currencyInfo } from "./currency";
import { getSetting } from "./driver-application";
import { notify } from "./push-delivery";

type Row = Record<string, unknown>;

/* ------------------------------------------------------------------------------------------------
 * Settings. Every number the apps rely on comes from here (the admin "Bidding" page). Nothing is hardcoded in Flutter.
 * ---------------------------------------------------------------------------------------------- */

export type BidOverride = {
  region_id: number | null;
  service_id: number | null;
  enabled: boolean | null;
  min_percent: number | null;
  max_percent: number | null;
  absolute_min: number | null;
  absolute_max: number | null;
};

export type BidSettings = {
  enabled: boolean;
  min_percent: number;
  max_percent: number;
  absolute_min: number;
  absolute_max: number;
  max_rounds: number;
  bid_expiry_seconds: number;
  offer_expiry_seconds: number;
  max_active_bids: number;
  max_bids_per_hour: number;
  max_cancelled_per_day: number;
  overrides: BidOverride[];
};

const clampInt = (x: unknown, d: number, min: number, max: number) => {
  const n = Number(x);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, Math.round(n))) : d;
};
const optNum = (x: unknown, min: number, max: number): number | null => {
  if (x === null || x === undefined || x === "") return null;
  const n = Number(x);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : null;
};
const optId = (x: unknown): number | null => {
  const n = Number(x);
  return x !== null && x !== undefined && x !== "" && Number.isInteger(n) && n > 0 ? n : null;
};

/** Turns whatever is stored (or sent by the admin page) into safe values. Used for both reading and saving. */
export function normalizeSettings(raw: unknown): BidSettings {
  const v = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const min = clampInt(v.min_percent, 70, 10, 100);
  const max = clampInt(v.max_percent, 150, 100, 500);
  const overrides = (Array.isArray(v.overrides) ? v.overrides : []).slice(0, 100).map((o): BidOverride => {
    const x = (o ?? {}) as Record<string, unknown>;
    return {
      region_id: optId(x.region_id),
      service_id: optId(x.service_id),
      enabled: typeof x.enabled === "boolean" ? x.enabled : null,
      min_percent: optNum(x.min_percent, 10, 100),
      max_percent: optNum(x.max_percent, 100, 500),
      absolute_min: optNum(x.absolute_min, 0, 1e9),
      absolute_max: optNum(x.absolute_max, 0, 1e9),
    };
  });
  return {
    enabled: v.enabled === true, // opt-in: nothing happens until an admin switches bidding on
    min_percent: min,
    max_percent: max,
    absolute_min: Math.max(0, Number(v.absolute_min) || 0),
    absolute_max: Math.max(0, Number(v.absolute_max) || 0),
    max_rounds: clampInt(v.max_rounds, 3, 1, 10),
    bid_expiry_seconds: clampInt(v.bid_expiry_seconds, 180, 30, 1800),
    offer_expiry_seconds: clampInt(v.offer_expiry_seconds, 90, 15, 900),
    max_active_bids: clampInt(v.max_active_bids, 1, 1, 5),
    max_bids_per_hour: clampInt(v.max_bids_per_hour, 10, 1, 100),
    max_cancelled_per_day: clampInt(v.max_cancelled_per_day, 6, 1, 100),
    overrides,
  };
}

export async function biddingSettings(db: Client): Promise<BidSettings> {
  return normalizeSettings((await db.query("select value from app.settings where key = 'bidding'")).rows[0]?.value);
}

/* ------------------------------------------------------------------------------------------------
 * Fare guardrails. The server is the only judge of what an offer may be.
 * ---------------------------------------------------------------------------------------------- */

export type Limits = { enabled: boolean; min: number; max: number; reason?: string };
export const round2 = (n: number) => Math.round(n * 100) / 100;

/** The admin's rules for this region and ride type. The most specific matching override wins, field by field. */
export function limitsFor(s: BidSettings, estimate: number, regionId: number | null, serviceId: number): Limits {
  if (!s.enabled) return { enabled: false, min: 0, max: 0, reason: "Fare bidding is not available right now." };
  const matches = s.overrides
    .filter((o) => (o.region_id === null || o.region_id === regionId) && (o.service_id === null || o.service_id === serviceId))
    .sort((a, b) => Number(b.service_id !== null) + Number(b.region_id !== null) - (Number(a.service_id !== null) + Number(a.region_id !== null)));
  const pick = <K extends keyof BidOverride>(k: K, fallback: NonNullable<BidOverride[K]>): NonNullable<BidOverride[K]> => {
    const o = matches.find((m) => m[k] !== null);
    return (o ? o[k] : fallback) as NonNullable<BidOverride[K]>;
  };
  if (pick("enabled", true) === false) return { enabled: false, min: 0, max: 0, reason: "Bidding is not available for this ride type here." };
  const minPct = pick("min_percent", s.min_percent);
  const maxPct = pick("max_percent", s.max_percent);
  const absMin = pick("absolute_min", s.absolute_min);
  const absMax = pick("absolute_max", s.absolute_max);
  let min = Math.ceil(Math.max(absMin, (estimate * minPct) / 100));
  let max = Math.floor((estimate * maxPct) / 100);
  if (absMax > 0) max = Math.min(max, Math.floor(absMax));
  if (!(estimate > 0) || min > max) return { enabled: false, min, max, reason: "Bidding is not available for this trip." };
  min = Math.max(1, min);
  return { enabled: true, min, max };
}

export const fmtMoney = (amount: unknown, currency: unknown) => {
  const i = currencyInfo(String(currency ?? "NGN").trim() || "NGN");
  return `${i.symbol}${Number(amount).toLocaleString("en-NG", { maximumFractionDigits: 2 })}`;
};

export type OfferCheck = { ok: true; amount: number } | { ok: false; code: "bad_amount" | "below_min" | "above_max"; message: string };

/** Is this amount a legal offer? Always explains itself: nothing is rejected silently. */
export function checkOffer(raw: unknown, limits: Limits, currency: string): OfferCheck {
  const n = typeof raw === "string" ? Number(raw.replace(/,/g, "")) : Number(raw);
  if (raw === null || raw === undefined || raw === "" || !Number.isFinite(n) || n <= 0) return { ok: false, code: "bad_amount", message: "Enter the amount you want to pay." };
  const amount = round2(n);
  if (amount < limits.min) return { ok: false, code: "below_min", message: `That is too low. Offers for this trip must be between ${fmtMoney(limits.min, currency)} and ${fmtMoney(limits.max, currency)}.` };
  if (amount > limits.max) return { ok: false, code: "above_max", message: `That is too high. Offers for this trip must be between ${fmtMoney(limits.min, currency)} and ${fmtMoney(limits.max, currency)}.` };
  return { ok: true, amount };
}

/* ------------------------------------------------------------------------------------------------
 * The negotiation state machine (one thread per driver). The table below is the ONLY place that says what may follow what.
 * ---------------------------------------------------------------------------------------------- */

export type RespStatus =
  | "driver_accepted_offer" | "counteroffered" | "rider_revised" | "passenger_accepted_counteroffer"
  | "selected" | "declined" | "rejected" | "expired" | "lost";
export type Action = "driver_accept" | "driver_counter" | "driver_decline" | "rider_accept" | "rider_reject" | "rider_revise" | "select";

/** A thread that is still in play (a driver can still act, or the passenger can still decide). */
export const LIVE: RespStatus[] = ["driver_accepted_offer", "counteroffered", "rider_revised", "passenger_accepted_counteroffer"];
/** Both sides agree on `amount`: the passenger may pick this driver. */
export const SELECTABLE: RespStatus[] = ["driver_accepted_offer", "passenger_accepted_counteroffer"];
export const WAITING_ON_RIDER: RespStatus[] = ["counteroffered", "driver_accepted_offer", "passenger_accepted_counteroffer"];
export const WAITING_ON_DRIVER: RespStatus[] = ["rider_revised"];
/** Actions that spend a negotiation round. */
export const SPENDS_ROUND: Action[] = ["driver_counter", "rider_revise"];

const TABLE: Record<string, Partial<Record<Action, RespStatus>>> = {
  start: { driver_accept: "driver_accepted_offer", driver_counter: "counteroffered", driver_decline: "declined" },
  rider_revised: { driver_accept: "passenger_accepted_counteroffer", driver_counter: "counteroffered", driver_decline: "declined" },
  counteroffered: { rider_accept: "passenger_accepted_counteroffer", rider_reject: "rejected", rider_revise: "rider_revised", driver_decline: "declined" },
  driver_accepted_offer: { select: "selected", rider_reject: "rejected", driver_decline: "declined" },
  passenger_accepted_counteroffer: { select: "selected", rider_reject: "rejected", driver_decline: "declined" },
};

/** The status after `action`, or null when that action is not allowed from here. `from` null = the driver has not answered yet. */
export function transition(from: RespStatus | null, action: Action): RespStatus | null {
  return TABLE[from ?? "start"]?.[action] ?? null;
}

/* ------------------------------------------------------------------------------------------------
 * Database helpers
 * ---------------------------------------------------------------------------------------------- */

export async function logEvent(db: Client, bidId: number, responseId: number | null, role: "rider" | "driver" | "system", actorId: number | null, action: string, amount?: number | null, note?: string | null) {
  await db.query(
    "insert into app.ride_bid_events (bid_id, response_id, actor_role, actor_id, action, amount, note) values ($1,$2,$3,$4,$5,$6,$7)",
    [bidId, responseId, role, actorId, action, amount ?? null, note ?? null],
  );
}

const POINT = "extensions.st_setsrid(extensions.st_makepoint(b.pickup_lng, b.pickup_lat), 4326)::extensions.geography";

/**
 * Drivers who may be told about a bid: the SAME rules as standard requests (online, free, approved, right ride type,
 * inside the pickup radius, wallet and documents in order), plus the driver chose to receive passenger bids.
 */
export async function eligibleBidDrivers(db: Client, bidId: number, radiusM: number, limit = 30): Promise<Row[]> {
  return (await db.query(
    `select du.id, extensions.st_distance(du.location, ${POINT}) as pickup_m
       from app.ride_bids b
       join app.driver_profiles p on p.service_id = b.service_id and p.status = 'approved' and p.accepts_bids
       join app.users du on du.id = p.user_id and du.status = 'active' and du.deleted_at is null
      where b.id = $1 and b.status = 'open' and du.id <> b.rider_id
        and du.is_online and du.is_available and du.active_mode = 'driver'
        and du.location is not null and du.last_location_update_at > now() - interval '5 minutes'
        and extensions.st_dwithin(du.location, ${POINT}, $2)
      order by pickup_m limit $3`, [bidId, radiusM, limit])).rows;
}

export type BidEvent =
  | "new_bid" | "driver_accepted" | "driver_counteroffered" | "rider_accepted_counter" | "rider_revised" | "bid_raised"
  | "bid_expired" | "bid_cancelled" | "driver_selected" | "selection_lost" | "response_expired" | "driver_withdrew" | "counter_rejected";

const BID_KEY: Record<BidEvent, string> = {
  new_bid: "driver.new_bid", driver_accepted: "passenger.bid_driver_accepted", driver_counteroffered: "passenger.bid_counteroffer",
  rider_accepted_counter: "driver.bid_counter_accepted", rider_revised: "driver.bid_revised", bid_raised: "driver.bid_raised",
  bid_expired: "passenger.bid_expired", bid_cancelled: "driver.bid_cancelled", driver_selected: "driver.bid_selected",
  selection_lost: "driver.bid_selection_lost", response_expired: "driver.bid_response_expired", driver_withdrew: "passenger.bid_driver_withdrew",
  counter_rejected: "driver.bid_counter_declined",
};

/** One short push, from the template for that bid event. The push never carries authority: the apps re-read the bid from the server. */
export async function pushBidEvent(db: Client, env: Bindings, userIds: number[], event: BidEvent, bidId: number, extra?: { amount?: unknown; currency?: unknown; place?: unknown }): Promise<void> {
  if (!userIds.length) return;
  await notify(db, env, {
    key: BID_KEY[event], userIds,
    vars: { amount: extra?.amount != null ? fmtMoney(extra.amount, extra.currency) : "", pickup_location: extra?.place != null ? String(extra.place) : "" },
    data: { type: "bid", event, bid_id: String(bidId) },
    dedupe: `${BID_KEY[event]}:bid${bidId}`,
  });
}

/** Tells eligible drivers a bid is waiting. Never throws. */
export async function pushNewBid(db: Client, env: Bindings, bidId: number, event: "new_bid" | "bid_raised" = "new_bid"): Promise<void> {
  try {
    const radius = await getSetting(db, "nearby_driver_radius_m", 5000);
    const b = (await db.query("select offer_fare, currency, pickup_address from app.ride_bids where id = $1 and status = 'open'", [bidId])).rows[0];
    if (!b) return;
    const drivers = await eligibleBidDrivers(db, bidId, radius);
    await pushBidEvent(db, env, drivers.map((d) => Number(d.id)), event, bidId, { amount: b.offer_fare, currency: b.currency, place: b.pickup_address });
  } catch (e) { console.error("push new bid", (e as Error).message); }
}

/**
 * Runs every minute: bids nobody finished in time expire, and driver responses the passenger ignored expire.
 * Returns the number of bids and responses closed.
 */
export async function sweepBids(db: Client, env: Bindings): Promise<{ bids: number; responses: number }> {
  let bids = 0, responses = 0;
  const lateResp = (await db.query(
    `update app.ride_bid_responses r set status = 'expired'
       from app.ride_bids b
      where r.bid_id = b.id and b.status = 'open' and r.status = any($1) and r.expires_at < now()
      returning r.id, r.bid_id, r.driver_id, r.amount`, [LIVE])).rows;
  for (const r of lateResp) {
    responses++;
    await logEvent(db, Number(r.bid_id), Number(r.id), "system", null, "response_expired", Number(r.amount));
    await pushBidEvent(db, env, [Number(r.driver_id)], "response_expired", Number(r.bid_id));
  }
  const dead = (await db.query(
    "update app.ride_bids set status = 'expired', close_reason = 'timeout', closed_at = now() where status = 'open' and expires_at < now() returning id, rider_id")).rows;
  for (const b of dead) {
    bids++;
    const lost = (await db.query("update app.ride_bid_responses set status = 'expired' where bid_id = $1 and status = any($2) returning id", [b.id, LIVE])).rowCount ?? 0;
    responses += lost;
    await logEvent(db, Number(b.id), null, "system", null, "bid_expired");
    await pushBidEvent(db, env, [Number(b.rider_id)], "bid_expired", Number(b.id));
  }
  return { bids, responses };
}
