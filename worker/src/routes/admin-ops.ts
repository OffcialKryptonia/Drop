import { Hono, type Context } from "hono";
import { z } from "zod";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { guard, loadAccess } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { rideEta } from "../lib/eta";
import { airportView, AIRPORT_COLS, AIRPORT_JOIN } from "../lib/airports";
import { pushLater, pushRideEvent } from "../lib/push";
import { notify } from "../lib/push-delivery";
import { notifyEmail } from "../lib/email-delivery";
import {
  CANCEL_CATEGORIES, FRESH_SECONDS, RIDE_FILTERS, assignDriver, candidatesFor, cancelRide, delaySettings, detectDelay, filterSql, fleetState,
  loadFacts, locationFreshness, paymentView, personName, reassignDriver, rideTimeline, toFacts, type RideFilter, type TimelineItem,
} from "../lib/dispatch";
import { getSetting } from "../lib/driver-application";

export const adminOpsRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
type Row = Record<string, unknown>;

const idOf = (c: C, name = "id") => { const n = Number(c.req.param(name)); return Number.isSafeInteger(n) && n > 0 ? n : null; };
const notFound = (c: C, what = "Ride") => c.json({ status: false, code: "not_found", message: `${what} not found.` }, 404);
const NAME = "coalesce(nullif(btrim(u.display_name), ''), nullif(btrim(concat_ws(' ', u.first_name, u.last_name)), ''), u.username)";
const OPEN = "('accepted', 'arrived', 'in_progress')";
const STALE = (db: Client) => getSetting(db, "driver_location_stale_minutes", 10);

// ---------------------------------------------------------------------------------------------------------------------
// A. Operations dashboard. Every figure is a live query. A figure that cannot be read says so; it is never shown as 0.
// ---------------------------------------------------------------------------------------------------------------------
type Metric = { available: true; value: unknown; note?: string } | { available: false; reason: string };

adminOpsRoutes.get("/admin/ops/metrics", ...guard("ops_dashboard list"), async (c) => {
  const db = c.get("db");
  const tzIn = (c.req.query("tz") ?? "Africa/Lagos").trim();
  const tz = (await db.query("select 1 from pg_timezone_names where name = $1", [tzIn])).rowCount ? tzIn : "Africa/Lagos";
  const start = (await db.query("select (date_trunc('day', now() at time zone $1) at time zone $1) as s", [tz])).rows[0].s as Date;
  const metrics: Record<string, Metric> = {};
  const run = async (name: string, fn: () => Promise<{ value: unknown; note?: string }>) => {
    try { metrics[name] = { available: true, ...(await fn()) }; }
    catch (e) { console.error("ops metric", name, (e as Error).message); metrics[name] = { available: false, reason: "Could not be read right now." }; }
  };
  const count = async (sql: string, args: unknown[] = []) => ({ value: Number((await db.query(sql, args)).rows[0].n) });

  await Promise.all([]); // queries share one connection, so they run one after another
  await run("rides_today", () => count("select count(*)::int n from app.ride_requests where created_at >= $1", [start]));
  await run("completed_today", () => count("select count(*)::int n from app.ride_requests where status = 'completed' and completed_at >= $1", [start]));
  await run("cancelled_today", () => count("select count(*)::int n from app.ride_requests where status = 'cancelled' and cancelled_at >= $1", [start]));
  await run("expired_today", () => count("select count(*)::int n from app.ride_requests where status = 'expired' and updated_at >= $1", [start]));
  await run("active_rides", () => count(`select count(*)::int n from app.ride_requests where status in ${OPEN}`));
  await run("pending_rides", () => count("select count(*)::int n from app.ride_requests where status = 'searching' and expires_at > now()"));
  await run("airport_bookings_today", () => count("select count(*)::int n from app.ride_requests where airport_id is not null and created_at >= $1", [start]));
  await run("online_drivers", async () => {
    const stale = await STALE(db);
    const r = (await db.query(
      `select count(*)::int total,
              count(*) filter (where u.last_location_update_at >= now() - interval '${FRESH_SECONDS} seconds')::int fresh,
              count(*) filter (where u.last_location_update_at is null or u.last_location_update_at < now() - make_interval(mins => $1::int))::int stale_or_unknown
         from app.users u join app.driver_profiles p on p.user_id = u.id and p.status = 'approved' where u.deleted_at is null and u.is_online`, [stale])).rows[0];
    return { value: Number(r.total), note: `${r.fresh} with a live location, ${r.stale_or_unknown} with an old or missing one.` };
  });
  await run("available_drivers", () => count(
    `select count(*)::int n from app.users u join app.driver_profiles p on p.user_id = u.id and p.status = 'approved'
      where u.deleted_at is null and u.is_online and u.is_available
        and not exists (select 1 from app.ride_requests r where r.driver_id = u.id and r.status in ${OPEN})`));
  await run("drivers_on_trips", () => count(`select count(distinct driver_id)::int n from app.ride_requests where status in ${OPEN} and driver_id is not null`));
  await run("pending_driver_applications", () => count("select count(*)::int n from app.driver_profiles where status in ('submitted', 'in_review')"));

  const money = async () => (await db.query(
    `select trim(currency) currency, count(*)::int rides, sum(fare)::float8 gross,
            sum(commission)::float8 platform, sum(fare - commission)::float8 driver,
            count(*) filter (where commission is null)::int without_commission
       from app.ride_requests where status = 'completed' and completed_at >= $1 group by 1 order by 1`, [start])).rows;
  let moneyRows: Row[] | null = null, moneyErr = false;
  try { moneyRows = await money(); } catch (e) { moneyErr = true; console.error("ops money", (e as Error).message); }
  const missing = (moneyRows ?? []).reduce((n, r) => n + Number(r.without_commission), 0);
  const note = (extra: string) => (missing ? `${missing} completed ride(s) have no commission recorded and are left out of this figure.${extra}` : extra || undefined);
  const put = (name: string, pick: (r: Row) => unknown, extra = "") => {
    metrics[name] = moneyErr || !moneyRows ? { available: false, reason: "Could not be read right now." }
      : { available: true, value: moneyRows.map((r) => ({ currency: r.currency, amount: Number(pick(r) ?? 0) })), ...(note(extra) ? { note: note(extra) } : {}) };
  };
  put("gross_ride_value_today", (r) => r.gross, "Fare of rides completed today, as recorded on the ride.");
  put("platform_revenue_today", (r) => r.platform, "DROP's commission on rides completed today. Cancellation fees are not included.");
  put("driver_earnings_today", (r) => r.driver, "Fare minus commission on rides completed today, before any payout.");

  await run("pending_payouts", async () => {
    const rows = (await db.query("select trim(currency) currency, count(*)::int n, sum(amount)::float8 amount from app.withdraw_requests where status = 'pending' group by 1 order by 1")).rows;
    return { value: { count: rows.reduce((n, r) => n + Number(r.n), 0), by_currency: rows.map((r) => ({ currency: r.currency, amount: Number(r.amount) })) } };
  });
  await run("sos_incidents", async () => {
    const r = (await db.query(
      `select count(*) filter (where status = 'open')::int open, count(*) filter (where status = 'acknowledged')::int acknowledged,
              count(*) filter (where created_at >= $1)::int today from app.sos_alerts`, [start])).rows[0];
    return { value: { open: Number(r.open), acknowledged: Number(r.acknowledged), today: Number(r.today) } };
  });
  await run("open_escalations", () => count("select count(*)::int n from app.ride_escalations where status = 'open'"));

  return c.json({ status: true, generated_at: new Date().toISOString(), timezone: tz, day_started_at: start.toISOString(), metrics });
});

