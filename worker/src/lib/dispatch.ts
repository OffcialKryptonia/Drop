import type { Client } from "pg";
import type { Bindings } from "../env";
import { haversineKm } from "./routing";
import { getGlobalMinBalance } from "./commission";
import { getSetting } from "./driver-application";
import { issuePickupCode } from "./pickup";
import { voidExtrasForRide } from "./extras";
import { chargeCancellationFee } from "./ride-settlement";

type Row = Record<string, unknown>;

/** A driver's phone reported within this many seconds is "live". Matches the passenger-facing ETA rule. */
export const FRESH_SECONDS = 90;
export const OPEN_STATUSES = ["accepted", "arrived", "in_progress"] as const;

// ---------------------------------------------------------------------------------------------------------------------
// Location freshness: stale or missing locations are shown as such, never as a guess.
// ---------------------------------------------------------------------------------------------------------------------
export type Freshness = { state: "fresh" | "delayed" | "stale" | "unknown"; age_seconds: number | null };

export function locationFreshness(at: unknown, now: number, staleMinutes: number): Freshness {
  if (!at) return { state: "unknown", age_seconds: null };
  const t = new Date(at as string).getTime();
  if (!Number.isFinite(t)) return { state: "unknown", age_seconds: null };
  const age = Math.max(0, Math.round((now - t) / 1000));
  if (age <= FRESH_SECONDS) return { state: "fresh", age_seconds: age };
  return { state: age <= staleMinutes * 60 ? "delayed" : "stale", age_seconds: age };
}

// ---------------------------------------------------------------------------------------------------------------------
// Driver state on the fleet map.
// ---------------------------------------------------------------------------------------------------------------------
export type FleetState = "available" | "unavailable" | "approaching_pickup" | "arrived" | "on_trip" | "multi_stop";

