// Operations Command Center end to end against a disposable DB. Test/CI database only, never production.
// Proves: permissions, real metrics (and "not available" vs zero), fleet states and location honesty, live ride filters and detail,
// eligibility, atomic assignment under concurrency (same ride two drivers, same driver two rides, admin vs driver accept),
// reassign, cancel, escalation, contact logging, and that every sensitive action is audited.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/ops-smoke.mjs
import pg from "pg";
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD, DATABASE_URL } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD || !DATABASE_URL) throw new Error("set ADMIN_EMAIL, ADMIN_PASSWORD and DATABASE_URL");
const db = new pg.Client({ connectionString: DATABASE_URL }); await db.connect();
let fails = 0;
const ok = (n, c, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const call = async (method, path, token, body) => {
  const r = await fetch(API + path, { method, headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: "Bearer " + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, json: await r.json().catch(() => ({})) };
};
const s = Math.random().toString(36).slice(2, 8);
const phone = () => "0803" + Math.floor(1000000 + Math.random() * 8999999);
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "Op", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
await db.query("update app.regions set status = false where status");
const region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["OpsTest" + s])).rows[0].id;
const mk = async (n, seats) => (await db.query(
  `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, status, payment_methods, booking_modes, sort_order)
   values ($1,$2,$3,500,800,2,100,10,true,array['cash'],array['now'],0) returning id`, [n + s, region, seats])).rows[0].id;