/** Rides and drivers that need a person's attention right now, by plain thresholds on recorded times. */
adminOpsRoutes.get("/admin/ops/attention", ...guard("ops_dashboard list"), async (c) => {
  const db = c.get("db");
  const s = await delaySettings(db);
  const rows = (await db.query(
    `select r.id, r.status, r.created_at, r.accepted_at, r.started_at, r.expires_at, r.duration_minutes, du.last_location_update_at as driver_location_at,
            r.pickup_address, ${NAME.replace(/u\./g, "rider.")} as passenger_name
       from app.ride_requests r join app.users rider on rider.id = r.rider_id left join app.users du on du.id = r.driver_id
      where (r.status = 'searching' and r.expires_at > now()) or r.status in ${OPEN} order by r.id limit 500`)).rows;
  const now = Date.now();
  const items = rows.flatMap((r) => detectDelay({ ...r, status: String(r.status) } as never, now, s).map((d) => ({
    ride_id: Number(r.id), status: r.status, kind: d.kind, minutes: d.minutes, passenger: r.passenger_name, pickup: r.pickup_address,
  })));
  const escalations = (await db.query(
    `select e.id, e.ride_request_id as ride_id, e.category, e.severity, e.reason, e.created_at from app.ride_escalations e
      where e.status = 'open' order by case e.severity when 'urgent' then 0 when 'high' then 1 else 2 end, e.id desc limit 20`)).rows;
  return c.json({ status: true, generated_at: new Date().toISOString(), rules: s, delays: items, escalations });
});

