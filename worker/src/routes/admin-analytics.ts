import { Hono, type Context } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { guard } from "../lib/permissions";
import { validationFailed } from "../lib/legacy";
import { FREQ_BUCKETS, avg, cohortMature, freqBucket, moneyList, parsePeriod, rate, round2, type Money, type Period } from "../lib/analytics";

/**
 * Driver and passenger analytics. Every figure comes from rides, ratings, events and sessions already in the database, for a stated
 * period of whole calendar days in one time zone. A figure that cannot be measured says why instead of showing 0.
 */
export const adminAnalyticsRoutes = new Hono<AppEnv>();
type C = Context<AppEnv>;
type Row = Record<string, unknown>;
type Metric<T = unknown> = { available: true; value: T; note?: string } | { available: false; reason: string };
const ok = <T>(value: T, note?: string): Metric<T> => ({ available: true, value, ...(note ? { note } : {}) });
const no = (reason: string): Metric<never> => ({ available: false, reason });
const NAME = (a: string) => `coalesce(nullif(btrim(${a}.display_name), ''), nullif(btrim(concat_ws(' ', ${a}.first_name, ${a}.last_name)), ''), ${a}.username)`;
const intOrNull = (v: unknown) => (/^\d{1,15}$/.test(String(v ?? "")) ? Number(v) : null);
const n = (v: unknown) => Number(v ?? 0);

async function bounds(db: Client, p: Period) {
  const r = (await db.query("select (($1::date)::timestamp at time zone $3) as s, ((($2::date) + 1)::timestamp at time zone $3) as e", [p.from, p.to, p.tz])).rows[0];
  return { s: r.s as Date, e: r.e as Date };
}
async function trackingSince(db: Client) {
  const v = (await db.query("select value from app.settings where key = 'analytics_tracking'")).rows[0]?.value as Row | undefined;
  const d = (x: unknown) => (x ? new Date(x as string) : null);
  return { driverEvents: d(v?.driver_events_since), onlineSessions: d(v?.online_sessions_since) };
}
const periodOut = (p: Period, s: Date, e: Date) => ({ from: p.from, to: p.to, timezone: p.tz, days: p.days, starts_at: s.toISOString(), ends_at: e.toISOString(), defaulted: p.defaulted });
const readPeriod = (c: C) => parsePeriod({ from: c.req.query("from"), to: c.req.query("to"), tz: c.req.query("tz") });

