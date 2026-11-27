import { strict as assert } from "node:assert";
import { RIDE_FILTERS, detectDelay, evaluateDriver, filterSql, fleetState, locationFreshness, paymentView, rideTimeline, type DriverFacts, type RideFacts } from "../src/lib/dispatch";

const NOW = Date.parse("2026-11-26T10:00:00Z");
const ago = (s: number) => new Date(NOW - s * 1000).toISOString();
const ride: RideFacts = { id: 1, rider_id: 10, service_id: 5, region_id: 2, capacity: 4 };
const good: DriverFacts = {
  id: 20, user_status: "active", has_role: true, active_mode: "driver", profile_status: "approved", is_online: true, is_available: true, open_ride_id: null,
  accepts_standard: true, service_id: 5, service_region_id: 2, vehicle_plate: "ABC123", vehicle_seats: 4, docs_expired: false, wallet_balance: 1000, wallet_minimum: 500,
  latitude: 9.07, longitude: 7.39, location_at: ago(20),
};
const o = { now: NOW, staleMinutes: 10 };
const codes = (d: Partial<DriverFacts>, extra: Partial<typeof o & { currentDriverId: number }> = {}) => evaluateDriver(ride, { ...good, ...d }, { ...o, ...extra }).reasons.map((r) => r.code);

// ---- an eligible driver
assert.deepEqual(evaluateDriver(ride, good, o), { eligible: true, reasons: [], warnings: [] });

// ---- every blocking rule, one at a time
assert.deepEqual(codes({ profile_status: "suspended" }), ["suspended"]);
assert.deepEqual(codes({ profile_status: "submitted" }), ["not_approved"]);
assert.deepEqual(codes({ profile_status: null }), ["not_driver"]);
assert.deepEqual(codes({ has_role: false }), ["not_driver"]);
assert.deepEqual(codes({ user_status: "suspended" }), ["account_inactive"]);
assert.deepEqual(codes({ id: 10 }), ["is_passenger"]);
assert.deepEqual(codes({ active_mode: "rider" }), ["not_in_driver_mode"]);
assert.deepEqual(codes({ is_online: false, is_available: false }), ["offline"]);
assert.deepEqual(codes({ open_ride_id: 99, is_available: false }), ["on_ride"]);
assert.deepEqual(codes({ is_available: false }), ["unavailable"]);
assert.deepEqual(codes({ accepts_standard: false }), ["standard_requests_off"]);
assert.deepEqual(codes({ service_id: 6 }), ["wrong_ride_type"]);
assert.deepEqual(codes({ service_id: null }), ["wrong_ride_type"]);
assert.deepEqual(codes({ service_region_id: 3 }), ["wrong_region"]);
assert.deepEqual(codes({ vehicle_seats: 2 }), ["vehicle_incompatible"]);
assert.deepEqual(codes({ docs_expired: true }), ["documents_expired"]);
assert.deepEqual(codes({ wallet_balance: 100 }), ["wallet_below_minimum"]);
assert.deepEqual(codes({ latitude: null, longitude: null, location_at: null }), ["location_unknown"]);
assert.deepEqual(codes({ location_at: ago(11 * 60) }), ["location_stale"]);
assert.deepEqual(codes({}, { currentDriverId: 20 }), ["already_assigned"]);
assert.equal(codes({ profile_status: "suspended", is_online: false, is_available: false, service_id: 9, docs_expired: true }).length, 4, "all problems are reported together");

// ---- unknown vehicle details warn but do not block; a slightly old location warns
const w = evaluateDriver(ride, { ...good, vehicle_seats: null, vehicle_plate: null, location_at: ago(300) }, o);
assert.ok(w.eligible);
assert.deepEqual(w.warnings.map((x) => x.code).sort(), ["location_delayed", "plate_missing", "seats_unknown"]);
// a ride whose region is unknown does not block on region
assert.ok(evaluateDriver({ ...ride, region_id: null }, { ...good, service_region_id: 9 }, o).eligible);

// ---- location freshness is honest about missing and old data
assert.deepEqual(locationFreshness(null, NOW, 10), { state: "unknown", age_seconds: null });
assert.deepEqual(locationFreshness("not a date", NOW, 10), { state: "unknown", age_seconds: null });
assert.equal(locationFreshness(ago(30), NOW, 10).state, "fresh");
assert.equal(locationFreshness(ago(90), NOW, 10).state, "fresh");
assert.equal(locationFreshness(ago(91), NOW, 10).state, "delayed");
assert.equal(locationFreshness(ago(600), NOW, 10).state, "delayed");
assert.equal(locationFreshness(ago(601), NOW, 10).state, "stale");
assert.equal(locationFreshness(new Date(NOW + 5000).toISOString(), NOW, 10).age_seconds, 0, "a clock a little ahead is not negative");

// ---- fleet state
assert.equal(fleetState({ is_available: true }), "available");
assert.equal(fleetState({ is_available: false }), "unavailable");
assert.equal(fleetState({ ride_status: "accepted", is_available: false }), "approaching_pickup");
assert.equal(fleetState({ ride_status: "arrived" }), "arrived");
assert.equal(fleetState({ ride_status: "in_progress", stops_total: 0 }), "on_trip");
assert.equal(fleetState({ ride_status: "in_progress", stops_total: 2 }), "multi_stop");