// ---------------------------------------------------------------------------------------------------------------------
// B. Live fleet
// ---------------------------------------------------------------------------------------------------------------------
adminOpsRoutes.get("/admin/ops/fleet", ...guard("fleet list"), async (c) => {
  const db = c.get("db");
  const region = Number(c.req.query("region_id"));
  const stale = await STALE(db);
  const rows = (await db.query(
    `select u.id, ${NAME} as name, u.latitude, u.longitude, u.last_location_update_at as location_at, u.is_online, u.is_available,
            p.vehicle_make, p.vehicle_model, p.vehicle_colour, p.vehicle_plate, s.name as service_name, s.region_id,
            r.id as ride_id, r.status as ride_status, r.airport_id, r.airport_direction, ap.name as airport_name, r.pickup_address, r.dropoff_address,
            (select count(*)::int from app.ride_request_stops st where st.ride_request_id = r.id) as stops_total,
            (select count(*)::int from app.ride_request_stops st where st.ride_request_id = r.id and st.status = 'completed') as stops_done
       from app.users u
       join app.driver_profiles p on p.user_id = u.id and p.status = 'approved'
       left join app.services s on s.id = p.service_id
       left join lateral (select x.id, x.status, x.airport_id, x.airport_direction, x.pickup_address, x.dropoff_address from app.ride_requests x
                           where x.driver_id = u.id and x.status in ${OPEN} limit 1) r on true
       left join app.airports ap on ap.id = r.airport_id
      where u.deleted_at is null and (u.is_online or r.id is not null) and ($1::bigint is null or s.region_id = $1)
      order by u.id limit 1000`, [Number.isSafeInteger(region) && region > 0 ? region : null])).rows;
  const now = Date.now();
  const drivers = rows.map((r) => {
    const state = fleetState({ is_available: r.is_available, ride_status: r.ride_status, stops_total: r.stops_total });
    return {
      id: Number(r.id), name: r.name, state, busy: r.ride_id != null, online: r.is_online === true,
      offline_with_ride: r.is_online !== true && r.ride_id != null,
      location: r.latitude == null || r.longitude == null ? null : { lat: Number(r.latitude), lng: Number(r.longitude), at: r.location_at },
      freshness: locationFreshness(r.location_at, now, stale),
      vehicle: { description: [r.vehicle_make, r.vehicle_model].filter(Boolean).join(" ") || null, colour: r.vehicle_colour ?? null, plate: r.vehicle_plate ?? null },
      ride_type: r.service_name ?? null,
      ride: r.ride_id == null ? null : {
        id: Number(r.ride_id), status: r.ride_status, pickup: r.pickup_address, dropoff: r.dropoff_address,
        stops: Number(r.stops_total) > 0 ? { total: Number(r.stops_total), done: Number(r.stops_done) } : null,
        airport: r.airport_id == null ? null : { name: r.airport_name, direction: r.airport_direction },
      },
    };
  });
  const counts: Record<string, number> = { online: 0, available: 0, unavailable: 0, approaching_pickup: 0, arrived: 0, on_trip: 0, multi_stop: 0, airport: 0, no_live_location: 0 };
  for (const d of drivers) {
    if (d.online) counts.online++;
    counts[d.state]++;
    if (d.ride?.airport) counts.airport++;
    if (d.freshness.state === "stale" || d.freshness.state === "unknown") counts.no_live_location++;
  }
  return c.json({ status: true, generated_at: new Date().toISOString(), fresh_seconds: FRESH_SECONDS, stale_minutes: stale, counts, drivers });
});