// ---------------------------------------------------------------------------------------------------------------------
// Driver performance
// ---------------------------------------------------------------------------------------------------------------------
async function driverMetrics(db: Client, ids: number[], s: Date, e: Date, since: Awaited<ReturnType<typeof trackingSince>>) {
  const out = new Map<number, Row>();
  const get = (id: number) => { let o = out.get(id); if (!o) { o = { money: new Map<string, Row>() }; out.set(id, o); } return o; };
  const evStart = since.driverEvents && since.driverEvents > s ? since.driverEvents : s;
  const osStart = since.onlineSessions && since.onlineSessions > s ? since.onlineSessions : s;
  const meta = { out, evStart, osStart, evOk: evStart < e, osOk: osStart < e };
  if (!ids.length) return meta;
  const inP = (col: string) => `${col} >= $1 and ${col} < $2`;

  for (const r of (await db.query(
    `select r.driver_id,
            count(*) filter (where r.status = 'completed' and ${inP("r.completed_at")}) completed,
            count(*) filter (where ${inP("r.accepted_at")}) accepted_held,
            count(*) filter (where r.status = 'cancelled' and r.accepted_at is not null and ${inP("r.cancelled_at")}) cancelled_assigned,
            count(*) filter (where r.status = 'cancelled' and r.cancelled_by = 'driver' and ${inP("r.cancelled_at")}) cancelled_by_driver,
            count(*) filter (where r.status = 'cancelled' and r.accepted_at is not null and r.cancelled_by = 'rider' and ${inP("r.cancelled_at")}) cancelled_by_rider,
            count(*) filter (where r.status = 'cancelled' and r.accepted_at is not null and r.cancelled_by in ('admin', 'system') and ${inP("r.cancelled_at")}) cancelled_by_admin_system,
            max(r.completed_at) filter (where r.status = 'completed') last_completed_at
       from app.ride_requests r where r.driver_id = any($3::bigint[]) group by 1`, [s, e, ids])).rows) Object.assign(get(Number(r.driver_id)), r);

  for (const r of (await db.query(
    `select r.driver_id, trim(r.currency) cur, count(*)::int rides, sum(r.fare)::float8 gross, sum(coalesce(r.commission, 0))::float8 commission,
            count(*) filter (where r.airport_id is not null)::int airport_rides,
            coalesce(sum(r.fare) filter (where r.airport_id is not null), 0)::float8 airport_gross,
            coalesce(sum(coalesce(r.commission, 0)) filter (where r.airport_id is not null), 0)::float8 airport_commission
       from app.ride_requests r where r.driver_id = any($3::bigint[]) and r.status = 'completed' and ${inP("r.completed_at")} group by 1, 2`, [s, e, ids])).rows) {
    const m = get(Number(r.driver_id)).money as Map<string, Row>;
    m.set(String(r.cur), { currency: String(r.cur), rides: n(r.rides), gross: n(r.gross), commission: n(r.commission), airport_rides: n(r.airport_rides), airport_gross: n(r.airport_gross), airport_commission: n(r.airport_commission), extras: 0 });
  }
  for (const r of (await db.query(
    `select x.driver_id, trim(x.currency) cur, sum(x.amount - x.commission)::float8 extras from app.ride_extras x
      where x.driver_id = any($3::bigint[]) and x.status = 'paid' and ${inP("x.responded_at")} group by 1, 2`, [s, e, ids])).rows) {
    const m = get(Number(r.driver_id)).money as Map<string, Row>;
    const cur = String(r.cur);
    m.set(cur, { ...(m.get(cur) ?? { currency: cur, rides: 0, gross: 0, commission: 0, airport_rides: 0, airport_gross: 0, airport_commission: 0 }), extras: n(r.extras) });
  }
  for (const r of (await db.query(
    `select driver_id, avg(rating) filter (where ${inP("created_at")})::float8 period_avg, count(*) filter (where ${inP("created_at")})::int period_n,
            avg(rating)::float8 all_avg, count(*)::int all_n from app.ride_ratings where driver_id = any($3::bigint[]) group by 1`, [s, e, ids])).rows)
    Object.assign(get(Number(r.driver_id)), { rating_period_avg: r.period_avg, rating_period_n: n(r.period_n), rating_all_avg: r.all_avg, rating_all_n: n(r.all_n) });

  // Recorded since tracking began: who took which offer, who backed out, and how long they were online.
  if (meta.evOk) {
    for (const r of (await db.query(
      `select e.driver_id,
              count(*) filter (where e.event = 'assigned' and not exists (select 1 from app.ride_dispatch_events d where d.ride_request_id = e.ride_request_id and d.to_driver_id = e.driver_id
                   and d.action in ('assign', 'reassign') and d.created_at between e.created_at - interval '2 seconds' and e.created_at + interval '2 seconds'))::int assigned_self,
              count(*) filter (where e.event = 'assigned')::int assigned_all,
              count(*) filter (where e.event = 'released')::int released,
              count(*) filter (where e.event = 'reassigned_away')::int reassigned_away
         from app.driver_ride_events e where e.driver_id = any($3::bigint[]) and e.created_at >= $1 and e.created_at < $2 group by 1`, [evStart, e, ids])).rows)
      Object.assign(get(Number(r.driver_id)), r);
    for (const r of (await db.query(
      `select d.driver_id, count(*)::int declines_raw,
              count(*) filter (where not exists (select 1 from app.driver_ride_events v where v.ride_request_id = d.request_id and v.driver_id = d.driver_id
                   and v.event in ('released', 'reassigned_away') and v.created_at between d.created_at - interval '5 seconds' and d.created_at + interval '5 seconds'))::int declines
         from app.ride_request_declines d where d.driver_id = any($3::bigint[]) and d.created_at >= $1 and d.created_at < $2 group by 1`, [evStart, e, ids])).rows)
      Object.assign(get(Number(r.driver_id)), r);
  }
  if (meta.osOk) {
    for (const r of (await db.query(
      `select driver_id, coalesce(sum(greatest(0, extract(epoch from least(coalesce(ended_at, now()), $2::timestamptz, now()) - greatest(started_at, $1::timestamptz)))), 0)::float8 secs
         from app.driver_online_sessions where driver_id = any($3::bigint[]) and started_at < $2 and coalesce(ended_at, now()) > $1 group by 1`, [osStart, e, ids])).rows)
      get(Number(r.driver_id)).online_seconds = Math.round(n(r.secs));
  }
  return meta;
}