// ---- ride list filters: every name has SQL, and the SQL never concatenates user input
for (const f of RIDE_FILTERS) assert.ok(filterSql(f) && !/\$[3-9]/.test(filterSql(f)), f);
assert.match(filterSql("unassigned"), /make_interval\(secs => \$1::int\)/);
assert.match(filterSql("multi_stop"), /ride_request_stops/);
assert.match(filterSql("airport_pickup"), /airport_direction = 'pickup'/);
assert.match(filterSql("airport_drop"), /airport_direction = 'drop'/);

// ---- delays are plain thresholds on recorded times
const s = { unassigned_after_seconds: 60, slow_pickup_minutes: 15, stale_minutes: 10 };
const r0 = { status: "searching", created_at: ago(30), accepted_at: null, started_at: null, duration_minutes: 20, driver_location_at: null, expires_at: new Date(NOW + 60000).toISOString() };
assert.deepEqual(detectDelay(r0, NOW, s), []);
assert.deepEqual(detectDelay({ ...r0, created_at: ago(120) }, NOW, s).map((d) => d.kind), ["waiting_for_driver"]);
assert.deepEqual(detectDelay({ ...r0, created_at: ago(120), expires_at: ago(5) }, NOW, s), [], "an expired request is not 'waiting'");
assert.deepEqual(detectDelay({ ...r0, status: "accepted", accepted_at: ago(20 * 60), driver_location_at: ago(10) }, NOW, s).map((d) => d.kind), ["slow_pickup"]);
assert.deepEqual(detectDelay({ ...r0, status: "accepted", accepted_at: ago(60), driver_location_at: ago(10) }, NOW, s), []);
assert.deepEqual(detectDelay({ ...r0, status: "in_progress", started_at: ago(50 * 60), duration_minutes: 20, driver_location_at: ago(10) }, NOW, s).map((d) => d.kind), ["overlong_trip"]);
assert.deepEqual(detectDelay({ ...r0, status: "in_progress", started_at: ago(25 * 60), duration_minutes: 20, driver_location_at: ago(10) }, NOW, s), [], "within 1.5x the quote");
assert.deepEqual(detectDelay({ ...r0, status: "arrived", driver_location_at: ago(20 * 60) }, NOW, s).map((d) => d.kind), ["driver_location_stale"]);
assert.deepEqual(detectDelay({ ...r0, status: "arrived", driver_location_at: null }, NOW, s).map((d) => d.kind), ["driver_location_stale"]);
assert.deepEqual(detectDelay({ ...r0, status: "arrived", driver_location_at: ago(200) }, NOW, s), [], "a slightly old location is not yet a problem");

// ---- payment status only claims what the platform knows
const pay = (status: string, method: string, paid: string | null, link: { status: string; gateway: string | null } | null = null) => paymentView({ status, payment_method: method, paid_with: paid }, link);
assert.equal(pay("completed", "wallet", "wallet").status, "paid_wallet");
assert.equal(pay("completed", "wallet", "cash").status, "cash_with_driver");
assert.match(pay("completed", "cash", "cash").note ?? "", /does not record/);
assert.equal(pay("completed", "cash", "cash").status, "cash_with_driver");
assert.equal(pay("completed", "card", "card").status, "paid_card");
assert.equal(pay("in_progress", "cash", null).status, "due_cash");
assert.equal(pay("in_progress", "wallet", null).status, "due_at_completion");
assert.equal(pay("accepted", "card", null, { status: "pending", gateway: null }).status, "awaiting_payment");
assert.equal(pay("accepted", "card", null, { status: "paid", gateway: "korapay" }).status, "paid_link");
assert.equal(pay("accepted", "virtual_account", null).status, "unknown");
assert.equal(pay("cancelled", "wallet", null).status, "not_charged");
assert.equal(pay("expired", "cash", null).status, "not_charged");

// ---- timeline: only recorded moments, oldest first, extra items merged in order
const tl = rideTimeline(
  { status: "completed", created_at: ago(3000), accepted_at: ago(2900), arrived_at: ago(2500), started_at: ago(2400), completed_at: ago(600), booking_source: "passenger" },
  [{ sequence: 1, arrived_at: ago(1500), completed_at: ago(1400) }],
  [{ at: ago(2950), kind: "dispatch_assign", label: "Driver assigned by dispatch", actor: "Ada" }],
);
assert.deepEqual(tl.map((t) => t.kind), ["requested", "dispatch_assign", "accepted", "arrived", "started", "stop_arrived", "stop_completed", "completed"]);
assert.ok(tl.every((t, i) => i === 0 || tl[i - 1].at <= t.at));
const never = rideTimeline({ status: "searching", created_at: ago(10), booking_source: "admin" }, []);
assert.deepEqual(never.map((t) => t.label), ["Ride booked by DROP Support"], "no invented steps");
assert.match(rideTimeline({ status: "cancelled", created_at: ago(100), cancelled_at: ago(50), cancelled_by: "admin", cancel_reason: "duplicate: twice" }, []).at(-1)!.label, /Cancelled by admin: duplicate/);

console.log("dispatch.test: all assertions passed");