adminOpsRoutes.get("/admin/ops/drivers/:id", ...guard("fleet list"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c, "Driver");
  const db = c.get("db");
  const row = (await loadFacts(db, [id]))[0];
  if (!row || !row.profile_status) return notFound(c, "Driver");
  const f = toFacts(row);
  const stale = await STALE(db);
  const cur = (await db.query(
    `select r.id, r.status, r.pickup_address, r.dropoff_address, r.airport_id, r.airport_direction from app.ride_requests r
      where r.driver_id = $1 and r.status in ${OPEN} limit 1`, [id])).rows[0];
  const perf = (await db.query(
    `select count(*) filter (where status = 'completed')::int completed_total,
            count(*) filter (where status = 'completed' and completed_at >= now() - interval '30 days')::int completed_30d,
            count(*) filter (where status = 'completed' and completed_at >= date_trunc('day', now()))::int completed_today
       from app.ride_requests where driver_id = $1`, [id])).rows[0];
  const rating = (await db.query("select avg(rating)::float8 avg, count(*)::int n from app.ride_ratings where driver_id = $1", [id])).rows[0];
  const earn = (await db.query(
    `select trim(currency) currency, sum(fare - commission)::float8 amount from app.ride_requests
      where driver_id = $1 and status = 'completed' and commission is not null and completed_at >= now() - interval '30 days' group by 1`, [id])).rows;
  return c.json({
    status: true,
    data: {
      id, name: personName(row), username: row.username ?? null, member_since: row.member_since, account_status: f.user_status, profile_status: f.profile_status,
      mode: f.active_mode, online: f.is_online, available: f.is_available,
      ride_type: { id: f.service_id, name: row.service_name ?? null, category: row.service_category ?? null },
      vehicle: { make: row.vehicle_make ?? null, model: row.vehicle_model ?? null, year: row.vehicle_year ?? null, colour: row.vehicle_colour ?? null, plate: f.vehicle_plate, seats: f.vehicle_seats },
      location: f.latitude == null || f.longitude == null ? null : { lat: f.latitude, lng: f.longitude, at: f.location_at },
      freshness: locationFreshness(f.location_at, Date.now(), stale),
      current_ride: cur ? { id: Number(cur.id), status: cur.status, pickup: cur.pickup_address, dropoff: cur.dropoff_address, airport: cur.airport_id != null } : null,
      performance: {
        completed_today: Number(perf.completed_today), completed_30d: Number(perf.completed_30d), completed_total: Number(perf.completed_total),
        rating: rating.n > 0 ? { average: Math.round(Number(rating.avg) * 100) / 100, count: Number(rating.n) } : null,
        earnings_30d: earn.map((e) => ({ currency: e.currency, amount: Number(e.amount) })),
        unavailable: ["Driver cancellations and acceptance rate are not recorded by the platform, so they are not shown."],
      },
      wallet_ok: f.wallet_balance >= f.wallet_minimum, documents_expired: f.docs_expired,
    },
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// C. Live rides
// ---------------------------------------------------------------------------------------------------------------------
const LIST_SELECT = `
  select r.id, r.status, r.created_at, r.expires_at, r.accepted_at, r.started_at, r.completed_at, r.cancelled_at, r.fare, trim(r.currency) as currency,
         r.payment_method, r.pickup_address, r.dropoff_address, r.airport_id, r.airport_direction, r.booking_source, r.duration_minutes, r.driver_id,
         ap.name as airport_name, s.name as service_name, s.category as service_category,
         ${NAME.replace(/u\./g, "rider.")} as passenger_name, ${NAME.replace(/u\./g, "du.")} as driver_name, du.last_location_update_at as driver_location_at,
         (select count(*)::int from app.ride_request_stops st where st.ride_request_id = r.id) as stops_total,
         (select count(*)::int from app.ride_request_stops st where st.ride_request_id = r.id and st.status = 'completed') as stops_done
    from app.ride_requests r
    join app.services s on s.id = r.service_id
    join app.users rider on rider.id = r.rider_id
    left join app.users du on du.id = r.driver_id
    left join app.airports ap on ap.id = r.airport_id`;

adminOpsRoutes.get("/admin/ops/rides", ...guard("ops_ride list"), async (c) => {
  const db = c.get("db");
  const filter = (c.req.query("filter") ?? "all_live") as RideFilter;
  if (!RIDE_FILTERS.includes(filter)) return validationFailed(c, { filter: ["Unknown filter."] });
  const q = (c.req.query("q") ?? "").trim().slice(0, 80);
  const region = Number(c.req.query("region_id"));
  const page = Math.max(1, Math.floor(Number(c.req.query("page")) || 1));
  const hours = Math.min(168, Math.max(1, Math.floor(Number(c.req.query("hours")) || 0)));
  const windowStart = c.req.query("hours")
    ? new Date(Date.now() - hours * 3600_000)
    : ((await db.query("select (date_trunc('day', now() at time zone 'Africa/Lagos') at time zone 'Africa/Lagos') as s")).rows[0].s as Date);
  const threshold = (await delaySettings(db)).unassigned_after_seconds;
  const oldest = c.req.query("sort") === "oldest";
  const where = `(${filterSql(filter)}) and ($3 = '' or r.id::text = $3 or rider.display_name ilike $4 or rider.username ilike $4 or du.display_name ilike $4)
       and ($5::bigint is null or r.region_id = $5)`;
  const args = [threshold, windowStart, q, `%${q.replace(/[%_]/g, "")}%`, Number.isSafeInteger(region) && region > 0 ? region : null];
  const total = Number((await db.query(`select count(*)::int n from app.ride_requests r join app.users rider on rider.id = r.rider_id left join app.users du on du.id = r.driver_id where ${where}`, args)).rows[0].n);
  const rows = (await db.query(`${LIST_SELECT} where ${where} order by r.id ${oldest ? "asc" : "desc"} limit 50 offset $6`, [...args, (page - 1) * 50])).rows;
  const stale = await STALE(db), now = Date.now();
  return c.json({
    status: true, generated_at: new Date().toISOString(), filter, window_started_at: windowStart.toISOString(), unassigned_after_seconds: threshold,
    pagination: { page, total_pages: Math.max(Math.ceil(total / 50), 1), total },
    data: rows.map((r) => ({
      id: Number(r.id), status: r.status, created_at: r.created_at, waited_seconds: r.status === "searching" ? Math.round((now - new Date(r.created_at as string).getTime()) / 1000) : null,
      passenger: r.passenger_name, driver: r.driver_id ? { id: Number(r.driver_id), name: r.driver_name, freshness: locationFreshness(r.driver_location_at, now, stale) } : null,
      service: r.service_name, category: r.service_category, booking_source: r.booking_source || "passenger",
      pickup: r.pickup_address, dropoff: r.dropoff_address, fare: Number(r.fare), currency: r.currency, payment_method: r.payment_method,
      airport: r.airport_id == null ? null : { name: r.airport_name, direction: r.airport_direction },
      stops: Number(r.stops_total) > 0 ? { total: Number(r.stops_total), done: Number(r.stops_done) } : null,
    })),
  });
});

adminOpsRoutes.get("/admin/ops/rides/:id", ...guard("ops_ride list"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const db = c.get("db");
  const r = (await db.query(
    `select r.*, s.name as service_name, s.category as service_category, s.capacity as service_capacity, ${AIRPORT_COLS},
            ${NAME.replace(/u\./g, "rider.")} as passenger_name, rider.id as passenger_id,
            ${NAME.replace(/u\./g, "du.")} as driver_name, du.latitude as driver_lat, du.longitude as driver_lng, du.last_location_update_at as driver_location_at,
            du.is_online as driver_online, p.vehicle_make, p.vehicle_model, p.vehicle_colour, p.vehicle_plate, p.vehicle_seats,
            ${NAME.replace(/u\./g, "adm.")} as booked_by_name
       from app.ride_requests r
       join app.services s on s.id = r.service_id
       join app.users rider on rider.id = r.rider_id
       ${AIRPORT_JOIN}
       left join app.users du on du.id = r.driver_id
       left join app.driver_profiles p on p.user_id = r.driver_id
       left join app.users adm on adm.id = r.booked_by_admin_id
      where r.id = $1`, [id])).rows[0];
  if (!r) return notFound(c);

  const stops = (await db.query("select id, sequence, lat, lng, address, status, arrived_at, completed_at from app.ride_request_stops where ride_request_id = $1 order by sequence", [id])).rows;
  const pickupEv = (await db.query("select event, created_at from app.ride_pickup_events where ride_request_id = $1 order by id", [id])).rows;
  const dispatchEv = (await db.query(
    `select e.*, ${NAME.replace(/u\./g, "a.")} as admin_name, ${NAME.replace(/u\./g, "f.")} as from_name, ${NAME.replace(/u\./g, "t.")} as to_name
       from app.ride_dispatch_events e left join app.users a on a.id = e.admin_id left join app.users f on f.id = e.from_driver_id left join app.users t on t.id = e.to_driver_id
      where e.ride_request_id = $1 order by e.id`, [id])).rows;
  const escalations = (await db.query("select id, category, severity, reason, status, created_at, resolved_at, resolution_note from app.ride_escalations where ride_request_id = $1 order by id desc", [id])).rows;
  const link = (await db.query("select status, gateway from app.ride_pay_links where ride_request_id = $1 order by id desc limit 1", [id])).rows[0] ?? null;

  const PICKUP_LABEL: Record<string, string> = { issued: "Pickup code issued", verified: "Pickup code verified by driver", wrong_code: "Wrong pickup code entered", locked: "Pickup code locked after wrong attempts", expired: "Pickup code expired", override: "Pickup authorised by DROP Support" };
  const DISPATCH_LABEL = (e: Row) => ({
    assign: `Driver ${e.to_name ?? "#" + e.to_driver_id} assigned by dispatch`,
    reassign: `Driver changed from ${e.from_name ?? "#" + e.from_driver_id} to ${e.to_name ?? "#" + e.to_driver_id}${e.reason ? `: ${e.reason}` : ""}`,
    cancel: `Cancelled by DROP Support${e.reason ? `: ${e.reason}` : ""}`,
    escalate: `Escalated: ${e.reason ?? ""}`,
    escalation_resolved: "Escalation resolved",
    contact_view: `Contact details viewed (${(e.detail as Row)?.party ?? "party"})`,
    message: `Message sent to ${(e.detail as Row)?.party ?? "party"}`,
  } as Record<string, string>)[String(e.action)] ?? String(e.action);
  const extra: TimelineItem[] = [
    ...pickupEv.map((e) => ({ at: new Date(e.created_at as string).toISOString(), kind: "pickup_code", label: PICKUP_LABEL[String(e.event)] ?? String(e.event) })),
    ...dispatchEv.map((e) => ({ at: new Date(e.created_at as string).toISOString(), kind: `dispatch_${e.action}`, label: DISPATCH_LABEL(e), actor: (e.admin_name as string) ?? null })),
  ];

  const now = Date.now();
  const stale = await STALE(db);
  const status = String(r.status);
  const expired = status === "searching" && r.expires_at && new Date(r.expires_at as string).getTime() <= now;
  const access = await loadAccess(c);
  const has = (p: string) => access.isSuper || access.permissions.has(p);
  const open = ["searching", "accepted", "arrived", "in_progress"].includes(status) && !expired;
  const canAssign = has("ops_ride assign");
  const actions = {
    assign: { allowed: canAssign && status === "searching" && !expired && r.driver_id == null && r.bid_id == null, why: !canAssign ? "No permission." : r.bid_id != null ? "Negotiated-fare rides cannot be assigned from Dispatch." : status !== "searching" || expired ? "Only a ride still waiting for a driver can be assigned." : null },
    reassign: { allowed: canAssign && ["accepted", "arrived"].includes(status) && r.bid_id == null, why: !canAssign ? "No permission." : r.bid_id != null ? "Negotiated-fare rides cannot be reassigned." : status === "in_progress" ? "A driver cannot be changed mid-trip." : !["accepted", "arrived"].includes(status) ? "Only a ride with a driver who has not started the trip can be reassigned." : null },
    cancel: { allowed: has("ops_ride cancel") && ["searching", "accepted", "arrived"].includes(status) && !expired, why: !has("ops_ride cancel") ? "No permission." : status === "in_progress" ? "The trip has started. Escalate it instead." : !["searching", "accepted", "arrived"].includes(status) || expired ? "This ride can no longer be cancelled." : null },
    escalate: { allowed: has("ops_ride escalate"), why: has("ops_ride escalate") ? null : "No permission." },
    contact: { allowed: has("ops_ride contact"), why: has("ops_ride contact") ? null : "No permission." },
  };

  const fare = r.fare_breakdown as Row | null;
  return c.json({
    status: true, generated_at: new Date().toISOString(),
    data: {
      id, status: expired ? "expired" : status, open, booking_source: r.booking_source || "passenger", booked_by: r.booked_by_name ?? null,
      booking_category: { ride_type: r.service_name, category: r.service_category, airport: r.airport_id != null, multi_stop: stops.length > 0, negotiated_fare: r.bid_id != null },
      passenger: { id: Number(r.passenger_id), name: r.passenger_name },
      driver: r.driver_id ? {
        id: Number(r.driver_id), name: r.driver_name, online: r.driver_online === true,
        vehicle: { description: [r.vehicle_make, r.vehicle_model].filter(Boolean).join(" ") || null, colour: r.vehicle_colour ?? null, plate: r.vehicle_plate ?? null, seats: r.vehicle_seats ?? null },
        location: r.driver_lat == null ? null : { lat: Number(r.driver_lat), lng: Number(r.driver_lng), at: r.driver_location_at },
        freshness: locationFreshness(r.driver_location_at, now, stale),
      } : null,
      pickup: { lat: Number(r.pickup_lat), lng: Number(r.pickup_lng), address: r.pickup_address },
      dropoff: { lat: Number(r.dropoff_lat), lng: Number(r.dropoff_lng), address: r.dropoff_address },
      stops, timeline: rideTimeline(r, stops, extra),
      eta: rideEta(r) ?? null, eta_note: rideEta(r) ? "An estimate from the driver's last known location, not turn-by-turn." : "No estimate: the ride is not on its way, or the driver's location is unknown.",
      fare: { amount: Number(r.fare), currency: String(r.currency).trim(), breakdown: fare, cancellation_fee: Number(r.cancellation_fee ?? 0) },
      payment: paymentView({ status, payment_method: String(r.payment_method), paid_with: (r.paid_with as string) ?? null }, link as { status: string; gateway: string | null } | null),
      // The flight contact phone is left out here; it is a passenger number and Contact already records every phone view.
      airport: airportView(r, true),
      cancel: status === "cancelled" ? { by: r.cancelled_by, reason: r.cancel_reason, at: r.cancelled_at } : null,
      waited_seconds: status === "searching" ? Math.round((now - new Date(r.created_at as string).getTime()) / 1000) : null,
      delays: detectDelay({ ...r, status } as never, now, await delaySettings(db)),
      escalations, actions,
    },
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// D/E. Dispatcher console and ride intervention. Every action is re-validated here against the locked database rows.
// ---------------------------------------------------------------------------------------------------------------------
adminOpsRoutes.get("/admin/ops/rides/:id/candidates", ...guard("ops_ride list"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const ride = (await c.get("db").query("select * from app.ride_requests where id = $1", [id])).rows[0];
  if (!ride) return notFound(c);
  return c.json({ status: true, generated_at: new Date().toISOString(), ride_id: id, current_driver_id: ride.driver_id == null ? null : Number(ride.driver_id), data: await candidatesFor(c.get("db"), ride, { currentDriverId: ride.driver_id == null ? null : Number(ride.driver_id) }) });
});

const actionFail = (c: C, f: { status: number; code: string; message: string; reasons?: unknown }) =>
  c.json({ status: false, code: f.code, message: f.message, ...(f.reasons ? { reasons: f.reasons } : {}) }, f.status as 404 | 409);
const reasonText = z.string().trim().min(3, "Enter a reason (at least 3 characters).").max(300);

adminOpsRoutes.post("/admin/ops/rides/:id/assign", ...guard("ops_ride assign"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ driver_id: z.coerce.number().int().positive(), note: z.string().trim().max(300).optional() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { driver_id: [p.error.issues[0].message] });
  const db = c.get("db");
  const res = await assignDriver(db, c.env, { rideId: id, driverId: p.data.driver_id, adminId: c.get("user").id, note: p.data.note ?? null });
  if (!res.ok) return actionFail(c, res);
  const ride = res.ride;
  pushLater(c, Promise.all([
    pushRideEvent(db, c.env, Number(ride.rider_id), "accepted", id),
    notifyEmail(db, c.env, { key: "email.passenger.driver_assigned", userIds: [Number(ride.rider_id)], rideId: id }),
    notify(db, c.env, { key: "driver.ride_assigned", userIds: [p.data.driver_id], rideId: id, data: { type: "ride", event: "dispatch_assigned", ride_id: String(id) } }),
  ]));
  return c.json({ status: true, id, driver_id: p.data.driver_id });
});

adminOpsRoutes.post("/admin/ops/rides/:id/reassign", ...guard("ops_ride assign"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ driver_id: z.coerce.number().int().positive(), expected_driver_id: z.coerce.number().int().positive(), reason: reasonText }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { reason: [p.error.issues[0].message] });
  const db = c.get("db");
  const res = await reassignDriver(db, c.env, { rideId: id, driverId: p.data.driver_id, expectedDriverId: p.data.expected_driver_id, adminId: c.get("user").id, reason: p.data.reason });
  if (!res.ok) return actionFail(c, res);
  const ride = res.ride;
  pushLater(c, Promise.all([
    pushRideEvent(db, c.env, Number(ride.rider_id), "accepted", id),
    notifyEmail(db, c.env, { key: "email.passenger.driver_assigned", userIds: [Number(ride.rider_id)], rideId: id, dedupe: `reassign:${p.data.driver_id}` }),
    notify(db, c.env, { key: "driver.ride_assigned", userIds: [p.data.driver_id], rideId: id, data: { type: "ride", event: "dispatch_assigned", ride_id: String(id) } }),
    notify(db, c.env, { key: "driver.ride_cancelled_by_admin", userIds: [p.data.expected_driver_id], rideId: id, data: { type: "ride", event: "dispatch_reassigned", ride_id: String(id) } }),
  ]));
  return c.json({ status: true, id, driver_id: p.data.driver_id });
});

adminOpsRoutes.post("/admin/ops/rides/:id/cancel", ...guard("ops_ride cancel"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ category: z.enum(CANCEL_CATEGORIES), reason: reasonText }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { reason: [p.error.issues[0].message] });
  const db = c.get("db");
  const res = await cancelRide(db, { rideId: id, adminId: c.get("user").id, category: p.data.category, reason: p.data.reason });
  if (!res.ok) return actionFail(c, res);
  const ride = res.ride;
  pushLater(c, Promise.all([
    notify(db, c.env, { key: "passenger.ride_cancelled_by_admin", userIds: [Number(ride.rider_id)], rideId: id, data: { type: "ride", event: "admin_cancelled", ride_id: String(id) } }),
    ride.driver_id ? notify(db, c.env, { key: "driver.ride_cancelled_by_admin", userIds: [Number(ride.driver_id)], rideId: id, data: { type: "ride", event: "admin_cancelled", ride_id: String(id) } }) : Promise.resolve(),
  ]));
  return c.json({ status: true, id, cancellation_fee: Number(res.extra?.cancellation_fee ?? 0) });
});

adminOpsRoutes.post("/admin/ops/rides/:id/escalate", ...guard("ops_ride escalate"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({
    category: z.enum(["delay", "driver_unreachable", "passenger_unreachable", "payment", "safety", "vehicle", "other"]),
    severity: z.enum(["normal", "high", "urgent"]).default("normal"), reason: z.string().trim().min(3, "Describe the problem (at least 3 characters).").max(500),
  }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { reason: [p.error.issues[0].message] });
  const db = c.get("db"), admin = c.get("user");
  if (!(await db.query("select 1 from app.ride_requests where id = $1", [id])).rowCount) return notFound(c);
  try {
    await db.query("begin");
    const e = (await db.query("insert into app.ride_escalations (ride_request_id, category, severity, reason, created_by) values ($1,$2,$3,$4,$5) returning id", [id, p.data.category, p.data.severity, p.data.reason, admin.id])).rows[0];
    await db.query("insert into app.ride_dispatch_events (ride_request_id, action, admin_id, reason, detail) values ($1,'escalate',$2,$3,$4)", [id, admin.id, p.data.reason, JSON.stringify({ category: p.data.category, severity: p.data.severity, escalation_id: Number(e.id) })]);
    await db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,'ops_ride_escalate',$2,$3)", [admin.id, String(id), JSON.stringify({ escalation_id: Number(e.id), category: p.data.category, severity: p.data.severity })]);
    await db.query("commit");
    return c.json({ status: true, id: Number(e.id) }, 201);
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") return c.json({ status: false, code: "already_escalated", message: "This problem is already escalated on this ride and still open." }, 409);
    throw e;
  }
});

adminOpsRoutes.get("/admin/ops/escalations", ...guard("ops_ride list"), async (c) => {
  const status = c.req.query("status") === "resolved" ? "resolved" : "open";
  const rows = (await c.get("db").query(
    `select e.id, e.ride_request_id as ride_id, e.category, e.severity, e.reason, e.status, e.created_at, e.resolved_at, e.resolution_note, ${NAME.replace(/u\./g, "a.")} as raised_by
       from app.ride_escalations e left join app.users a on a.id = e.created_by where e.status = $1
      order by case e.severity when 'urgent' then 0 when 'high' then 1 else 2 end, e.id desc limit 100`, [status])).rows;
  return c.json({ status: true, data: rows });
});

adminOpsRoutes.post("/admin/ops/escalations/:id/resolve", ...guard("ops_ride escalate"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c, "Escalation");
  const p = z.object({ note: z.string().trim().max(500).optional() }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { note: [p.error.issues[0].message] });
  const db = c.get("db"), admin = c.get("user");
  const e = (await db.query("update app.ride_escalations set status = 'resolved', resolved_by = $2, resolved_at = now(), resolution_note = $3 where id = $1 and status = 'open' returning ride_request_id", [id, admin.id, p.data.note ?? null])).rows[0];
  if (!e) return c.json({ status: false, code: "not_open", message: "That escalation is already resolved, or does not exist." }, 409);
  await db.query("insert into app.ride_dispatch_events (ride_request_id, action, admin_id, reason, detail) values ($1,'escalation_resolved',$2,$3,$4)", [e.ride_request_id, admin.id, p.data.note ?? null, JSON.stringify({ escalation_id: id })]);
  await db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,'ops_escalation_resolve',$2,$3)", [admin.id, String(e.ride_request_id), JSON.stringify({ escalation_id: id })]);
  return c.json({ status: true });
});