function driverRow(base: Row, m: Row | undefined, meta: { evOk: boolean; osOk: boolean; evStart: Date; osStart: Date }) {
  const g = (k: string) => n(m?.[k]);
  const completed = g("completed"), cancelledAssigned = g("cancelled_assigned");
  const resolved = completed + cancelledAssigned;
  const money = [...(((m?.money as Map<string, Row>) ?? new Map()).values())];
  const sum = (k: string, cur?: string) => money.filter((x) => !cur || x.currency === cur).reduce((t, x) => t + n(x[k]), 0);
  const byCur = (f: (x: Row) => number): Money[] => moneyList(money.map((x) => ({ currency: String(x.currency), amount: f(x) })));
  const assignedSelf = g("assigned_self"), declines = g("declines");
  const tracked = (since: Date, what: string) => `Recorded since ${since.toISOString().slice(0, 10)}; ${what}`;
  return {
    id: Number(base.id), name: base.name, status: base.status, service: base.service_name, vehicle_plate: base.vehicle_plate ?? null, online_now: base.is_online === true,
    total_rides: ok(completed),
    rides_accepted: ok(g("accepted_held"), "Rides this driver holds that were accepted in the period."),
    completion_rate: resolved > 0 ? ok(rate(completed, resolved), `${completed} completed of ${resolved} that ended with this driver (completed or cancelled by anyone).`) : no("No trips ended with this driver in the period."),
    cancellation_rate: resolved > 0 ? ok(rate(g("cancelled_by_driver"), resolved), `${g("cancelled_by_driver")} cancelled by the driver of ${resolved} that ended with this driver. Backing out of an accepted trip is counted separately below.`) : no("No trips ended with this driver in the period."),
    cancelled_by: ok({ driver: g("cancelled_by_driver"), rider: g("cancelled_by_rider"), admin_or_system: g("cancelled_by_admin_system") }),
    rejection_rate: meta.evOk && assignedSelf + declines > 0 ? ok(rate(declines, assignedSelf + declines), tracked(meta.evStart, `${declines} declined of ${assignedSelf + declines} offers the driver answered. Offers they ignored are not recorded.`)) : no(meta.evOk ? "The driver answered no offers in the period." : "Offer answers have been recorded only since tracking began, which is after this period."),
    acceptance_rate: meta.evOk && assignedSelf + declines > 0 ? ok(rate(assignedSelf, assignedSelf + declines), tracked(meta.evStart, `${assignedSelf} accepted of ${assignedSelf + declines} offers the driver answered.`)) : no(meta.evOk ? "The driver answered no offers in the period." : "Offer answers have been recorded only since tracking began, which is after this period."),
    backed_out: meta.evOk ? ok(g("released"), tracked(meta.evStart, "times the driver released a trip after accepting it.")) : no("Recorded only since tracking began, which is after this period."),
    average_rating: m?.rating_period_n ? ok(round2(m.rating_period_avg), `${g("rating_period_n")} rating(s) in the period; ${g("rating_all_n")} overall, average ${round2(m.rating_all_avg)}.`) : m?.rating_all_n ? no(`No ratings in the period. Overall: ${round2(m.rating_all_avg)} from ${g("rating_all_n")}.`) : no("No ratings yet."),
    gross_fares: ok(byCur((x) => n(x.gross))),
    commission: ok(byCur((x) => n(x.commission))),
    earnings: ok(byCur((x) => n(x.gross) - n(x.commission) + n(x.extras)), "Fare minus commission on completed trips, plus paid extra charges net of commission."),
    online_seconds: meta.osOk ? ok(m?.online_seconds == null ? 0 : n(m.online_seconds), tracked(meta.osStart, "online time counts every minute the driver was switched online, including time with an old location.")) : no("Online time has been recorded only since tracking began, which is after this period."),
    airport: ok({ rides: sum("airport_rides"), gross: byCur((x) => n(x.airport_gross)), earnings: byCur((x) => n(x.airport_gross) - n(x.airport_commission)) }),
    last_completed_at: m?.last_completed_at ? new Date(m.last_completed_at as string).toISOString() : null,
  };
}

