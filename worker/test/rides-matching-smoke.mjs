// Matching: driver requests list, first-accept-wins, decline, passenger sees driver, sweep. Local/test DB only.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/rides-matching-smoke.mjs
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
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "M", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
await db.query("update app.regions set status = false where status");
const region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["MatchTest" + s])).rows[0].id;
const mk = async (n) => (await db.query(
  `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, status, payment_methods, booking_modes, sort_order)
   values ($1,$2,4,500,800,2,100,10,true,array['cash'],array['now'],0) returning id`, [n + s, region])).rows[0].id;
const svc = await mk("Car"), svcOther = await mk("Van");
const trip = { pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(svc), payment_method: "cash" };
const ids = [];
const makeDriver = async (tag, service, lat, lng) => {
  const D = await reg("driver", tag); ids.push(D.id);
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2 where user_id = $1", [D.id, service]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  const T = (await call("POST", "/login", null, { email: `${tag}${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", T, { mode: "driver" });
  await call("POST", "/driver/online", T, { online: true, latitude: lat, longitude: lng });
  return { id: D.id, T };
};
const oldMin = (await db.query("select value from app.settings where key = 'driver_min_wallet_balance'")).rows[0]?.value;
try {
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const P = await reg("rider", "pax"); ids.push(P.id);
  const d1 = await makeDriver("da", svc, 9.08, 7.4);
  const d2 = await makeDriver("db", svc, 9.081, 7.401);
  const far = await makeDriver("dc", svc, 9.3, 7.7);
  const other = await makeDriver("dd", svcOther, 9.08, 7.4);

  ok("requests need sign-in", (await call("GET", "/driver/requests", null)).status === 401);
  ok("passenger cannot read driver requests", (await call("GET", "/driver/requests", P.api_token)).status >= 400);
  ok("no requests yet", (await call("GET", "/driver/requests", d1.T)).json.requests?.length === 0);

  const r = await call("POST", "/ride/request", P.api_token, trip);
  const rid = r.json.data.id;
  const l1 = await call("GET", "/driver/requests", d1.T);
  const q = l1.json.requests?.[0];
  ok("nearby driver sees the request with fare, earning and pickup time", q?.id === rid && q.fare > 0 && q.earning > 0 && q.pickup_eta_minutes >= 1 && q.seconds_left > 0, JSON.stringify(l1.json).slice(0, 300));
  ok("rider phone number hidden before accepting", q?.rider.contact_number === null);
  ok("driver far away does not see it", (await call("GET", "/driver/requests", far.T)).json.requests?.length === 0);
  ok("driver of another ride type does not see it", (await call("GET", "/driver/requests", other.T)).json.requests?.length === 0);

  ok("decline hides it from that driver only", (await call("POST", `/driver/requests/${rid}/decline`, d2.T)).status === 200 && (await call("GET", "/driver/requests", d2.T)).json.requests.length === 0 && (await call("GET", "/driver/requests", d1.T)).json.requests.length === 1);
  ok("wrong ride type cannot accept", (await call("POST", `/driver/requests/${rid}/accept`, other.T)).json.code === "request_gone");

  // race: two drivers accept at once, exactly one wins
  const [a, b] = await Promise.all([call("POST", `/driver/requests/${rid}/accept`, d1.T), call("POST", `/driver/requests/${rid}/accept`, d2.T)]);
  const wins = [a, b].filter((x) => x.status === 200), loses = [a, b].filter((x) => x.status === 409);
  ok("exactly one driver wins a simultaneous accept", wins.length === 1 && loses.length === 1 && loses[0].json.code === "request_gone", JSON.stringify([a.json, b.json]).slice(0, 300));
  const winner = a.status === 200 ? d1 : d2, loser = winner === d1 ? d2 : d1;
  const row = (await db.query("select status, driver_id from app.ride_requests where id = $1", [rid])).rows[0];
  ok("ride is accepted by the winner", row.status === "accepted" && Number(row.driver_id) === Number(winner.id));
  ok("winner is no longer available", (await db.query("select is_available from app.users where id = $1", [winner.id])).rows[0].is_available === false);
  const act = await call("GET", "/driver/requests", winner.T);
  ok("winner's poll returns the active ride with rider phone", act.json.active?.id === rid && act.json.requests.length === 0 && !!act.json.active.rider.contact_number, JSON.stringify(act.json).slice(0, 300));
  ok("accepting again is refused", (await call("POST", `/driver/requests/${rid}/accept`, loser.T)).status === 409);

  const cur = await call("GET", "/ride/current", P.api_token);
  ok("passenger sees the driver and vehicle fields", cur.json.data?.status === "accepted" && Number(cur.json.data.driver?.id) === Number(winner.id) && "vehicle" in cur.json.data.driver && cur.json.data.driver.location?.lat != null, JSON.stringify(cur.json).slice(0, 400));
  const sw = await call("POST", "/mode", winner.T, { mode: "rider" });
  ok("driver cannot switch to passenger mode mid-trip", sw.status === 409 && sw.json.code === "active_trip");

  // a second request cannot be accepted by a driver already on a ride
  const P2 = await reg("rider", "px"); ids.push(P2.id);
  const r2 = await call("POST", "/ride/request", P2.api_token, trip);
  ok("busy driver cannot take another ride", (await call("POST", `/driver/requests/${r2.json.data.id}/accept`, winner.T)).status === 409);
  await call("POST", "/ride/cancel", P2.api_token, {});

  // passenger cancels accepted ride -> driver freed
  ok("passenger cancels the accepted ride", (await call("POST", "/ride/cancel", P.api_token, { reason: "x" })).status === 200);
  ok("driver is available again", (await db.query("select is_available from app.users where id = $1", [winner.id])).rows[0].is_available === true);

  // expired request cannot be accepted
  const r3 = await call("POST", "/ride/request", P.api_token, trip);
  await db.query("update app.ride_requests set expires_at = now() - interval '1 minute' where id = $1", [r3.json.data.id]);
  ok("expired request cannot be accepted", (await call("POST", `/driver/requests/${r3.json.data.id}/accept`, winner.T)).json.code === "request_gone");

  // offline driver
  await call("POST", "/driver/online", loser.T, { online: false });
  ok("offline driver told to go online", (await call("GET", "/driver/requests", loser.T)).json.code === "not_online");

} finally {
  if (oldMin !== undefined) await db.query("update app.settings set value = $1::jsonb where key = 'driver_min_wallet_balance'", [JSON.stringify(oldMin)]);
  await db.query("delete from app.ride_requests where service_id in ($1,$2)", [svc, svcOther]);
  await db.query("delete from app.services where id in ($1,$2)", [svc, svcOther]);
  await db.query("delete from app.regions where id = $1", [region]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