// ---- Contact: phone numbers are shown only on request, and every reveal is logged. Messages go out as push notifications.
const partyOf = async (c: C, rideId: number, party: string) => {
  const r = (await c.get("db").query(
    `select r.rider_id, r.driver_id, p.first_name as pf, p.last_name as pl, p.country_code as pcc, p.contact_number as pnum, d.first_name as df, d.last_name as dl, d.country_code as dcc, d.contact_number as dnum
       from app.ride_requests r join app.users p on p.id = r.rider_id left join app.users d on d.id = r.driver_id where r.id = $1`, [rideId])).rows[0];
  if (!r) return null;
  if (party === "driver") return r.driver_id ? { id: Number(r.driver_id), name: [r.df, r.dl].filter(Boolean).join(" "), phone: [r.dcc, r.dnum].filter(Boolean).join("") } : { none: true as const };
  return { id: Number(r.rider_id), name: [r.pf, r.pl].filter(Boolean).join(" "), phone: [r.pcc, r.pnum].filter(Boolean).join("") };
};
const partySchema = z.enum(["passenger", "driver"]);

adminOpsRoutes.post("/admin/ops/rides/:id/contact", ...guard("ops_ride contact"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ party: partySchema }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { party: ["Choose passenger or driver."] });
  const who = await partyOf(c, id, p.data.party);
  if (!who) return notFound(c);
  if ("none" in who) return c.json({ status: false, code: "no_driver", message: "No driver is assigned to this ride." }, 409);
  const db = c.get("db"), admin = c.get("user");
  await db.query("insert into app.ride_dispatch_events (ride_request_id, action, admin_id, detail) values ($1,'contact_view',$2,$3)", [id, admin.id, JSON.stringify({ party: p.data.party })]);
  await db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,'ops_contact_view',$2,$3)", [admin.id, String(id), JSON.stringify({ party: p.data.party, user_id: who.id })]);
  return c.json({ status: true, party: p.data.party, name: who.name, phone: who.phone || null, note: who.phone ? "Viewing this number is recorded." : "This person has no phone number on file." });
});

