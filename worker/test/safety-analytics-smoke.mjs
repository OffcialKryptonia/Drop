// Phase 7 end to end against a disposable DB: Safety Center, driver and passenger analytics, financial intelligence, audit log.
// Test/CI database only, never production.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/safety-analytics-smoke.mjs
import pg from "pg";
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD, DATABASE_URL } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD || !DATABASE_URL) throw new Error("set ADMIN_EMAIL, ADMIN_PASSWORD and DATABASE_URL");
const db = new pg.Client({ connectionString: DATABASE_URL }); await db.connect();
let fails = 0;
const ok = (n, c, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const call = async (method, path, token, body) => {
  const r = await fetch(API + path, { method, headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: "Bearer " + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  let json = {}; try { json = JSON.parse(text); } catch { /* csv */ }
  return { status: r.status, json, text, headers: r.headers };
};
const s = Math.random().toString(36).slice(2, 8);
const phone = () => "0803" + Math.floor(1000000 + Math.random() * 8999999);
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "Sf", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const today = new Date().toISOString().slice(0, 10);

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
const ids = [];
let region, svc, roleId, subId;
try {
  await db.query("update app.regions set status = false where status");
  region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["SafTest" + s])).rows[0].id;
  svc = (await db.query(
    `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, status, payment_methods, booking_modes, sort_order)
     values ($1,$2,4,500,800,2,100,10,true,array['cash'],array['now'],0) returning id`, ["Car" + s, region])).rows[0].id;
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const trip = { pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(svc), payment_method: "cash" };
  const P1 = await reg("rider", "p1"); ids.push(P1.id);
  const P2 = await reg("rider", "p2"); ids.push(P2.id);
  const D = await reg("driver", "d1"); ids.push(D.id);
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2, vehicle_plate = 'SAF1', vehicle_seats = 4, vehicle_make = 'Toyota', vehicle_model = 'Corolla' where user_id = $1", [D.id, svc]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  const DT = (await call("POST", "/login", null, { email: `d1${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", DT, { mode: "driver" });

  // ---- permissions: every new endpoint refuses a passenger, a driver and a signed-out caller
  const eps = [["GET", "/admin/safety/incidents"], ["GET", "/admin/safety/incidents/1"], ["GET", "/admin/safety/assignees"], ["POST", "/admin/safety/incidents/1/reveal"],
    ["PUT", "/admin/safety/incidents/1/status"], ["PUT", "/admin/safety/incidents/1/assign"], ["PUT", "/admin/safety/incidents/1/classify"], ["POST", "/admin/safety/incidents/1/notes"], ["POST", "/admin/safety/incidents"],
    ["GET", "/admin/analytics/drivers"], ["GET", "/admin/analytics/drivers/1"], ["GET", "/admin/analytics/passengers"],
    ["GET", "/admin/finance/summary"], ["GET", "/admin/finance/reconciliation"], ["GET", "/admin/finance/export?report=rides"],
    ["GET", "/admin/audit-logs"], ["GET", "/admin/audit-logs/filters"]];
  let denied = true, unauth = true;
  for (const [m, p] of eps) {
    const body = m === "GET" ? undefined : {};
    if ((await call(m, p, P1.api_token, body)).status !== 403) { denied = false; console.log("  not 403:", m, p); }
    if ((await call(m, p, DT, body)).status !== 403) { denied = false; console.log("  driver not 403:", m, p); }
    if ((await call(m, p, null, body)).status !== 401) { unauth = false; console.log("  not 401:", m, p); }
  }
  ok("a passenger and a driver are refused on every Phase 7 endpoint", denied);
  ok("signed-out requests are refused on every Phase 7 endpoint", unauth);

  // ---- a restricted administrator with only "sos list"
  const role = await call("POST", "/admin/roles", A, { name: "saf_" + s, label: "Safety viewer " + s, permissions: ["sos list"] });
  roleId = role.json.data?.id ?? role.json.id;
  ok("a limited role can be created", !!roleId, JSON.stringify(role.json).slice(0, 200));
  const subEmail = `sub${s}@x.com`;
  const sub = await call("POST", "/admin/sub-admins", A, { first_name: "Sub", last_name: "Viewer", email: subEmail, username: "sub" + s, contact_number: null, admin_role_id: roleId, status: "active", password: "secret12345" });
  subId = sub.json.data?.id ?? sub.json.id;
  const S = (await call("POST", "/login", null, { email: subEmail, password: "secret12345", user_type: "admin" })).json.data?.api_token;
  ok("the limited administrator can sign in", !!S, JSON.stringify(sub.json).slice(0, 200));

  // ---- raise an SOS from a rider with an active trip
  const ride = (await call("POST", "/ride/request", P1.api_token, trip)).json.data?.id;
  ok("a ride exists for the SOS", !!ride);
  const sosR = await call("POST", "/sos/alert", P1.api_token, { latitude: 9.0765123, longitude: 7.3986456, message: "Driver took a wrong turn" });
  ok("the SOS is accepted", sosR.status === 200 || sosR.status === 201, JSON.stringify(sosR.json).slice(0, 200));
  const inc = (await db.query("select id, status, category, severity, ride_request_id from app.sos_alerts where user_id = $1 order by id desc limit 1", [P1.id])).rows[0];
  ok("it becomes a New incident linked to the ride with high severity", inc && inc.status === "open" && Number(inc.ride_request_id) === Number(ride) && inc.severity === "high", JSON.stringify(inc));
  const iid = inc.id;
  const hist0 = (await db.query("select action from app.safety_incident_events where incident_id = $1", [iid])).rows.map((r) => r.action);
  ok("the history starts with a 'created' row", hist0.includes("created"), hist0.join(","));

  // ---- privacy
  const lst = (await call("GET", "/admin/safety/incidents", S)).json;
  const li = lst.data?.find((x) => Number(x.id) === Number(iid));
  ok("the limited administrator sees the incident", !!li, JSON.stringify(lst).slice(0, 300));
  ok("the list does not say they may see personal details", lst.can_see_personal_details === false);
  const blob = JSON.stringify(lst) + JSON.stringify((await call("GET", `/admin/safety/incidents/${iid}`, S)).json);
  ok("no phone number, full surname or exact coordinate is in the list or detail", !/803\d{7}/.test(blob) && !blob.includes(`p1${s}`) && !blob.includes("9.0765123") && !blob.includes("7.3986456"));
  ok("the location is approximate", li?.location?.approximate === true && li.location.lat === 9.08 && li.location.lng === 7.4, JSON.stringify(li?.location));
  ok("the name is masked", /^Sf [A-Z]\.$/.test(li?.person?.name ?? ""), li?.person?.name);
  ok("reveal is refused without 'sos pii'", (await call("POST", `/admin/safety/incidents/${iid}/reveal`, S)).status === 403);
  ok("status change is refused without 'sos edit'", (await call("PUT", `/admin/safety/incidents/${iid}/status`, S, { status: "acknowledged" })).status === 403);
  const rev = await call("POST", `/admin/safety/incidents/${iid}/reveal`, A);
  ok("a super administrator can reveal, and gets the phone and exact place", rev.status === 200 && /\+234803\d{7}/.test(rev.json.data?.person?.phone ?? "") && Math.abs(rev.json.data.location?.lat - 9.0765123) < 0.00001, JSON.stringify(rev.json).slice(0, 300));
  ok("the reveal is in the incident history and the audit log", (await db.query("select count(*)::int n from app.safety_incident_events where incident_id = $1 and action = 'reveal'", [iid])).rows[0].n === 1
    && (await db.query("select count(*)::int n from app.admin_audit where action = 'safety_pii_view' and target = $1", [String(iid)])).rows[0].n === 1);
  const revHist = JSON.stringify((await db.query("select detail from app.safety_incident_events where incident_id = $1 and action = 'reveal'", [iid])).rows);
  ok("the history row records the fields, not the values", !/803\d{7}/.test(revHist) && /names/.test(revHist));

  // ---- workflow
  const st = (to, note, tok = A, id = iid) => call("PUT", `/admin/safety/incidents/${id}/status`, tok, note === undefined ? { status: to } : { status: to, note });
  ok("an unknown status is refused", (await st("bogus")).status === 422);
  ok("same status is refused", (await st("open")).status === 409);
  ok("New to Acknowledged works", (await st("acknowledged")).status === 200);
  ok("resolving needs a note", (await st("resolved")).status === 422);
  ok("escalating needs a note", (await st("escalated")).status === 422);
  ok("Acknowledged cannot go back to New", (await st("open")).status === 409);
  ok("Acknowledged to Investigating works", (await st("investigating")).status === 200);
  ok("escalation with a note works", (await st("escalated", "Driver unreachable for 10 minutes")).status === 200);
  ok("Escalated cannot be Acknowledged", (await st("acknowledged")).status === 409);
  ok("Escalated back to Investigating works", (await st("investigating")).status === 200);

  // concurrency: two requests resolve at once, exactly one wins
  const [r1, r2] = await Promise.all([st("resolved", "Resolved by call one"), st("resolved", "Resolved by call two")]);
  ok("two simultaneous resolves: one succeeds, one is refused", [r1.status, r2.status].sort().join() === "200,409", `${r1.status},${r2.status}`);
  ok("Resolved cannot be assigned or reclassified", (await call("PUT", `/admin/safety/incidents/${iid}/assign`, A, { admin_id: null })).status === 409
    && (await call("PUT", `/admin/safety/incidents/${iid}/classify`, A, { severity: "low" })).status === 409);
  ok("Resolved to Closed works", (await st("closed")).status === 200);
  ok("Closed is final", (await st("investigating")).status === 409);
  ok("a closed incident takes no notes", (await call("POST", `/admin/safety/incidents/${iid}/notes`, A, { note: "late note" })).status === 409);
  const row = (await db.query("select status, closed_at, handled_by from app.sos_alerts where id = $1", [iid])).rows[0];
  ok("closed_at and handler are recorded", row.status === "closed" && row.closed_at && row.handled_by);

  // ---- admin-raised incident, assignment, classification, notes
  const ride2 = (await call("POST", "/ride/request", P2.api_token, trip)).json.data?.id;
  const created = await call("POST", "/admin/safety/incidents", A, { ride_request_id: Number(ride2), party: "rider", category: "harassment", severity: "medium", note: "Reported by phone" });
  ok("an admin can raise an incident from a trip", created.status === 201 && created.json.id, JSON.stringify(created.json));
  const id2 = created.json.id;
  ok("raising for a driver on a trip with no driver is refused", (await call("POST", "/admin/safety/incidents", A, { ride_request_id: Number(ride2), party: "driver", category: "other", severity: "low", note: "none yet" })).status === 422);
  ok("a missing trip is a 404", (await call("POST", "/admin/safety/incidents", A, { ride_request_id: 99999999, party: "rider", category: "other", severity: "low", note: "x yz" })).status === 404);
  const me = (await db.query("select id from app.users where email = $1", [ADMIN_EMAIL])).rows[0].id;
  ok("assigning to myself works", (await call("PUT", `/admin/safety/incidents/${id2}/assign`, A, { admin_id: Number(me) })).status === 200);
  ok("assigning the same person again is refused", (await call("PUT", `/admin/safety/incidents/${id2}/assign`, A, { admin_id: Number(me) })).status === 409);
  ok("assigning to a non-admin is refused", (await call("PUT", `/admin/safety/incidents/${id2}/assign`, A, { admin_id: Number(P1.id) })).status === 422);
  ok("classify changes category and severity with a history row each", (await call("PUT", `/admin/safety/incidents/${id2}/classify`, A, { category: "accident", severity: "critical" })).status === 200
    && (await db.query("select count(*)::int n from app.safety_incident_events where incident_id = $1 and action in ('category','severity')", [id2])).rows[0].n === 2);
  ok("classify with nothing to change is refused", (await call("PUT", `/admin/safety/incidents/${id2}/classify`, A, { severity: "critical" })).status === 409);
  ok("a note shorter than 3 characters is refused", (await call("POST", `/admin/safety/incidents/${id2}/notes`, A, { note: "x" })).status === 422);
  ok("a note is added", (await call("POST", `/admin/safety/incidents/${id2}/notes`, A, { note: "Called the passenger back" })).status === 200);
  const f1 = (await call("GET", "/admin/safety/incidents?severity=critical&category=accident&assigned=me", A)).json;
  ok("filters by severity, category and assignee work", f1.data?.length >= 1 && f1.data.every((x) => x.severity === "critical" && x.category === "accident"));
  ok("an unknown filter value is refused", (await call("GET", "/admin/safety/incidents?severity=nope", A)).status === 422 && (await call("GET", "/admin/safety/incidents?status=nope", A)).status === 422);
  ok("searching by ride number finds the incident", (await call("GET", `/admin/safety/incidents?q=${ride2}&status=all`, A)).json.data?.some((x) => Number(x.id) === Number(id2)));
  const d2 = (await call("GET", `/admin/safety/incidents/${id2}`, A)).json.data;
  ok("detail has a full ordered history and allowed actions", d2.history.map((h) => h.action)[0] === "created" && d2.history.length >= 5 && Array.isArray(d2.allowed_next) && d2.actions.assign_others === true);
  ok("a missing incident is a 404", (await call("GET", "/admin/safety/incidents/99999999", A)).status === 404 && (await call("GET", "/admin/safety/incidents/abc", A)).status === 404);

  // ---- audit log: append only, redaction, filters
  const aid = (await db.query("select max(id) m from app.admin_audit")).rows[0].m;
  const blockedUpdate = await db.query("update app.admin_audit set action = 'x' where id = $1", [aid]).then(() => false, () => true);
  const blockedDelete = await db.query("delete from app.admin_audit where id = $1", [aid]).then(() => false, () => true);
  const blockedTrunc = await db.query("truncate app.admin_audit").then(() => false, () => true);
  const blockedHist = await db.query("delete from app.safety_incident_events where incident_id = $1", [iid]).then(() => false, () => true);
  ok("the audit log cannot be updated, deleted or truncated", blockedUpdate && blockedDelete && blockedTrunc);
  ok("the incident history cannot be deleted", blockedHist);
  const al = (await call("GET", "/admin/audit-logs?action=safety_status", A)).json;
  ok("the audit log lists safety actions with who did them", al.data?.length >= 1 && al.data.every((x) => x.action === "safety_status"), JSON.stringify(al).slice(0, 300));
  ok("the audit log is refused to the limited administrator", (await call("GET", "/admin/audit-logs", S)).status === 403);
  ok("audit filters endpoint lists actions", JSON.stringify((await call("GET", "/admin/audit-logs/filters", A)).json).includes("safety_pii_view"));

  // ---- a completed trip for analytics and finance
  await call("POST", "/driver/online", DT, { online: true, latitude: 9.08, longitude: 7.4 });
  ok("going online opens an online session", (await db.query("select count(*)::int n from app.driver_online_sessions where driver_id = $1 and ended_at is null", [D.id])).rows[0].n === 1);
  const accept = await call("POST", `/driver/requests/${ride}/accept`, DT);
  ok("the driver accepts", accept.status === 200, JSON.stringify(accept.json).slice(0, 200));
  ok("the acceptance is recorded as an event", (await db.query("select count(*)::int n from app.driver_ride_events where ride_request_id = $1 and driver_id = $2 and event = 'assigned'", [ride, D.id])).rows[0].n === 1);
  await call("POST", `/driver/rides/${ride}/arrived`, DT);
  const code = (await call("GET", "/ride/current", P1.api_token)).json.data?.pickup_code?.code;
  if (code) await call("POST", `/driver/rides/${ride}/verify-pickup`, DT, { code });
  await call("POST", `/driver/rides/${ride}/start`, DT);
  const done = await call("POST", `/driver/rides/${ride}/complete`, DT);
  ok("the trip completes", done.status === 200, JSON.stringify(done.json).slice(0, 200));

  // ---- driver analytics
  const da = (await call("GET", `/admin/analytics/drivers?from=${today}&to=${today}`, A)).json;
  const dr = da.data?.find((x) => Number(x.id) === Number(D.id));
  ok("driver analytics list the driver", !!dr, JSON.stringify(da).slice(0, 300));
  ok("completed trips are counted", dr?.total_rides.available && dr.total_rides.value === 1, JSON.stringify(dr?.total_rides));
  ok("tracking-since dates are reported", !!da.tracking?.offers_and_backing_out_since && !!da.tracking?.online_time_since);
  ok("online time is a real figure or honestly unavailable", dr.online_seconds.available === true ? dr.online_seconds.value >= 0 : typeof dr.online_seconds.reason === "string");
  ok("every metric is {available:true,value} or {available:false,reason}", ["completion_rate", "cancellation_rate", "rejection_rate", "acceptance_rate", "average_rating", "earnings", "commission"].every((k) => dr[k].available ? "value" in dr[k] : typeof dr[k].reason === "string"));
  ok("no ratings means average rating is unavailable, not 0", dr.average_rating.available === false);
  ok("earnings are money lists by currency", Array.isArray(dr.earnings.value) && dr.earnings.value.length >= 1 && !!dr.earnings.value[0].currency);
  const dd = await call("GET", `/admin/analytics/drivers/${D.id}?from=${today}&to=${today}`, A);
  ok("driver detail has activity by hour and rating counts", dd.status === 200 && dd.json.activity.completed_by_hour.length === 24 && dd.json.rating_counts.length === 5);
  ok("an unknown driver is a 404", (await call("GET", "/admin/analytics/drivers/99999999", A)).status === 404);
  ok("a bad or reversed period is refused", (await call("GET", `/admin/analytics/drivers?from=${today}&to=2000-01-01`, A)).status === 422 && (await call("GET", "/admin/analytics/drivers?from=nope&to=nope", A)).status === 422);
  ok("a period before tracking began says so instead of inventing figures", (await call("GET", "/admin/analytics/drivers?from=2020-01-01&to=2020-01-31", A)).json.data.every((x) => x.rejection_rate.available === false));

  // ---- passenger analytics
  const pa = (await call("GET", `/admin/analytics/passengers?from=${today}&to=${today}`, A)).json;
  ok("passenger analytics load", pa.status === true && !!pa.period, JSON.stringify(pa).slice(0, 400));
  ok("they report completed rides", JSON.stringify(pa).includes("completed"));
  ok("a region filter works", (await call("GET", `/admin/analytics/passengers?from=${today}&to=${today}&region_id=${region}`, A)).status === 200);

  // ---- finance
  const fs = (await call("GET", `/admin/finance/summary?from=${today}&to=${today}&region_id=${region}`, A)).json;
  ok("finance summary loads", fs.status === true, JSON.stringify(fs).slice(0, 300));
  const flat = JSON.stringify(fs);
  const feeRow = (await db.query("select fare::float8 as fare from app.ride_requests where id = $1", [ride])).rows[0];
  ok("gross for the region equals the one completed fare", flat.includes(String(feeRow.fare)), `fare ${feeRow.fare}: ${flat.slice(0, 300)}`);
  ok("a bad category or payment method is refused", (await call("GET", "/admin/finance/summary?category=nope", A)).status === 422 && (await call("GET", "/admin/finance/summary?payment_method=nope", A)).status === 422);

  // reconciliation: loads, then detects an injected discrepancy
  const rc0 = (await call("GET", `/admin/finance/reconciliation?from=${today}&to=${today}`, A)).json;
  ok("reconciliation loads with checks", rc0.status === true && Array.isArray(rc0.checks) && rc0.checks.length >= 5, JSON.stringify(rc0).slice(0, 300));
  let wallet = (await db.query("select id from app.wallets where user_id = $1 and kind = 'driver' limit 1", [D.id])).rows[0];
  if (!wallet) wallet = (await db.query("insert into app.wallets (user_id, kind, currency, balance) values ($1, 'driver', 'NGN', 0) returning id", [D.id])).rows[0];
  if (wallet) {
    await db.query("update app.wallets set balance = balance + 123 where id = $1", [wallet.id]);
    const rc1 = (await call("GET", `/admin/finance/reconciliation?from=${today}&to=${today}`, A)).json;
    const chk = rc1.checks.find((k) => (k.id ?? k.key) === "wallet_balance_differs_from_ledger");
    ok("an injected wallet discrepancy is detected", rc1.clean === false && chk && chk.count >= 1, JSON.stringify(rc1.checks.map((k) => [k.id ?? k.key, k.count])));
    await db.query("update app.wallets set balance = balance - 123 where id = $1", [wallet.id]);
  } else console.log("SKIP wallet discrepancy (no driver wallet row)");

  // export
  ok("export is refused without 'finance export'", (await call("GET", `/admin/finance/export?report=rides&from=${today}&to=${today}`, S)).status === 403);
  const ex = await call("GET", `/admin/finance/export?report=rides&from=${today}&to=${today}&region_id=${region}`, A);
  ok("a CSV is returned with the right type and a filename", ex.status === 200 && /text\/csv/.test(ex.headers.get("content-type")) && /attachment; filename=/.test(ex.headers.get("content-disposition")));
  ok("the CSV has a header and exactly one trip row for this region", ex.text.trim().split("\n").length === 2, ex.text.slice(0, 300));
  ok("the CSV carries no phone numbers, emails or names", !/803\d{7}/.test(ex.text) && !ex.text.includes("@x.com") && !ex.text.includes(`p1${s}`));
  ok("an unknown report is refused", (await call("GET", `/admin/finance/export?report=nope&from=${today}&to=${today}`, A)).status === 422);
  ok("each export is audited", (await db.query("select count(*)::int n from app.admin_audit where action = 'finance_export' and target = 'rides'")).rows[0].n >= 1);
  for (const rep of ["ledger", "payouts", "reconciliation"]) ok(`the ${rep} export works`, (await call("GET", `/admin/finance/export?report=${rep}&from=${today}&to=${today}`, A)).status === 200);

  // audit coverage of the actions above
  const have = async (action) => (await db.query("select count(*)::int n from app.admin_audit where action = $1", [action])).rows[0].n > 0;
  ok("create, assign, classify, note, status and escalate are all in the audit log", (await Promise.all(["safety_create", "safety_assign", "safety_classify", "safety_note", "safety_escalate", "safety_status"].map(have))).every(Boolean));
} finally {
  if (!process.env.KEEP_DATA) try {
    // The audit log and incident history are append-only, so those rows stay; everything else is cleaned up.
    if (ids.length) {
      await db.query("delete from app.sos_alerts where user_id = any($1::bigint[])", [ids]).catch(() => {});
      await db.query("delete from app.ride_requests where rider_id = any($1::bigint[]) or driver_id = any($1::bigint[])", [ids]).catch(() => {});
    }
    if (subId) await db.query("delete from app.users where id = $1", [subId]).catch(() => {});
    if (roleId) await db.query("delete from app.admin_roles where id = $1", [roleId]).catch(() => {});
    if (region) {
      await db.query("delete from app.services where region_id = $1", [region]).catch(() => {});
      await db.query("delete from app.regions where id = $1", [region]).catch(() => {});
    }
    if (was.length) await db.query("update app.regions set status = true where id = any($1::bigint[])", [was]);
  } catch (e) { console.log("cleanup:", e.message); }
  await db.end();
}
console.log(fails ? `\n${fails} FAILED` : "\nALL PASSED");
process.exit(fails ? 1 : 0);