adminAnalyticsRoutes.get("/admin/analytics/drivers", ...guard("driver_analytics list"), async (c) => {
  const db = c.get("db");
  const p = readPeriod(c);
  if ("error" in p) return validationFailed(c, { from: [p.error] });
  const { s, e } = await bounds(db, p);
  const since = await trackingSince(db);
  const region = intOrNull(c.req.query("region_id")), service = intOrNull(c.req.query("service_id"));
  const q = (c.req.query("q") ?? "").trim().slice(0, 60);
  const base = (await db.query(
    `select u.id, ${NAME("u")} as name, dp.status, dp.vehicle_plate, sv.name as service_name, u.is_online
       from app.driver_profiles dp join app.users u on u.id = dp.user_id left join app.services sv on sv.id = dp.service_id
      where dp.status in ('approved', 'suspended') and u.deleted_at is null
        and ($1::bigint is null or sv.region_id = $1::bigint) and ($2::bigint is null or dp.service_id = $2::bigint)
        and ($3::text = '' or ${NAME("u")} ilike '%' || $3::text || '%' or dp.vehicle_plate ilike '%' || $3::text || '%')
      order by u.id limit 500`, [region, service, q])).rows;
  const mm = await driverMetrics(db, base.map((r) => Number(r.id)), s, e, since);
  const rows = base.map((b) => driverRow(b, mm.out.get(Number(b.id)), mm));
  const sortKey = c.req.query("sort") ?? "total_rides";
  const val = (r: Row, k: string) => { const m = r[k] as Metric | undefined; if (!m || !m.available) return -Infinity; const v = m.value; return Array.isArray(v) ? n((v as Money[]).reduce((t, x) => t + x.amount, 0)) : typeof v === "number" ? v : -Infinity; };
  const allowed = ["total_rides", "earnings", "commission", "completion_rate", "cancellation_rate", "average_rating", "online_seconds", "acceptance_rate"];
  const key = allowed.includes(sortKey) ? sortKey : "total_rides";
  rows.sort((a, b) => val(b, key) - val(a, key) || n(a.id) - n(b.id));
  const completedTotal = rows.reduce((t, r) => t + n((r.total_rides as { value: number }).value), 0);
  return c.json({
    status: true, period: periodOut(p, s, e),
    tracking: { offers_and_backing_out_since: since.driverEvents?.toISOString() ?? null, online_time_since: since.onlineSessions?.toISOString() ?? null,
      note: "Offer answers, backing out and online time were not recorded before these dates and are never estimated for earlier periods." },
    totals: { drivers: rows.length, completed_rides: completedTotal, online_now: rows.filter((r) => r.online_now).length },
    sorted_by: key, data: rows,
    truncated: base.length === 500,
  });
});