adminOpsRoutes.post("/admin/ops/rides/:id/message", ...guard("ops_ride contact"), async (c) => {
  const id = idOf(c);
  if (!id) return notFound(c);
  const p = z.object({ party: partySchema, message: z.string().trim().min(3, "Write a message (at least 3 characters).").max(160, "Keep it to 160 characters.") }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { message: [p.error.issues[0].message] });
  const who = await partyOf(c, id, p.data.party);
  if (!who) return notFound(c);
  if ("none" in who) return c.json({ status: false, code: "no_driver", message: "No driver is assigned to this ride." }, 409);
  const db = c.get("db"), admin = c.get("user");
  const res = await notify(db, c.env, { key: `${p.data.party}.support_update`, userIds: [who.id], rideId: id, vars: { note: p.data.message }, data: { type: "ride", event: "support_message", ride_id: String(id) }, dedupe: null });
  await db.query("insert into app.ride_dispatch_events (ride_request_id, action, admin_id, detail) values ($1,'message',$2,$3)", [id, admin.id, JSON.stringify({ party: p.data.party, sent: res.sent, failed: res.failed, skipped: res.skipped })]);
  await db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,'ops_message',$2,$3)", [admin.id, String(id), JSON.stringify({ party: p.data.party, user_id: who.id, sent: res.sent })]);
  if (res.sent > 0) return c.json({ status: true, delivered: true, message: "Message sent as a notification." });
  const why = res.skipped > 0 ? "The “Support update” notification template is switched off. Turn it on under Push templates." : res.error ?? "The notification could not be delivered (the person may not have notifications on).";
  return c.json({ status: false, delivered: false, code: "not_delivered", message: why }, 409);
});
