// Ride estimate and request against a running `wrangler dev` on a LOCAL/test database.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/rides-smoke.mjs
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
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "R", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

// --- test data: one region with a boundary around Abuja, one ride type, one extra. Other regions are switched off meanwhile. ---
const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
await db.query("update app.regions set status = false where status");
const region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["RidesTest" + s])).rows[0].id;
const svc = (await db.query(
  `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, status, payment_methods, booking_modes, sort_order)
   values ($1,$2,4,500,800,2,100,10,true,array['cash','wallet'],array['now'],0) returning id`, ["TestCar" + s, region])).rows[0].id;
const hidden = (await db.query(
  `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, status, booking_modes) values ($1,$2,4,100,100,true,array['scheduled']) returning id`, ["SchedOnly" + s, region])).rows[0].id;
const opt = (await db.query("insert into app.service_options (name, price) values ($1, 250) returning id", ["ChildSeat" + s])).rows[0].id;
const fareOf = (km, min) => Math.max(500 + Math.max(0, km - 2) * 100 + min * 10, 800);

const pickup = { lat: 9.0765, lng: 7.3986, address: "Wuse" };
const dropoff = { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" };
const trip = { pickup, dropoff };
let driverId = null, driver2Id = null;
try {
  const P = await reg("rider", "pax");
  ok("estimate needs sign-in", (await call("POST", "/ride/estimate", null, trip)).status === 401);
  ok("bad coordinates refused", (await call("POST", "/ride/estimate", P.api_token, { pickup: { lat: 999, lng: 7 }, dropoff })).status === 422);
  let e = await call("POST", "/ride/estimate", P.api_token, { pickup: { lat: 0.1, lng: 0.1 }, dropoff });
  ok("outside the service area", e.status === 422 && e.json.code === "outside_service_area", JSON.stringify(e.json));
  e = await call("POST", "/ride/estimate", P.api_token, { pickup, dropoff: { lat: 0.1, lng: 0.1 } });
  ok("drop-off outside the area", e.status === 422 && e.json.code === "dropoff_outside_area", JSON.stringify(e.json));
  e = await call("POST", "/ride/estimate", P.api_token, { pickup, dropoff: pickup });
  ok("same place refused", e.status === 422 && e.json.code === "same_place", JSON.stringify(e.json));

  e = await call("POST", "/ride/estimate", P.api_token, trip);
  const t = e.json.ride_types?.find((x) => x.id === Number(svc));
  ok("estimate ok, route estimated", e.status === 200 && e.json.route_source === "estimate" && e.json.distance_unit === "km", JSON.stringify(e.json).slice(0, 300));
  ok("only 'now' ride types of the region are offered", t && !e.json.ride_types.some((x) => x.id === Number(hidden)), JSON.stringify(e.json.ride_types?.map((x) => x.id)));
  ok("fare follows the admin prices", t && Math.abs(t.fare - fareOf(e.json.distance, e.json.duration_minutes)) < 0.011, `${t?.fare} vs ${fareOf(e.json.distance, e.json.duration_minutes)}`);
  ok("extras are listed with prices", e.json.options.some((o) => o.id === Number(opt) && o.price === 250));
  ok("no drivers online yet", t.drivers_nearby === 0 && t.pickup_eta_minutes === null);

  // --- request rules ---
  const base = { ...trip, service_id: Number(svc), payment_method: "cash" };
  ok("unknown payment method refused", (await call("POST", "/ride/request", P.api_token, { ...base, payment_method: "bitcoin" })).status === 422);
  ok("ride type from nowhere refused", (await call("POST", "/ride/request", P.api_token, { ...base, service_id: 99999999 })).json.code === "ride_type_unavailable");
  ok("scheduled-only ride type refused", (await call("POST", "/ride/request", P.api_token, { ...base, service_id: Number(hidden) })).json.code === "ride_type_unavailable");
  ok("card not offered by this ride type", (await call("POST", "/ride/request", P.api_token, { ...base, payment_method: "card" })).status === 422);
  ok("unknown extra refused", (await call("POST", "/ride/request", P.api_token, { ...base, option_ids: [99999999] })).status === 422);
  const poor = await call("POST", "/ride/request", P.api_token, { ...base, payment_method: "wallet" });
  ok("wallet too low refused", poor.status === 422 && poor.json.code === "insufficient_wallet", JSON.stringify(poor.json));

  const r1 = await call("POST", "/ride/request", P.api_token, { ...base, option_ids: [Number(opt)], fare: 1 });
  ok("request created, phone-sent fare ignored, extras added", r1.status === 201 && r1.json.data.status === "searching" && Math.abs(r1.json.data.fare - (t.fare + 250)) < 0.011 && r1.json.data.options.length === 1, JSON.stringify(r1.json));
  ok("second open request refused", (await call("POST", "/ride/request", P.api_token, base)).json.code === "already_has_ride");
  const cur = await call("GET", "/ride/current", P.api_token);
  ok("current returns the open request", cur.json.data?.id === r1.json.data.id);
  const cx = await call("POST", "/ride/cancel", P.api_token, { reason: "Changed my mind" });
  ok("cancel works", cx.status === 200 && cx.json.id === r1.json.data.id, JSON.stringify(cx.json));
  ok("nothing left to cancel", (await call("POST", "/ride/cancel", P.api_token, {})).status === 409);
  ok("current is empty after cancel", (await call("GET", "/ride/current", P.api_token)).json.data === null);

  // wallet payment with enough money
  await db.query("insert into app.wallets (user_id, kind, balance) values ($1,'rider',5000) on conflict (user_id, kind) do update set balance = 5000", [P.id]);
  const rw = await call("POST", "/ride/request", P.api_token, { ...base, payment_method: "wallet" });
  ok("wallet ride accepted with enough balance", rw.status === 201, JSON.stringify(rw.json));
  await call("POST", "/ride/cancel", P.api_token, {});

  // expiry
  const r2 = await call("POST", "/ride/request", P.api_token, base);
  await db.query("update app.ride_requests set expires_at = now() - interval '1 minute' where id = $1", [r2.json.data.id]);
  ok("unaccepted request expires", (await call("GET", "/ride/current", P.api_token)).json.data === null && (await db.query("select status from app.ride_requests where id = $1", [r2.json.data.id])).rows[0].status === "expired");

  // --- a driver nearby ---
  const D = await reg("driver", "drv"); driverId = D.id;
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2 where user_id = $1", [D.id, svc]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const DT = (await call("POST", "/login", null, { email: `drv${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", DT, { mode: "driver" });
  ok("driver goes online near the pickup", (await call("POST", "/driver/online", DT, { online: true, latitude: 9.08, longitude: 7.4 })).status === 200);
  e = await call("POST", "/ride/estimate", P.api_token, trip);
  const t2 = e.json.ride_types.find((x) => x.id === Number(svc));
  ok("estimate shows 1 driver nearby with a pickup time", t2.drivers_nearby === 1 && t2.pickup_eta_minutes >= 1, JSON.stringify(t2));
  await db.query("update app.users set last_location_update_at = now() - interval '10 minutes' where id = $1", [D.id]);
  e = await call("POST", "/ride/estimate", P.api_token, trip);
  ok("a driver with an old location is not counted", e.json.ride_types.find((x) => x.id === Number(svc)).drivers_nearby === 0);
  await db.query("update app.users set last_location_update_at = now() where id = $1", [D.id]);
  await db.query("update app.users set latitude = 9.3, longitude = 7.7, last_location_update_at = now() where id = $1", [D.id]);
  e = await call("POST", "/ride/estimate", P.api_token, trip);
  ok("a driver far away is not counted", e.json.ride_types.find((x) => x.id === Number(svc)).drivers_nearby === 0);

  ok("driver in driver mode cannot request a ride", (await call("POST", "/ride/request", DT, base)).json.code === "not_in_passenger_mode");
  await call("POST", "/mode", DT, { mode: "rider" });
  const rd = await call("POST", "/ride/request", DT, base);
  ok("same person can ride as a passenger after switching", rd.status === 201, JSON.stringify(rd.json));
  const sw = await call("POST", "/mode", DT, { mode: "driver" });
  ok("cannot switch to driver mode during an open ride", sw.status === 409 && sw.json.code === "active_trip", JSON.stringify(sw.json));
  await call("POST", "/ride/cancel", DT, {});
  ok("can switch once the ride is cancelled", (await call("POST", "/mode", DT, { mode: "driver" })).status === 200);
} finally {
  await db.query("delete from app.ride_requests where service_id in ($1,$2)", [svc, hidden]);
  await db.query("delete from app.services where id in ($1,$2)", [svc, hidden]);
  await db.query("delete from app.service_options where id = $1", [opt]);
  await db.query("delete from app.regions where id = $1", [region]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  if (driverId) await db.query("delete from app.users where id = $1", [driverId]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