adminAnalyticsRoutes.get("/admin/analytics/drivers/:id", ...guard("driver_analytics list"), async (c) => {
  const db = c.get("db");
  const id = Number(c.req.param("id"));
  if (!Number.isSafeInteger(id) || id <= 0) return c.json({ status: false, code: "not_found", message: "Driver not found." }, 404);
  const p = readPeriod(c);
  if ("error" in p) return validationFailed(c, { from: [p.error] });
  const { s, e } = await bounds(db, p);
  const since = await trackingSince(db);
  const b = (await db.query(
    `select u.id, ${NAME("u")} as name, dp.status, dp.vehicle_plate, sv.name as service_name, u.is_online
       from app.driver_profiles dp join app.users u on u.id = dp.user_id left join app.services sv on sv.id = dp.service_id where u.id = $1`, [id])).rows[0];
  if (!b) return c.json({ status: false, code: "not_found", message: "Driver not found." }, 404);
  const mm = await driverMetrics(db, [id], s, e, since);
  const row = driverRow(b, mm.out.get(id), mm);
  const hours = (await db.query(
    `select extract(hour from completed_at at time zone $4)::int h, extract(dow from completed_at at time zone $4)::int d, count(*)::int n
       from app.ride_requests where driver_id = $3 and status = 'completed' and completed_at >= $1 and completed_at < $2 group by 1, 2`, [s, e, id, p.tz])).rows;
  const byHour = Array.from({ length: 24 }, (_, h) => hours.filter((r) => Number(r.h) === h).reduce((t, r) => t + n(r.n), 0));
  const byDow = Array.from({ length: 7 }, (_, d) => hours.filter((r) => Number(r.d) === d).reduce((t, r) => t + n(r.n), 0));
  const air = (await db.query(
    `select r.airport_direction dir, count(*)::int rides, trim(r.currency) cur, sum(r.fare)::float8 gross, sum(coalesce(r.commission, 0))::float8 commission
       from app.ride_requests r where r.driver_id = $3 and r.status = 'completed' and r.airport_id is not null and r.completed_at >= $1 and r.completed_at < $2 group by 1, 3`, [s, e, id])).rows;
  const stars = (await db.query("select rating, count(*)::int n from app.ride_ratings where driver_id = $1 and created_at >= $2 and created_at < $3 group by 1", [id, s, e])).rows;
  return c.json({
    status: true, period: periodOut(p, s, e), data: row,
    activity: { timezone: p.tz, completed_by_hour: byHour, completed_by_weekday: byDow, weekday_labels: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
      note: "When this driver completed trips. Online time by hour is not broken down." },
    airport_detail: air.map((r) => ({ direction: r.dir, rides: n(r.rides), currency: r.cur, gross: n(r.gross), earnings: round2(n(r.gross) - n(r.commission)) })),
    rating_counts: [1, 2, 3, 4, 5].map((k) => ({ stars: k, count: n(stars.find((r) => Number(r.rating) === k)?.n) })),
  });
});