export function fleetState(d: { is_available?: unknown; ride_status?: unknown; stops_total?: unknown }): FleetState {
  switch (d.ride_status) {
    case "accepted": return "approaching_pickup";
    case "arrived": return "arrived";
    case "in_progress": return Number(d.stops_total ?? 0) > 0 ? "multi_stop" : "on_trip";
    default: return d.is_available === true ? "available" : "unavailable";
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Who may be assigned? One pure function, used to show the dispatcher why a driver is blocked AND to re-check inside the
// assignment transaction, so the screen and the server can never disagree.
// ---------------------------------------------------------------------------------------------------------------------
export type DriverFacts = {
  id: number; user_status: string | null; has_role: boolean; active_mode: string | null; profile_status: string | null;
  is_online: boolean; is_available: boolean; open_ride_id: number | null; accepts_standard: boolean | null;
  service_id: number | null; service_region_id: number | null;
  vehicle_plate: string | null; vehicle_seats: number | null;
  docs_expired: boolean; wallet_balance: number; wallet_minimum: number;
  latitude: number | null; longitude: number | null; location_at: unknown;
};
export type RideFacts = { id: number; rider_id: number; service_id: number; region_id: number | null; capacity: number };
export type Reason = { code: string; message: string };
export type Verdict = { eligible: boolean; reasons: Reason[]; warnings: Reason[] };

export function evaluateDriver(ride: RideFacts, d: DriverFacts, o: { now: number; staleMinutes: number; currentDriverId?: number | null }): Verdict {
  const reasons: Reason[] = [], warnings: Reason[] = [];
  const no = (code: string, message: string) => reasons.push({ code, message });
  if (!d.has_role || !d.profile_status) no("not_driver", "This person has no driver profile.");
  else if (d.profile_status === "suspended") no("suspended", "Driver is suspended.");
  else if (d.profile_status !== "approved") no("not_approved", "Driver is not approved.");
  if (d.user_status !== "active") no("account_inactive", "Driver account is not active.");
  if (d.id === ride.rider_id) no("is_passenger", "A person cannot drive their own ride.");
  if (o.currentDriverId != null && d.id === o.currentDriverId) no("already_assigned", "This driver already has this ride.");
  if (d.active_mode !== "driver") no("not_in_driver_mode", "Driver is in Passenger mode.");
  if (!d.is_online) no("offline", "Driver is offline.");
  if (d.open_ride_id != null) no("on_ride", `Driver is already on ride #${d.open_ride_id}.`);
  else if (d.is_online && !d.is_available) no("unavailable", "Driver is marked unavailable.");
  if (d.accepts_standard === false) no("standard_requests_off", "Driver has switched standard requests off.");
  if (d.service_id == null || d.service_id !== ride.service_id) no("wrong_ride_type", "Driver is registered for a different ride type.");
  if (ride.region_id != null && d.service_region_id != null && d.service_region_id !== ride.region_id) no("wrong_region", "Driver's ride type belongs to a different region.");
  if (d.vehicle_seats != null && d.vehicle_seats < ride.capacity) no("vehicle_incompatible", `Vehicle has ${d.vehicle_seats} seat(s); this ride type needs ${ride.capacity}.`);
  if (d.vehicle_seats == null) warnings.push({ code: "seats_unknown", message: "Vehicle seat count is not on file." });
  if (!d.vehicle_plate) warnings.push({ code: "plate_missing", message: "No vehicle plate on file." });
  if (d.docs_expired) no("documents_expired", "A required document has expired.");
  if (d.wallet_balance < d.wallet_minimum) no("wallet_below_minimum", `Wallet is below the minimum of ${d.wallet_minimum}.`);
  const fresh = locationFreshness(d.location_at, o.now, o.staleMinutes);
  if (d.latitude == null || d.longitude == null || fresh.state === "unknown") no("location_unknown", "Driver has not shared a location.");
  else if (fresh.state === "stale") no("location_stale", "Driver's location is out of date.");
  else if (fresh.state === "delayed") warnings.push({ code: "location_delayed", message: "Driver's location is a little behind." });
  return { eligible: reasons.length === 0, reasons, warnings };
}

export const DRIVER_FACTS_SQL = `
  select u.id, u.display_name, u.first_name, u.last_name, u.username, u.status as user_status, u.active_mode, ('driver' = any(u.roles)) as has_role,
         u.is_online, u.is_available, u.latitude, u.longitude, u.last_location_update_at as location_at, u.created_at as member_since,
         p.status as profile_status, p.service_id, p.vehicle_make, p.vehicle_model, p.vehicle_year, p.vehicle_colour, p.vehicle_plate, p.vehicle_seats,
         p.accepts_standard, s.region_id as service_region_id, s.name as service_name, s.category as service_category,
         (select r.id from app.ride_requests r where r.driver_id = u.id and r.status in ('accepted', 'arrived', 'in_progress') limit 1) as open_ride_id,
         exists (select 1 from app.driver_documents dd join app.documents d on d.id = dd.document_id
                  where dd.driver_id = u.id and d.is_required and dd.expire_date is not null and dd.expire_date < current_date) as docs_expired,
         coalesce((select w.balance from app.wallets w where w.user_id = u.id and w.kind = 'driver'), 0) as wallet_balance,
         coalesce(s.min_wallet_balance, $2::numeric) as wallet_minimum
    from app.users u
    left join app.driver_profiles p on p.user_id = u.id
    left join app.services s on s.id = p.service_id
   where u.id = any($1::bigint[]) and u.deleted_at is null`;

export const toFacts = (r: Row): DriverFacts => ({
  id: Number(r.id), user_status: (r.user_status as string) ?? null, has_role: r.has_role === true, active_mode: (r.active_mode as string) ?? null,
  profile_status: (r.profile_status as string) ?? null, is_online: r.is_online === true, is_available: r.is_available === true,
  open_ride_id: r.open_ride_id == null ? null : Number(r.open_ride_id), accepts_standard: r.accepts_standard == null ? null : r.accepts_standard === true,
  service_id: r.service_id == null ? null : Number(r.service_id), service_region_id: r.service_region_id == null ? null : Number(r.service_region_id),
  vehicle_plate: (r.vehicle_plate as string) || null, vehicle_seats: r.vehicle_seats == null ? null : Number(r.vehicle_seats),
  docs_expired: r.docs_expired === true, wallet_balance: Number(r.wallet_balance ?? 0), wallet_minimum: Number(r.wallet_minimum ?? 0),
  latitude: r.latitude == null ? null : Number(r.latitude), longitude: r.longitude == null ? null : Number(r.longitude), location_at: r.location_at,
});

export const personName = (r: Row) => String(r.display_name || [r.first_name, r.last_name].filter(Boolean).join(" ") || r.username || `#${r.id}`);

export async function loadFacts(db: Client, ids: number[]): Promise<Row[]> {
  if (!ids.length) return [];
  return (await db.query(DRIVER_FACTS_SQL, [ids, await getGlobalMinBalance(db)])).rows;
}

export const rideFactsOf = (r: Row, capacity: unknown): RideFacts => ({
  id: Number(r.id), rider_id: Number(r.rider_id), service_id: Number(r.service_id), region_id: r.region_id == null ? null : Number(r.region_id), capacity: Number(capacity ?? 1),
});

// ---------------------------------------------------------------------------------------------------------------------
// Candidates for one ride: every online driver, nearest first, eligible ones before blocked ones.
// ---------------------------------------------------------------------------------------------------------------------
export async function candidatesFor(db: Client, ride: Row, o: { currentDriverId?: number | null; limit?: number } = {}) {
  const capacity = (await db.query("select capacity from app.services where id = $1", [ride.service_id])).rows[0]?.capacity;
  const rf = rideFactsOf(ride, capacity);
  const staleMinutes = await getSetting(db, "driver_location_stale_minutes", 10);
  const ids = (await db.query(
    `select u.id from app.users u join app.driver_profiles p on p.user_id = u.id
      where u.deleted_at is null and u.is_online and p.status in ('approved', 'suspended')
      order by u.last_location_update_at desc nulls last limit 300`)).rows.map((r) => Number(r.id));
  const now = Date.now();
  const pickup = { lat: Number(ride.pickup_lat), lng: Number(ride.pickup_lng) };
  const out = (await loadFacts(db, ids)).map((row) => {
    const f = toFacts(row);
    const v = evaluateDriver(rf, f, { now, staleMinutes, currentDriverId: o.currentDriverId ?? null });
    const km = f.latitude != null && f.longitude != null ? Math.round(haversineKm({ lat: f.latitude, lng: f.longitude }, pickup) * 10) / 10 : null;
    return {
      id: f.id, name: personName(row), eligible: v.eligible, reasons: v.reasons, warnings: v.warnings,
      status: fleetState({ is_available: f.is_available, ride_status: null }), on_ride_id: f.open_ride_id,
      distance_km: km, location: locationFreshness(f.location_at, now, staleMinutes),
      vehicle: { description: [row.vehicle_make, row.vehicle_model].filter(Boolean).join(" ") || null, colour: row.vehicle_colour ?? null, plate: f.vehicle_plate, seats: f.vehicle_seats },
      ride_type: { id: f.service_id, name: row.service_name ?? null }, ride_type_matches: f.service_id === rf.service_id,
    };
  });
  out.sort((a, b) => Number(b.eligible) - Number(a.eligible) || (a.distance_km ?? 1e9) - (b.distance_km ?? 1e9));
  const top = out.slice(0, o.limit ?? 60);
  // Workload: how busy each listed driver has been today (completed rides, and rides taken so far).
  if (top.length) {
    const w = (await db.query(
      `select driver_id, count(*) filter (where status = 'completed' and completed_at >= now() - interval '24 hours')::int as completed_24h,
              count(*) filter (where accepted_at >= now() - interval '24 hours')::int as taken_24h
         from app.ride_requests where driver_id = any($1::bigint[]) and (accepted_at >= now() - interval '24 hours' or completed_at >= now() - interval '24 hours')
        group by driver_id`, [top.map((d) => d.id)])).rows;
    const by = new Map(w.map((r) => [Number(r.driver_id), r]));
    return top.map((d) => ({ ...d, workload: { completed_24h: Number(by.get(d.id)?.completed_24h ?? 0), taken_24h: Number(by.get(d.id)?.taken_24h ?? 0), on_ride: d.on_ride_id != null } }));
  }
  return top.map((d) => ({ ...d, workload: { completed_24h: 0, taken_24h: 0, on_ride: d.on_ride_id != null } }));
}

// ---------------------------------------------------------------------------------------------------------------------
// Atomic actions. Each one is a single transaction: lock the ride row, lock the driver rows, re-check every rule with the
// locked data, then change. The existing unique indexes (one open ride per driver, one per passenger) are the final guard.
// ---------------------------------------------------------------------------------------------------------------------
export type Fail = { ok: false; status: number; code: string; message: string; reasons?: Reason[] };
export type Done<T = Row> = { ok: true; ride: T; extra?: Row };

const fail = (status: number, code: string, message: string, reasons?: Reason[]): Fail => ({ ok: false, status, code, message, reasons });
const logRow = (db: Client, rideId: number, action: string, adminId: number, from: number | null, to: number | null, reason: string | null, detail: Row = {}) =>
  db.query("insert into app.ride_dispatch_events (ride_request_id, action, admin_id, from_driver_id, to_driver_id, reason, detail) values ($1,$2,$3,$4,$5,$6,$7)",
    [rideId, action, adminId, from, to, reason, JSON.stringify(detail)]);
const auditRow = (db: Client, adminId: number, action: string, rideId: number, detail: Row) =>
  db.query("insert into app.admin_audit (admin_id, action, target, detail) values ($1,$2,$3,$4)", [adminId, action, String(rideId), JSON.stringify(detail)]);

async function lockDrivers(db: Client, ids: number[]) {
  // Always in id order, so two dispatchers touching the same pair of drivers cannot deadlock.
  for (const id of [...new Set(ids)].sort((a, b) => a - b)) await db.query("select id from app.users where id = $1 for update", [id]);
}

async function checkNewDriver(db: Client, ride: Row, driverId: number, currentDriverId: number | null): Promise<Fail | null> {
  const capacity = (await db.query("select capacity from app.services where id = $1", [ride.service_id])).rows[0]?.capacity;
  const row = (await loadFacts(db, [driverId]))[0];
  if (!row) return fail(404, "driver_not_found", "Driver not found.");
  const v = evaluateDriver(rideFactsOf(ride, capacity), toFacts(row), { now: Date.now(), staleMinutes: await getSetting(db, "driver_location_stale_minutes", 10), currentDriverId });
  return v.eligible ? null : fail(409, "driver_not_eligible", v.reasons[0].message, v.reasons);
}

export async function assignDriver(db: Client, env: Bindings, o: { rideId: number; driverId: number; adminId: number; note?: string | null }): Promise<Done | Fail> {
  await db.query("begin");
  try {
    const ride = (await db.query("select * from app.ride_requests where id = $1 for update", [o.rideId])).rows[0];
    if (!ride) { await db.query("rollback"); return fail(404, "ride_not_found", "Ride not found."); }
    if (ride.status !== "searching" || ride.driver_id != null) { await db.query("rollback"); return fail(409, "ride_not_open", ride.driver_id != null ? "This ride already has a driver. Use Reassign." : `This ride is ${ride.status}, so it cannot be assigned.`); }
    if (ride.expires_at && new Date(ride.expires_at as string).getTime() <= Date.now()) { await db.query("rollback"); return fail(409, "ride_expired", "This request has expired. The passenger must request again."); }
    if (ride.bid_id != null) { await db.query("rollback"); return fail(409, "bid_ride", "This ride came from a fare negotiation and cannot be assigned from Dispatch."); }
    await lockDrivers(db, [o.driverId]);
    const bad = await checkNewDriver(db, ride, o.driverId, null);
    if (bad) { await db.query("rollback"); return bad; }
    const upd = await db.query(
      `update app.ride_requests set status = 'accepted', driver_id = $2, accepted_at = now()
        where id = $1 and status = 'searching' and driver_id is null and expires_at > now() and bid_id is null returning *`, [o.rideId, o.driverId]);
    if (!upd.rowCount) { await db.query("rollback"); return fail(409, "ride_changed", "The ride changed while you were assigning. Refresh and check it."); }
    await db.query("update app.users set is_available = false where id = $1", [o.driverId]);
    await issuePickupCode(db, env.SETTINGS_ENCRYPTION_KEY, o.rideId);
    await logRow(db, o.rideId, "assign", o.adminId, null, o.driverId, o.note ?? null);
    await auditRow(db, o.adminId, "ops_ride_assign", o.rideId, { driver_id: o.driverId, passenger_id: Number(ride.rider_id) });
    await db.query("commit");
    return { ok: true, ride: upd.rows[0] };
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") return fail(409, "duplicate_assignment", "That driver was just given another ride. Pick another driver.");
    throw e;
  }
}

export async function reassignDriver(db: Client, env: Bindings, o: { rideId: number; driverId: number; expectedDriverId: number; adminId: number; reason: string }): Promise<Done | Fail> {
  await db.query("begin");
  try {
    const ride = (await db.query("select * from app.ride_requests where id = $1 for update", [o.rideId])).rows[0];
    if (!ride) { await db.query("rollback"); return fail(404, "ride_not_found", "Ride not found."); }
    if (!["accepted", "arrived"].includes(String(ride.status))) { await db.query("rollback"); return fail(409, "cannot_reassign", ride.status === "in_progress" ? "The trip has started. A driver cannot be changed mid-trip; escalate instead." : `This ride is ${ride.status}, so the driver cannot be changed.`); }
    if (Number(ride.driver_id) !== o.expectedDriverId) { await db.query("rollback"); return fail(409, "driver_changed", "The driver on this ride changed. Refresh and check it."); }
    if (ride.bid_id != null) { await db.query("rollback"); return fail(409, "bid_ride", "This ride has a negotiated fare for one driver and cannot be reassigned. Cancel it instead."); }
    await lockDrivers(db, [o.driverId, o.expectedDriverId]);
    const bad = await checkNewDriver(db, ride, o.driverId, o.expectedDriverId);
    if (bad) { await db.query("rollback"); return bad; }
    const upd = await db.query(
      `update app.ride_requests set driver_id = $2, status = 'accepted', accepted_at = now(), arrived_at = null
        where id = $1 and driver_id = $3 and status in ('accepted', 'arrived') returning *`, [o.rideId, o.driverId, o.expectedDriverId]);
    if (!upd.rowCount) { await db.query("rollback"); return fail(409, "ride_changed", "The ride changed while you were reassigning. Refresh and check it."); }
    await db.query("update app.users set is_available = true where id = $1 and is_online", [o.expectedDriverId]);
    await db.query("update app.users set is_available = false where id = $1", [o.driverId]);
    await db.query("insert into app.ride_request_declines (request_id, driver_id) values ($1, $2) on conflict do nothing", [o.rideId, o.expectedDriverId]);
    await voidExtrasForRide(db, o.rideId);
    await issuePickupCode(db, env.SETTINGS_ENCRYPTION_KEY, o.rideId);
    await logRow(db, o.rideId, "reassign", o.adminId, o.expectedDriverId, o.driverId, o.reason);
    await auditRow(db, o.adminId, "ops_ride_reassign", o.rideId, { from_driver_id: o.expectedDriverId, to_driver_id: o.driverId, reason: o.reason, status_before: ride.status });
    await db.query("commit");
    return { ok: true, ride: upd.rows[0], extra: { status_before: ride.status } };
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    if ((e as { code?: string }).code === "23505") return fail(409, "duplicate_assignment", "That driver was just given another ride. Pick another driver.");
    throw e;
  }
}

export const CANCEL_CATEGORIES = ["passenger_request", "no_driver_available", "driver_unreachable", "passenger_unreachable", "safety", "duplicate", "operational_issue", "other"] as const;
export type CancelCategory = (typeof CANCEL_CATEGORIES)[number];

/**
 * Cancels a ride that has not started. The ride type's own cancellation-fee rule is applied ONLY when the passenger asked
 * to cancel; an operational cancellation never charges the passenger. in_progress rides cannot be cancelled from here.
 */
export async function cancelRide(db: Client, o: { rideId: number; adminId: number; category: CancelCategory; reason: string }): Promise<Done | Fail> {
  let before: Row;
  await db.query("begin");
  try {
    before = (await db.query("select * from app.ride_requests where id = $1 for update", [o.rideId])).rows[0];
    if (!before) { await db.query("rollback"); return fail(404, "ride_not_found", "Ride not found."); }
    if (!["searching", "accepted", "arrived"].includes(String(before.status))) {
      await db.query("rollback");
      return fail(409, "cannot_cancel", before.status === "in_progress" ? "The trip has started. It cannot be cancelled from Admin; escalate it instead." : `This ride is already ${before.status}.`);
    }
    await db.query("update app.ride_requests set status = 'cancelled', cancelled_by = 'admin', cancel_reason = $2, cancelled_at = now() where id = $1", [o.rideId, `${o.category}: ${o.reason}`.slice(0, 300)]);
    if (before.driver_id) {
      await db.query("update app.users set is_available = true where id = $1 and is_online", [before.driver_id]);
      await voidExtrasForRide(db, o.rideId);
    }
    await logRow(db, o.rideId, "cancel", o.adminId, before.driver_id == null ? null : Number(before.driver_id), null, o.reason, { category: o.category, status_before: before.status });
    await auditRow(db, o.adminId, "ops_ride_cancel", o.rideId, { category: o.category, reason: o.reason, status_before: before.status, passenger_id: Number(before.rider_id) });
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
  let fee = 0;
  if (o.category === "passenger_request" && before.driver_id) {
    fee = await chargeCancellationFee(db, { ...before, status_before: before.status }, await getSetting(db, "ride_cancel_grace_seconds", 120));
  }
  return { ok: true, ride: before, extra: { cancellation_fee: fee } };
}

// ---------------------------------------------------------------------------------------------------------------------
// Live ride list filters. "Pending" = waiting for any driver; "Unassigned" = waiting longer than the threshold (needs a
// dispatcher). "Assigned" = has a driver and is not finished; "Driver approaching" = accepted, "Driver arrived" = arrived.
// ---------------------------------------------------------------------------------------------------------------------
export const RIDE_FILTERS = ["pending", "unassigned", "assigned", "approaching", "arrived", "in_progress", "multi_stop", "airport_pickup", "airport_drop", "completed", "cancelled", "expired", "all_live"] as const;
export type RideFilter = (typeof RIDE_FILTERS)[number];

const HAS_STOPS = "exists (select 1 from app.ride_request_stops st where st.ride_request_id = r.id)";
/** SQL for a filter. $1 = unassigned threshold seconds, $2 = start of the window for finished rides. */
export const filterSql = (f: RideFilter): string => ({
  pending: "r.status = 'searching' and r.expires_at > now()",
  unassigned: "r.status = 'searching' and r.expires_at > now() and r.created_at <= now() - make_interval(secs => $1::int)",
  assigned: "r.driver_id is not null and r.status in ('accepted', 'arrived', 'in_progress')",
  approaching: "r.status = 'accepted'",
  arrived: "r.status = 'arrived'",
  in_progress: "r.status = 'in_progress'",
  multi_stop: `r.status in ('searching', 'accepted', 'arrived', 'in_progress') and ${HAS_STOPS}`,
  airport_pickup: "r.airport_id is not null and r.airport_direction = 'pickup' and (r.status in ('searching', 'accepted', 'arrived', 'in_progress') or r.created_at >= $2)",
  airport_drop: "r.airport_id is not null and r.airport_direction = 'drop' and (r.status in ('searching', 'accepted', 'arrived', 'in_progress') or r.created_at >= $2)",
  completed: "r.status = 'completed' and r.completed_at >= $2",
  cancelled: "r.status = 'cancelled' and r.cancelled_at >= $2",
  expired: "r.status = 'expired' and r.updated_at >= $2",
  all_live: "(r.status = 'searching' and r.expires_at > now()) or r.status in ('accepted', 'arrived', 'in_progress')",
} as Record<RideFilter, string>)[f];

// ---------------------------------------------------------------------------------------------------------------------
// Delay rules for "investigate delays". Plain thresholds on recorded timestamps, nothing predicted.
// ---------------------------------------------------------------------------------------------------------------------
export type DelayKind = "waiting_for_driver" | "slow_pickup" | "overlong_trip" | "driver_location_stale";
export type DelaySettings = { unassigned_after_seconds: number; slow_pickup_minutes: number; stale_minutes: number };

export function detectDelay(r: { status: string; created_at: unknown; accepted_at: unknown; started_at: unknown; duration_minutes: unknown; driver_location_at: unknown; expires_at?: unknown }, now: number, s: DelaySettings): { kind: DelayKind; minutes: number }[] {
  const out: { kind: DelayKind; minutes: number }[] = [];
  const t = (v: unknown) => (v ? new Date(v as string).getTime() : NaN);
  const mins = (from: number) => Math.round((now - from) / 60000);
  if (r.status === "searching" && Number.isFinite(t(r.created_at)) && (!r.expires_at || t(r.expires_at) > now) && now - t(r.created_at) >= s.unassigned_after_seconds * 1000)
    out.push({ kind: "waiting_for_driver", minutes: mins(t(r.created_at)) });
  if (r.status === "accepted" && Number.isFinite(t(r.accepted_at)) && now - t(r.accepted_at) >= s.slow_pickup_minutes * 60000)
    out.push({ kind: "slow_pickup", minutes: mins(t(r.accepted_at)) });
  if (r.status === "in_progress" && Number.isFinite(t(r.started_at))) {
    const quoted = Number(r.duration_minutes) || 0;
    const limit = Math.max(quoted * 1.5, quoted + 10);
    if (mins(t(r.started_at)) > limit) out.push({ kind: "overlong_trip", minutes: mins(t(r.started_at)) });
  }
  if (["accepted", "arrived", "in_progress"].includes(r.status) && locationFreshness(r.driver_location_at, now, s.stale_minutes).state !== "fresh" && locationFreshness(r.driver_location_at, now, s.stale_minutes).state !== "delayed")
    out.push({ kind: "driver_location_stale", minutes: Number.isFinite(t(r.driver_location_at)) ? mins(t(r.driver_location_at)) : -1 });
  return out;
}

export async function delaySettings(db: Client): Promise<DelaySettings> {
  return {
    unassigned_after_seconds: await getSetting(db, "ops_unassigned_after_seconds", 60),
    slow_pickup_minutes: await getSetting(db, "ops_slow_pickup_minutes", 15),
    stale_minutes: await getSetting(db, "driver_location_stale_minutes", 10),
  };
}

// ---------------------------------------------------------------------------------------------------------------------
// Payment status as the platform can actually know it. Cash handover is not recorded by DROP, and it says so.
// ---------------------------------------------------------------------------------------------------------------------
export function paymentView(r: { status: string; payment_method: string; paid_with: string | null }, link: { status: string; gateway: string | null } | null) {
  const done = r.status === "completed";
  if (r.status === "cancelled" || r.status === "expired") return { method: r.payment_method, status: "not_charged", label: "Not charged", note: "The ride did not complete." };
  if (done && r.paid_with === "wallet") return { method: r.payment_method, status: "paid_wallet", label: "Paid from wallet", note: null };
  if (done && r.paid_with === "card") return { method: r.payment_method, status: "paid_card", label: "Paid by card", note: null };
  if (done && r.paid_with === "cash") return { method: r.payment_method, status: "cash_with_driver", label: r.payment_method === "wallet" ? "Cash (wallet could not cover it)" : "Cash paid to driver", note: "DROP does not record the cash handover." };
  if (link?.status === "paid") return { method: r.payment_method, status: "paid_link", label: `Paid by payment link${link.gateway ? ` (${link.gateway})` : ""}`, note: null };
  if (link?.status === "pending") return { method: r.payment_method, status: "awaiting_payment", label: "Payment link sent, not paid yet", note: null };
  if (r.payment_method === "wallet") return { method: r.payment_method, status: "due_at_completion", label: "Wallet is charged when the trip completes", note: null };
  if (r.payment_method === "cash") return { method: r.payment_method, status: "due_cash", label: "Cash due at the end of the trip", note: null };
  return { method: r.payment_method, status: "unknown", label: "No payment recorded yet", note: "Card and virtual-account payments appear here once a payment link is paid." };
}

// ---------------------------------------------------------------------------------------------------------------------
// Status timeline: only moments the platform actually recorded, oldest first.
// ---------------------------------------------------------------------------------------------------------------------
export type TimelineItem = { at: string; kind: string; label: string; actor?: string | null };

const iso = (v: unknown) => (v ? new Date(v as string).toISOString() : null);

export function rideTimeline(r: Row, stops: Row[], extra: TimelineItem[] = []): TimelineItem[] {
  const items: TimelineItem[] = [];
  const add = (at: unknown, kind: string, label: string, actor?: string | null) => { const t = iso(at); if (t) items.push({ at: t, kind, label, actor: actor ?? null }); };
  add(r.created_at, "requested", r.booking_source === "admin" ? "Ride booked by DROP Support" : "Ride requested");
  add(r.accepted_at, "accepted", "Driver assigned");
  add(r.arrived_at, "arrived", "Driver arrived at pickup");
  add(r.started_at, "started", "Trip started");
  for (const s of stops) {
    add(s.arrived_at, "stop_arrived", `Arrived at stop ${s.sequence}`);
    add(s.completed_at, "stop_completed", `Finished stop ${s.sequence}`);
  }
  add(r.completed_at, "completed", "Trip completed");
  if (r.status === "cancelled") add(r.cancelled_at, "cancelled", `Cancelled by ${r.cancelled_by ?? "unknown"}${r.cancel_reason ? `: ${r.cancel_reason}` : ""}`);
  if (r.status === "expired") add(r.expires_at, "expired", "Request expired with no driver");
  return [...items, ...extra].sort((a, b) => a.at.localeCompare(b.at));
}