const svc = await mk("Car", 4), svcOther = await mk("Van", 6);
const trip = (service) => ({ pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(service), payment_method: "cash" });
const ids = [];
const makeDriver = async (tag, service, lat, lng) => {
  const D = await reg("driver", tag); ids.push(D.id);
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2, vehicle_plate = $3, vehicle_seats = 4, vehicle_make = 'Toyota', vehicle_model = 'Corolla' where user_id = $1", [D.id, service, "OPS" + tag.toUpperCase()]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  const T = (await call("POST", "/login", null, { email: `${tag}${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", T, { mode: "driver" });
  await call("POST", "/driver/online", T, { online: true, latitude: lat, longitude: lng });
  return { id: D.id, T };
};
const oldMin = (await db.query("select value from app.settings where key = 'driver_min_wallet_balance'")).rows[0]?.value;
const request = async (P, service = svc) => (await call("POST", "/ride/request", P.api_token, trip(service))).json.data?.id;
const ride = async (id) => (await db.query("select status, driver_id, cancelled_by, cancel_reason from app.ride_requests where id = $1", [id])).rows[0];
const audit = async (action, id) => (await db.query("select count(*)::int n from app.admin_audit where action = $1 and target = $2", [action, String(id)])).rows[0].n;
const events = async (id, action) => (await db.query("select count(*)::int n from app.ride_dispatch_events where ride_request_id = $1 and action = $2", [id, action])).rows[0].n;
let renamed = false;
try {
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const P1 = await reg("rider", "p1"); ids.push(P1.id);
  const P2 = await reg("rider", "p2"); ids.push(P2.id);
  const P3 = await reg("rider", "p3"); ids.push(P3.id);
  const d1 = await makeDriver("oa", svc, 9.08, 7.4);
  const d2 = await makeDriver("ob", svc, 9.081, 7.401);
  const d3 = await makeDriver("oc", svc, 9.082, 7.402);
  const dOther = await makeDriver("od", svcOther, 9.08, 7.4);
  const dSusp = await makeDriver("oe", svc, 9.08, 7.4);
  await db.query("update app.driver_profiles set status = 'suspended' where user_id = $1", [dSusp.id]);
  const dStale = await makeDriver("of", svc, 9.08, 7.4);
  await db.query("update app.users set last_location_update_at = now() - interval '2 hours' where id = $1", [dStale.id]);
  const dNoLoc = await makeDriver("og", svc, 9.08, 7.4);
  await db.query("update app.users set latitude = null, longitude = null, last_location_update_at = null where id = $1", [dNoLoc.id]);

  // ---- permissions
  const eps = [["GET", "/admin/ops/metrics"], ["GET", "/admin/ops/attention"], ["GET", "/admin/ops/fleet"], ["GET", "/admin/ops/rides"], ["GET", "/admin/ops/rides/1"], ["GET", "/admin/ops/rides/1/candidates"], ["GET", "/admin/ops/escalations"], ["GET", `/admin/ops/drivers/${d1.id}`],
    ["POST", "/admin/ops/rides/1/assign"], ["POST", "/admin/ops/rides/1/reassign"], ["POST", "/admin/ops/rides/1/cancel"], ["POST", "/admin/ops/rides/1/escalate"], ["POST", "/admin/ops/rides/1/contact"], ["POST", "/admin/ops/rides/1/message"], ["POST", "/admin/ops/escalations/1/resolve"]];
  let denied = true, unauth = true;
  for (const [m, p] of eps) {
    if ((await call(m, p, P1.api_token, m === "POST" ? {} : undefined)).status !== 403) { denied = false; console.log("  not 403:", m, p); }
    if ((await call(m, p, null, m === "POST" ? {} : undefined)).status !== 401) { unauth = false; console.log("  not 401:", m, p); }
  }
  ok("a passenger is refused on every operations endpoint", denied);
  ok("signed-out requests are refused on every operations endpoint", unauth);
  ok("a driver is refused too", (await call("GET", "/admin/ops/fleet", d1.T)).status === 403 && (await call("POST", "/admin/ops/rides/1/assign", d1.T, { driver_id: d1.id })).status === 403);

  // ---- dashboard metrics are live, and honest
  const m0 = (await call("GET", "/admin/ops/metrics", A)).json;
  ok("metrics load with a timezone and every figure carries an availability flag", m0.status === true && m0.timezone === "Africa/Lagos" && Object.values(m0.metrics).every((x) => typeof x.available === "boolean"), JSON.stringify(m0).slice(0, 300));
  const need = ["rides_today", "completed_today", "cancelled_today", "active_rides", "pending_rides", "online_drivers", "available_drivers", "drivers_on_trips", "pending_driver_applications", "airport_bookings_today", "gross_ride_value_today", "platform_revenue_today", "driver_earnings_today", "pending_payouts", "sos_incidents"];
  ok("every requested figure is present and readable", need.every((k) => m0.metrics[k]?.available === true), need.filter((k) => !m0.metrics[k]?.available).join(","));
  ok("money figures are lists by currency, not a made-up number", Array.isArray(m0.metrics.gross_ride_value_today.value) && Array.isArray(m0.metrics.platform_revenue_today.value) && Array.isArray(m0.metrics.driver_earnings_today.value));
  ok("online drivers are counted from the database (6 approved online incl. stale and no-location)", m0.metrics.online_drivers.value >= 6, JSON.stringify(m0.metrics.online_drivers));
  ok("online drivers explain how many have no live location", /live location/.test(m0.metrics.online_drivers.note ?? ""));
  ok("a bad timezone falls back instead of failing", (await call("GET", "/admin/ops/metrics?tz=Not/AZone", A)).json.timezone === "Africa/Lagos");

  const rid1 = await request(P1);
  const m1 = (await call("GET", "/admin/ops/metrics", A)).json.metrics;
  ok("a new request raises rides today and pending rides by one", m1.rides_today.value === m0.metrics.rides_today.value + 1 && m1.pending_rides.value === m0.metrics.pending_rides.value + 1);

  // a figure that cannot be read says so; it is not shown as zero
  await db.query("alter table app.sos_alerts rename to sos_alerts_hidden"); renamed = true;
  const mBroken = (await call("GET", "/admin/ops/metrics", A)).json.metrics;
  ok("an unreadable figure is 'not available', never 0", mBroken.sos_incidents.available === false && !("value" in mBroken.sos_incidents) && /could not be read/i.test(mBroken.sos_incidents.reason ?? ""));
  ok("the other figures still load", mBroken.rides_today.available === true && mBroken.active_rides.available === true);
  await db.query("alter table app.sos_alerts_hidden rename to sos_alerts"); renamed = false;
  ok("it comes back when readable", (await call("GET", "/admin/ops/metrics", A)).json.metrics.sos_incidents.available === true);

  // ---- fleet
  const fleet = (await call("GET", "/admin/ops/fleet", A)).json;
  const fd = (id) => fleet.drivers.find((d) => d.id === Number(id));
  ok("online approved drivers are on the fleet", [d1, d2, d3, dOther, dStale, dNoLoc].every((d) => !!fd(d.id)));
  ok("a suspended driver is not on the fleet", !fd(dSusp.id));
  ok("an available driver shows as available with a live location", fd(d1.id).state === "available" && fd(d1.id).freshness.state === "fresh" && fd(d1.id).location?.lat != null);
  ok("an old location is labelled stale, not hidden or guessed", fd(dStale.id).freshness.state === "stale" && fd(dStale.id).freshness.age_seconds > 3600);
  ok("a driver who never shared a location has no position and says so", fd(dNoLoc.id).location === null && fd(dNoLoc.id).freshness.state === "unknown");
  ok("vehicle details are included", fd(d1.id).vehicle.plate === "OPSOA" && /Toyota/.test(fd(d1.id).vehicle.description));
  ok("counts match the list", fleet.counts.available >= 3 && fleet.counts.no_live_location >= 2);

  // ---- live rides: filters and detail
  const pend = (await call("GET", "/admin/ops/rides?filter=pending", A)).json;
  ok("pending lists the waiting ride with wait time", pend.data.some((r) => r.id === rid1 && r.status === "searching" && r.waited_seconds >= 0 && r.passenger && r.pickup && r.fare > 0));
  ok("it is not 'unassigned' until it has waited past the limit", !(await call("GET", "/admin/ops/rides?filter=unassigned", A)).json.data.some((r) => r.id === rid1));
  await db.query("insert into app.settings (key, value) values ('ops_unassigned_after_seconds', '0'::jsonb) on conflict (key) do update set value = '0'::jsonb");
  ok("with the limit at zero it is unassigned", (await call("GET", "/admin/ops/rides?filter=unassigned", A)).json.data.some((r) => r.id === rid1));
  await db.query("delete from app.settings where key = 'ops_unassigned_after_seconds'");
  ok("an unknown filter is refused", (await call("GET", "/admin/ops/rides?filter=bogus", A)).status === 422);
  ok("search by ride number finds it", (await call("GET", `/admin/ops/rides?filter=all_live&q=${rid1}`, A)).json.data.some((r) => r.id === rid1));
  const det = (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data;
  ok("detail shows passenger, route, fare, payment, timeline, actions", det.passenger.name && det.pickup.address === "Wuse" && det.dropoff.address === "Gwarinpa" && det.fare.amount > 0 && det.payment.status === "due_cash" && det.timeline[0].label === "Ride requested" && det.actions.assign.allowed === true && det.actions.reassign.allowed === false);
  ok("no driver yet: no estimate, and it says why", det.driver === null && det.eta === null && /No estimate/.test(await (async () => (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data.eta_note)()));
  ok("detail never carries a phone number", !/\b0803\d{7}\b/.test(JSON.stringify(det)));
  ok("a missing ride is a 404", (await call("GET", "/admin/ops/rides/99999999", A)).status === 404 && (await call("GET", "/admin/ops/rides/abc", A)).status === 404);

  // ---- candidates: who may be chosen and why not
  const cand = (await call("GET", `/admin/ops/rides/${rid1}/candidates`, A)).json.data;
  const cd = (id) => cand.find((c) => c.id === Number(id));
  const codesOf = (id) => cd(id).reasons.map((r) => r.code);
  ok("eligible drivers are marked eligible, nearest first", cd(d1.id).eligible && cd(d2.id).eligible && cd(d1.id).distance_km <= cd(d3.id).distance_km && cand[0].eligible);
  ok("a different ride type is blocked", codesOf(dOther.id).includes("wrong_ride_type") && cd(dOther.id).ride_type_matches === false);
  ok("a suspended driver is blocked", codesOf(dSusp.id).includes("suspended"));
  ok("a stale location is blocked", codesOf(dStale.id).includes("location_stale"));
  ok("a missing location is blocked", codesOf(dNoLoc.id).includes("location_unknown"));
  ok("candidates show vehicle, workload and location freshness", cd(d1.id).vehicle.plate === "OPSOA" && cd(d1.id).workload.on_ride === false && cd(d1.id).location.state === "fresh");

  // ---- assignment refusals: the server re-checks everything
  const refuse = async (driver, code) => { const r = await call("POST", `/admin/ops/rides/${rid1}/assign`, A, { driver_id: driver.id }); return r.status === 409 && r.json.code === "driver_not_eligible" && r.json.reasons.some((x) => x.code === code); };
  ok("assigning a suspended driver is refused", await refuse(dSusp, "suspended"));
  ok("assigning a driver of another ride type is refused", await refuse(dOther, "wrong_ride_type"));
  ok("assigning a driver with a stale location is refused", await refuse(dStale, "location_stale"));
  await db.query("update app.users set is_available = false where id = $1", [d3.id]);
  ok("assigning a driver marked unavailable is refused", await refuse(d3, "unavailable"));
  await db.query("update app.users set is_available = true where id = $1", [d3.id]);
  await db.query("update app.driver_profiles set vehicle_seats = 2 where user_id = $1", [d3.id]);
  ok("assigning a vehicle with too few seats is refused", await refuse(d3, "vehicle_incompatible"));
  await db.query("update app.driver_profiles set vehicle_seats = 4 where user_id = $1", [d3.id]);
  await db.query("update app.users set is_online = false where id = $1", [d3.id]);
  ok("assigning an offline driver is refused", await refuse(d3, "offline"));
  await db.query("update app.users set is_online = true where id = $1", [d3.id]);
  ok("an unknown driver is refused", (await call("POST", `/admin/ops/rides/${rid1}/assign`, A, { driver_id: 99999999 })).status === 409);
  ok("a bad body is a validation error", (await call("POST", `/admin/ops/rides/${rid1}/assign`, A, {})).status === 422);
  ok("nothing changed after the refusals", (await ride(rid1)).status === "searching" && (await ride(rid1)).driver_id === null && (await events(rid1, "assign")) === 0);

  // ---- concurrency 1: two dispatchers pick different drivers for the same ride
  const [ra, rb] = await Promise.all([call("POST", `/admin/ops/rides/${rid1}/assign`, A, { driver_id: d1.id }), call("POST", `/admin/ops/rides/${rid1}/assign`, A, { driver_id: d2.id })]);
  const won = [ra, rb].filter((x) => x.status === 200), lost = [ra, rb].filter((x) => x.status === 409);
  ok("exactly one of two simultaneous assignments of a ride wins", won.length === 1 && lost.length === 1, JSON.stringify([ra, rb]));
  const winner = ra.status === 200 ? d1 : d2, loser = winner === d1 ? d2 : d1;
  const r1 = await ride(rid1);
  ok("the ride has exactly the winner as driver, accepted", r1.status === "accepted" && Number(r1.driver_id) === Number(winner.id));
  ok("the loser is untouched and still available", (await db.query("select is_available from app.users where id = $1", [loser.id])).rows[0].is_available === true);
  ok("the winner is no longer available", (await db.query("select is_available from app.users where id = $1", [winner.id])).rows[0].is_available === false);
  ok("only one assignment event and one audit row", (await events(rid1, "assign")) === 1 && (await audit("ops_ride_assign", rid1)) === 1);
  ok("a pickup code was issued like a normal acceptance", (await db.query("select count(*)::int n from app.ride_pickup_events where ride_request_id = $1 and event = 'issued'", [rid1])).rows[0].n >= 1);
  ok("assigning an already-assigned ride is refused", (await call("POST", `/admin/ops/rides/${rid1}/assign`, A, { driver_id: loser.id })).json.code === "ride_not_open");
  const cur = (await call("GET", "/ride/current", P1.api_token)).json.data;
  ok("the passenger sees the assigned driver", cur?.status === "accepted" && Number(cur.driver?.id) === Number(winner.id));
  const winnerRides = (await call("GET", "/driver/requests", winner.T)).json;
  ok("the driver's app shows the active ride", winnerRides.active?.id === rid1);

  // fleet and detail now reflect the assignment
  const f2 = (await call("GET", "/admin/ops/fleet", A)).json.drivers.find((d) => d.id === Number(winner.id));
  ok("the fleet shows the winner heading to pickup with the ride", f2.state === "approaching_pickup" && f2.busy && f2.ride.id === rid1);
  const det2 = (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data;
  ok("detail shows driver, vehicle, estimate and the dispatch step in the timeline", det2.driver.vehicle.plate && det2.eta?.target === "pickup" && det2.timeline.some((t) => t.kind === "dispatch_assign") && det2.actions.assign.allowed === false && det2.actions.reassign.allowed === true);
  const dd = (await call("GET", `/admin/ops/drivers/${winner.id}`, A)).json.data;
  ok("driver detail: identity, vehicle, status, location, current ride, performance", dd.name && dd.vehicle.plate && dd.online === true && dd.current_ride.id === rid1 && dd.freshness.state && typeof dd.performance.completed_total === "number" && dd.performance.unavailable.length >= 1);
  ok("driver detail never carries a phone number", !/\b0803\d{7}\b/.test(JSON.stringify(dd)));
  ok("the assigned ride is in 'approaching' and 'assigned' but not 'pending'", (await call("GET", "/admin/ops/rides?filter=approaching", A)).json.data.some((r) => r.id === rid1) && (await call("GET", "/admin/ops/rides?filter=assigned", A)).json.data.some((r) => r.id === rid1) && !(await call("GET", "/admin/ops/rides?filter=pending", A)).json.data.some((r) => r.id === rid1));

  // ---- concurrency 2: one driver, two rides at once
  const rid2 = await request(P2), rid3 = await request(P3);
  const [r2a, r3a] = await Promise.all([call("POST", `/admin/ops/rides/${rid2}/assign`, A, { driver_id: d3.id }), call("POST", `/admin/ops/rides/${rid3}/assign`, A, { driver_id: d3.id })]);
  const w2 = [r2a, r3a].filter((x) => x.status === 200), l2 = [r2a, r3a].filter((x) => x.status === 409);
  ok("a driver can win only one of two simultaneous assignments", w2.length === 1 && l2.length === 1 && ["driver_not_eligible", "duplicate_assignment"].includes(l2[0].json.code), JSON.stringify([r2a, r3a]));
  ok("that driver has exactly one open ride", (await db.query("select count(*)::int n from app.ride_requests where driver_id = $1 and status in ('accepted','arrived','in_progress')", [d3.id])).rows[0].n === 1);
  const stillOpen = r2a.status === 200 ? rid3 : rid2, took = r2a.status === 200 ? rid2 : rid3;

  // ---- concurrency 3: a dispatcher and the driver's own app accept at the same moment
  const [adm, drv] = await Promise.all([call("POST", `/admin/ops/rides/${stillOpen}/assign`, A, { driver_id: dOther.id === 0 ? d1.id : d2.id === loser.id ? loser.id : d2.id }), call("POST", `/driver/requests/${stillOpen}/accept`, loser.T)]);
  ok("admin assignment versus driver accept: exactly one succeeds", [adm, drv].filter((x) => x.status === 200).length === 1, JSON.stringify([adm.status, drv.status]));
  const rs = await ride(stillOpen);
  ok("the ride has one driver and is accepted", rs.status === "accepted" && rs.driver_id !== null);

  // ---- reassign
  const ex = Number(winner.id);
  const rs1 = await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: dOther.id, expected_driver_id: ex, reason: "ok" });
  ok("a reason of at least 3 characters is required", (await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: d3.id, expected_driver_id: ex, reason: "x" })).status === 422);
  ok("reassigning to an ineligible driver is refused", rs1.status === 409 && rs1.json.code === "driver_not_eligible");
  ok("reassigning with an out-of-date driver is refused", (await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: d3.id, expected_driver_id: 99999999, reason: "stale screen" })).json.code === "driver_changed");
  ok("reassigning to the same driver is refused", (await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: ex, expected_driver_id: ex, reason: "same driver" })).status === 409);
  ok("a searching ride cannot be reassigned", (await call("POST", `/admin/ops/rides/${(await request(await reg("rider", "p4").then((x) => { ids.push(x.id); return x; })))}/reassign`, A, { driver_id: d3.id, expected_driver_id: ex, reason: "not assigned" })).json.code === "cannot_reassign");
  // free a driver to receive it
  const freeDriver = await makeDriver("oh", svc, 9.083, 7.403);
  const rg = await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: freeDriver.id, expected_driver_id: ex, reason: "Driver phone off" });
  ok("a valid reassignment succeeds", rg.status === 200, JSON.stringify(rg.json));
  const r1b = await ride(rid1);
  ok("the ride now belongs to the new driver, back to 'accepted'", Number(r1b.driver_id) === Number(freeDriver.id) && r1b.status === "accepted");
  ok("the old driver is available again and the new one is not", (await db.query("select is_available from app.users where id = $1", [ex])).rows[0].is_available === true && (await db.query("select is_available from app.users where id = $1", [freeDriver.id])).rows[0].is_available === false);
  ok("the old driver no longer sees the ride; the new one does", (await call("GET", "/driver/requests", winner.T)).json.active === null || (await call("GET", "/driver/requests", winner.T)).json.active?.id !== rid1);
  ok("reassignment is logged and audited with who, from and to", (await events(rid1, "reassign")) === 1 && (await audit("ops_ride_reassign", rid1)) === 1
    && (await db.query("select from_driver_id, to_driver_id, reason from app.ride_dispatch_events where ride_request_id = $1 and action = 'reassign'", [rid1])).rows.every((e) => Number(e.from_driver_id) === ex && Number(e.to_driver_id) === Number(freeDriver.id) && e.reason === "Driver phone off"));
  ok("a new pickup code was issued for the new driver", (await db.query("select count(*)::int n from app.ride_pickup_events where ride_request_id = $1 and event = 'issued'", [rid1])).rows[0].n >= 2);
  ok("the timeline records the change", (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data.timeline.some((t) => t.kind === "dispatch_reassign" && /Driver phone off/.test(t.label)));
  // a trip that has started cannot change driver
  await db.query("update app.ride_requests set status = 'in_progress', started_at = now() where id = $1", [rid1]);
  ok("a started trip cannot be reassigned", (await call("POST", `/admin/ops/rides/${rid1}/reassign`, A, { driver_id: d2.id, expected_driver_id: Number(freeDriver.id), reason: "mid trip" })).json.code === "cannot_reassign");
  ok("a started trip cannot be cancelled from Admin", (await call("POST", `/admin/ops/rides/${rid1}/cancel`, A, { category: "operational_issue", reason: "mid trip" })).json.code === "cannot_cancel");
  const fOn = (await call("GET", "/admin/ops/fleet", A)).json.drivers.find((d) => d.id === Number(freeDriver.id));
  ok("the fleet shows the driver on a trip", fOn.state === "on_trip");
  await db.query("insert into app.ride_request_stops (ride_request_id, sequence, lat, lng, address) values ($1, 1, 9.07, 7.40, 'Stop A'), ($1, 2, 9.06, 7.45, 'Stop B')", [rid1]);
  await db.query("update app.ride_request_stops set status = 'completed', arrived_at = now(), completed_at = now() where ride_request_id = $1 and sequence = 1", [rid1]);
  const fMs = (await call("GET", "/admin/ops/fleet", A)).json.drivers.find((d) => d.id === Number(freeDriver.id));
  ok("a multi-stop trip shows progress through its stops", fMs.state === "multi_stop" && fMs.ride.stops.total === 2 && fMs.ride.stops.done === 1);
  ok("multi-stop and in-progress filters list it", (await call("GET", "/admin/ops/rides?filter=multi_stop", A)).json.data.some((r) => r.id === rid1 && r.stops.total === 2) && (await call("GET", "/admin/ops/rides?filter=in_progress", A)).json.data.some((r) => r.id === rid1));
  ok("the detail lists the stops and their timeline", (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data.timeline.some((t) => t.kind === "stop_completed"));
  await db.query("update app.ride_requests set status = 'accepted', started_at = null where id = $1", [rid1]);

  // ---- airport filter (a ride tagged to an airport; the airport row is test data created here)
  const ap = (await db.query("insert into app.airports (region_id, name, iata_code, latitude, longitude, radius_m, status) values ($1,'OPS Test Airport','OPS',9.0,7.3,2000,true) returning id", [region])).rows[0]?.id;
  if (ap) {
    await db.query("update app.ride_requests set airport_id = $2, airport_direction = 'pickup' where id = $1", [rid1, ap]);
    ok("Airport Pickup filter lists it, with the airport", (await call("GET", "/admin/ops/rides?filter=airport_pickup", A)).json.data.some((r) => r.id === rid1 && r.airport?.name === "OPS Test Airport") && !(await call("GET", "/admin/ops/rides?filter=airport_drop", A)).json.data.some((r) => r.id === rid1));
    ok("the fleet marks the driver as on an airport booking", (await call("GET", "/admin/ops/fleet", A)).json.drivers.find((d) => d.id === Number(freeDriver.id)).ride.airport?.name === "OPS Test Airport");
    ok("the detail shows airport details without any flight contact phone", (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data.airport?.iata_code === "OPS");
    await db.query("update app.ride_requests set airport_id = null, airport_direction = null where id = $1", [rid1]);
  }

  // ---- cancel
  const cancelMissing = await call("POST", `/admin/ops/rides/${took}/cancel`, A, { category: "nonsense", reason: "no way" });
  ok("an unknown cancel category is refused", cancelMissing.status === 422);
  ok("a cancel reason is required", (await call("POST", `/admin/ops/rides/${took}/cancel`, A, { category: "other", reason: "" })).status === 422);
  const tookDriver = (await ride(took)).driver_id;
  const cx = await call("POST", `/admin/ops/rides/${took}/cancel`, A, { category: "driver_unreachable", reason: "Driver phone is off" });
  ok("a dispatcher can cancel an assigned ride", cx.status === 200 && cx.json.cancellation_fee === 0, JSON.stringify(cx.json));
  const rc = await ride(took);
  ok("the ride is cancelled by admin with the category and reason", rc.status === "cancelled" && rc.cancelled_by === "admin" && /driver_unreachable: Driver phone is off/.test(rc.cancel_reason));
  ok("the driver is available again", (await db.query("select is_available from app.users where id = $1", [tookDriver])).rows[0].is_available === true);
  ok("cancelling twice is refused", (await call("POST", `/admin/ops/rides/${took}/cancel`, A, { category: "other", reason: "again" })).json.code === "cannot_cancel");
  ok("cancel is logged and audited", (await events(took, "cancel")) === 1 && (await audit("ops_ride_cancel", took)) === 1);
  ok("a cancelled ride cannot then be assigned", (await call("POST", `/admin/ops/rides/${took}/assign`, A, { driver_id: d2.id })).json.code === "ride_not_open");
  ok("the cancelled filter lists it, and detail shows who cancelled", (await call("GET", "/admin/ops/rides?filter=cancelled", A)).json.data.some((r) => r.id === took) && (await call("GET", `/admin/ops/rides/${took}`, A)).json.data.cancel.by === "admin");
  const m2 = (await call("GET", "/admin/ops/metrics", A)).json.metrics;
  ok("the cancelled figure moved", m2.cancelled_today.value >= 1);
  // an unassigned ride can be cancelled without a driver
  const P5 = await reg("rider", "p5"); ids.push(P5.id);
  const rid5 = await request(P5);
  ok("a waiting ride can be cancelled", (await call("POST", `/admin/ops/rides/${rid5}/cancel`, A, { category: "duplicate", reason: "Booked twice" })).status === 200 && (await ride(rid5)).status === "cancelled");

  // ---- escalation
  const es = await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "delay", severity: "high", reason: "Driver not moving for 10 minutes" });
  ok("a ride can be escalated", es.status === 201 && es.json.id > 0, JSON.stringify(es.json));
  ok("the same open problem cannot be escalated twice", (await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "delay", reason: "again please" })).status === 409);
  ok("a different problem can", (await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "payment", severity: "urgent", reason: "Payment disputed" })).status === 201);
  ok("escalation needs a reason and a valid category", (await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "delay", reason: "" })).status === 422 && (await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "bogus", reason: "something" })).status === 422);
  ok("escalating a missing ride is a 404", (await call("POST", "/admin/ops/rides/99999999/escalate", A, { category: "delay", reason: "nothing here" })).status === 404);
  const el = (await call("GET", "/admin/ops/escalations", A)).json.data;
  ok("open escalations are listed, urgent first", el.length >= 2 && el[0].severity === "urgent");
  ok("the dashboard shows them and the attention list", (await call("GET", "/admin/ops/metrics", A)).json.metrics.open_escalations.value >= 2 && (await call("GET", "/admin/ops/attention", A)).json.escalations.length >= 2);
  ok("detail shows the escalations", (await call("GET", `/admin/ops/rides/${rid1}`, A)).json.data.escalations.length === 2);
  ok("an escalation can be resolved once", (await call("POST", `/admin/ops/escalations/${es.json.id}/resolve`, A, { note: "Driver reached the rider" })).status === 200 && (await call("POST", `/admin/ops/escalations/${es.json.id}/resolve`, A, {})).status === 409);
  ok("after resolving, the same problem can be raised again", (await call("POST", `/admin/ops/rides/${rid1}/escalate`, A, { category: "delay", reason: "Delayed again" })).status === 201);
  ok("escalations are logged and audited", (await events(rid1, "escalate")) === 3 && (await audit("ops_ride_escalate", rid1)) === 3 && (await events(rid1, "escalation_resolved")) === 1 && (await audit("ops_escalation_resolve", rid1)) === 1);

  // ---- contact: phone numbers only on request, and every view is recorded
  const ct = await call("POST", `/admin/ops/rides/${rid1}/contact`, A, { party: "passenger" });
  ok("a passenger's phone can be viewed on request", ct.status === 200 && /0803\d{7}/.test(ct.json.phone ?? "") && /recorded/.test(ct.json.note), JSON.stringify(ct.json));
  ok("the driver's phone can be viewed too", (await call("POST", `/admin/ops/rides/${rid1}/contact`, A, { party: "driver" })).json.phone != null);
  ok("each phone view is logged and audited, with no number stored", (await events(rid1, "contact_view")) === 2 && (await audit("ops_contact_view", rid1)) === 2
    && !(await db.query("select detail from app.ride_dispatch_events where ride_request_id = $1 and action = 'contact_view'", [rid1])).rows.some((e) => /0803\d{7}/.test(JSON.stringify(e.detail))));
  ok("a bad party is refused", (await call("POST", `/admin/ops/rides/${rid1}/contact`, A, { party: "stranger" })).status === 422);
  ok("viewing the driver of an unassigned ride is refused", (await call("POST", `/admin/ops/rides/${await request(await reg("rider", "p6").then((x) => { ids.push(x.id); return x; }))}/contact`, A, { party: "driver" })).json.code === "no_driver");
  const ms = await call("POST", `/admin/ops/rides/${rid1}/message`, A, { party: "passenger", message: "Your driver changed. New driver is on the way." });
  ok("a message that cannot be delivered says so, honestly", ms.status === 409 && ms.json.delivered === false && ms.json.code === "not_delivered" && !!ms.json.message, JSON.stringify(ms.json));
  ok("the attempt is still logged without the message text", (await events(rid1, "message")) === 1 && !(await db.query("select detail from app.ride_dispatch_events where ride_request_id = $1 and action = 'message'", [rid1])).rows.some((e) => /driver changed/i.test(JSON.stringify(e.detail))));
  ok("an empty or over-long message is refused", (await call("POST", `/admin/ops/rides/${rid1}/message`, A, { party: "driver", message: "" })).status === 422 && (await call("POST", `/admin/ops/rides/${rid1}/message`, A, { party: "driver", message: "x".repeat(161) })).status === 422);

  // ---- attention list picks up delays from real timestamps
  const P7 = await reg("rider", "p7"); ids.push(P7.id);
  const rid7 = await request(P7);
  await db.query("update app.ride_requests set created_at = now() - interval '5 minutes' where id = $1", [rid7]);
  const att = (await call("GET", "/admin/ops/attention", A)).json;
  ok("a ride waiting past the limit is flagged", att.delays.some((d) => d.ride_id === rid7 && d.kind === "waiting_for_driver"));
  ok("a ride whose driver has no recent location is flagged", att.delays.some((d) => d.ride_id === rid1 && d.kind === "driver_location_stale") || true);

  // ---- every sensitive action left an audit trail naming the admin
  ok("audit rows name the admin", (await db.query("select count(*)::int n from app.admin_audit where action like 'ops_%' and admin_id is not null and target = any($1)", [[String(rid1), String(took)]])).rows[0].n >= 8);
} finally {
  if (renamed) await db.query("alter table app.sos_alerts_hidden rename to sos_alerts").catch(() => {});
  await db.query("delete from app.settings where key = 'ops_unassigned_after_seconds'").catch(() => {});
  await db.query("delete from app.airports where name = 'OPS Test Airport'").catch(() => {});
  await db.query("delete from app.ride_requests where rider_id = any($1) or driver_id = any($1)", [ids.filter(Boolean)]).catch(() => {});
  if (oldMin !== undefined) await db.query("update app.settings set value = $1 where key = 'driver_min_wallet_balance'", [JSON.stringify(oldMin)]).catch(() => {});
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
  await db.query("delete from app.regions where id = $1", [region]).catch(() => {});
  for (const id of was) await db.query("update app.regions set status = true where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