// ---------------------------------------------------------------------------------------------------------------------
// Passengers
// ---------------------------------------------------------------------------------------------------------------------
adminAnalyticsRoutes.get("/admin/analytics/passengers", ...guard("passenger_analytics list"), async (c) => {
  const db = c.get("db");
  const p = readPeriod(c);
  if ("error" in p) return validationFailed(c, { from: [p.error] });
  const { s, e } = await bounds(db, p);
  const region = intOrNull(c.req.query("region_id"));
  const dormantDays = Math.min(Math.max(intOrNull(c.req.query("dormant_days")) ?? 30, 7), 365);
  const asOf = new Date(Math.min(e.getTime(), Date.now()));
  const rideScope = "($3::bigint is null or r.region_id = $3::bigint)";

  // Accounts have no region, so account figures are unavailable when a region is chosen.
  const acc = region ? null : (await db.query(
    `select count(*) filter (where created_at < $2)::int total, count(*) filter (where created_at >= $1 and created_at < $2)::int fresh
       from app.users where 'rider' = any(roles) and deleted_at is null and user_type <> 'admin'`, [s, e])).rows[0];

  const life = (await db.query(
    `select count(*)::int requested,
            count(*) filter (where r.status = 'completed')::int completed,
            count(*) filter (where r.status = 'cancelled')::int cancelled,
            count(*) filter (where r.status = 'expired')::int expired,
            count(*) filter (where r.status in ('searching', 'accepted', 'arrived', 'in_progress'))::int in_flight,
            count(*) filter (where r.status = 'cancelled' and r.cancelled_by = 'rider' and r.accepted_at is null)::int rider_before_driver,
            count(*) filter (where r.status = 'cancelled' and r.cancelled_by = 'rider' and r.accepted_at is not null)::int rider_after_driver,
            count(*) filter (where r.status = 'cancelled' and r.cancelled_by = 'driver')::int by_driver,
            count(*) filter (where r.status = 'cancelled' and r.cancelled_by in ('admin', 'system'))::int by_admin_system,
            count(distinct r.rider_id)::int active
       from app.ride_requests r where r.created_at >= $1 and r.created_at < $2 and ${rideScope}`, [s, e, region])).rows[0];

  const comp = (await db.query(
    `select r.rider_id, count(*)::int rides from app.ride_requests r
      where r.status = 'completed' and r.completed_at >= $1 and r.completed_at < $2 and ${rideScope} group by 1`, [s, e, region])).rows;
  const freq: Record<string, number> = Object.fromEntries(FREQ_BUCKETS.map((b) => [b, 0]));
  for (const r of comp) freq[freqBucket(n(r.rides))]++;
  const completedRides = comp.reduce((t, r) => t + n(r.rides), 0);

  const spend = (await db.query(
    `select trim(r.currency) cur, sum(r.fare)::float8 total, count(*)::int rides, count(distinct r.rider_id)::int riders
       from app.ride_requests r where r.status = 'completed' and r.completed_at >= $1 and r.completed_at < $2 and ${rideScope} group by 1 order by 1`, [s, e, region])).rows;

  const kinds = (await db.query(
    `with first as (select rider_id, min(completed_at) first_at from app.ride_requests where status = 'completed' group by 1),
          inp as (select distinct r.rider_id from app.ride_requests r where r.status = 'completed' and r.completed_at >= $1 and r.completed_at < $2 and ${rideScope})
     select count(*) filter (where f.first_at >= $1 and f.first_at < $2)::int first_time,
            count(*) filter (where f.first_at < $1)::int as returning_riders
       from inp join first f on f.rider_id = inp.rider_id`, [s, e, region])).rows[0];

  const repeat = (await db.query(
    `select count(*)::int n from (select r.rider_id from app.ride_requests r where r.status = 'cancelled' and r.cancelled_by = 'rider' and r.cancelled_at >= $1 and r.cancelled_at < $2 and ${rideScope}
       group by 1 having count(*) >= 3) x`, [s, e, region])).rows[0];

  // Dormant: had at least one completed ride, and none in the last N days up to the end of the period (or today, if sooner).
  const dormant = (await db.query(
    `with last as (select r.rider_id, max(r.completed_at) last_at from app.ride_requests r where r.status = 'completed' and r.completed_at < $2 and ${rideScope} group by 1)
     select count(*) filter (where last_at < $1::timestamptz - make_interval(days => $4::int))::int dormant,
            count(*) filter (where last_at < $1::timestamptz - make_interval(days => $4::int) and last_at >= $1::timestamptz - make_interval(days => $4::int * 2))::int d1,
            count(*) filter (where last_at < $1::timestamptz - make_interval(days => $4::int * 2) and last_at >= $1::timestamptz - make_interval(days => $4::int * 3))::int d2,
            count(*) filter (where last_at < $1::timestamp with time zone - make_interval(days => $4::int * 3))::int d3,
            count(*)::int ever from last`, [asOf, e, region, dormantDays])).rows[0];

  // Retention: of riders whose first completed ride fell in a month, the share who rode again within 30 days. Reported only for months in which
  // every rider has had the full 30 days.
  const cohorts = (await db.query(
    `with first as (select rider_id, min(completed_at) first_at from app.ride_requests where status = 'completed' and ${rideScope.replace("r.region_id", "region_id")} group by 1),
          c as (select rider_id, first_at, date_trunc('month', first_at at time zone $4) m from first
                 where $1::timestamptz is not null and first_at >= (date_trunc('month', $2::timestamptz at time zone $4) - interval '11 months') at time zone $4 and first_at < $2)
     select to_char(c.m, 'YYYY-MM') as month, (c.m + interval '1 month' - interval '1 day')::date::text last_day, count(*)::int size,
            count(*) filter (where exists (select 1 from app.ride_requests r where r.rider_id = c.rider_id and r.status = 'completed' and r.completed_at > c.first_at
                                              and r.completed_at <= c.first_at + interval '30 days'))::int retained
       from c group by c.m order by c.m`, [s, e, region, p.tz])).rows;
  const today = (await db.query("select (now() at time zone $1)::date::text d", [p.tz])).rows[0].d as string;

  const week = p.days > 92;
  const trend = (await db.query(
    `select to_char(date_trunc($4, r.created_at at time zone $5), 'YYYY-MM-DD') bucket, count(*)::int requested,
            count(*) filter (where r.status = 'completed')::int completed, count(distinct r.rider_id)::int active
       from app.ride_requests r where r.created_at >= $1 and r.created_at < $2 and ${rideScope} group by 1 order by 1`, [s, e, region, week ? "week" : "day", p.tz])).rows;
  const signups = region ? [] : (await db.query(
    `select to_char(date_trunc($3, created_at at time zone $4), 'YYYY-MM-DD') bucket, count(*)::int n from app.users
      where 'rider' = any(roles) and deleted_at is null and user_type <> 'admin' and created_at >= $1 and created_at < $2 group by 1`, [s, e, week ? "week" : "day", p.tz])).rows;

  const resolved = n(life.completed) + n(life.cancelled) + n(life.expired);
  return c.json({
    status: true, period: periodOut(p, s, e), region_id: region,
    definitions: {
      period: "Whole calendar days in the chosen time zone, both ends included.",
      passenger: "An account with the rider role that is not deleted.",
      active: "A passenger who requested at least one ride in the period.",
      first_time: "Completed their first ever trip in the period.",
      returning: "Completed a trip in the period and had completed at least one before it.",
      booking_completion: "Completed trips as a share of requests that have ended (completed, cancelled or expired). Requests still in progress are left out.",
      retention: "Of passengers whose first completed trip was in a month, the share who completed another within 30 days. Shown only once all of them have had 30 days.",
      dormant: `Completed a trip before, but none in the ${dormantDays} days up to ${asOf.toISOString().slice(0, 10)}.`,
    },
    total_passengers: acc ? ok(n(acc.total)) : no("Accounts do not belong to a region, so this cannot be split by region."),
    new_passengers: acc ? ok(n(acc.fresh)) : no("Accounts do not belong to a region, so this cannot be split by region."),
    active_passengers: ok(n(life.active)),
    first_time_riders: ok(n(kinds?.first_time)), returning_riders: ok(n(kinds?.returning_riders)),
    requests: { requested: n(life.requested), completed: n(life.completed), cancelled: n(life.cancelled), expired: n(life.expired), in_flight: n(life.in_flight) },
    booking_completion: resolved > 0 ? ok(rate(n(life.completed), resolved), `${n(life.completed)} completed of ${resolved} requests that ended.`) : no("No requests ended in the period."),
    cancellation_behaviour: {
      by_passenger_before_driver: n(life.rider_before_driver), by_passenger_after_driver: n(life.rider_after_driver), by_driver: n(life.by_driver), by_admin_or_system: n(life.by_admin_system), expired_unmatched: n(life.expired),
      passenger_cancel_rate: resolved > 0 ? ok(rate(n(life.rider_before_driver) + n(life.rider_after_driver), resolved)) : no("No requests ended in the period."),
      repeat_cancellers: ok(n(repeat?.n), "Passengers who cancelled 3 or more trips themselves in the period."),
    },
    ride_frequency: {
      completed_rides_per_passenger: comp.length ? ok(avg(completedRides, comp.length)) : no("No completed trips in the period."),
      distribution: FREQ_BUCKETS.map((b) => ({ rides: b, passengers: freq[b] })),
    },
    average_spend: spend.length ? ok({
      per_completed_ride: moneyList(spend.map((r) => ({ currency: r.cur as string, amount: n(r.total) / Math.max(n(r.rides), 1) }))),
      per_paying_passenger: moneyList(spend.map((r) => ({ currency: r.cur as string, amount: n(r.total) / Math.max(n(r.riders), 1) }))),
    }, "Trip fares only. Cancellation fees and extra charges are not included.") : no("No completed trips in the period."),
    retention: cohorts.map((r) => {
      const mature = cohortMature(String(r.last_day), 30, today);
      return { month: r.month, size: n(r.size), retained: mature ? n(r.retained) : null, rate: mature ? rate(n(r.retained), n(r.size)) : null, measurable: mature };
    }),
    dormant: { days: dormantDays, passengers: n(dormant?.dormant), of_riders_who_ever_completed: n(dormant?.ever),
      lapsed_for: [{ label: `${dormantDays}-${dormantDays * 2 - 1} days`, passengers: n(dormant?.d1) }, { label: `${dormantDays * 2}-${dormantDays * 3 - 1} days`, passengers: n(dormant?.d2) }, { label: `${dormantDays * 3}+ days`, passengers: n(dormant?.d3) }] },
    trend: { granularity: week ? "week" : "day", points: trend.map((r) => ({ bucket: r.bucket, requested: n(r.requested), completed: n(r.completed), active_passengers: n(r.active), new_accounts: signups.find((x) => x.bucket === r.bucket) ? n(signups.find((x) => x.bucket === r.bucket)!.n) : 0 })) },
  });
});
