// Trip states, settlement, cancellation fees. Local/test DB only.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/rides-trip-smoke.mjs
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
  `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, cancellation_fee, commission_type, admin_commission, status, payment_methods, booking_modes, sort_order)
   values ($1,$2,4,500,800,2,100,10,300,'percentage',10,true,array['cash','wallet'],array['now'],0) returning id`, [n + s, region])).rows[0].id;
const svc = await mk("Car");
const trip = { pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(svc), payment_method: "cash" };
const ids = [];
const driver = async (tag) => {
  const D = await reg("driver", tag); ids.push(D.id);
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2 where user_id = $1", [D.id, svc]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  const T = (await call("POST", "/login", null, { email: `${tag}${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", T, { mode: "driver" });
  await call("POST", "/driver/online", T, { online: true, latitude: 9.08, longitude: 7.4 });
  return { id: D.id, T };
};
const bal = async (id, kind) => Number((await db.query("select balance from app.wallets where user_id = $1 and kind = $2", [id, kind])).rows[0]?.balance ?? 0);
const oldMin = (await db.query("select value from app.settings where key = 'driver_min_wallet_balance'")).rows[0]?.value;
try {
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const P = await reg("rider", "pax"); ids.push(P.id);
  const d = await driver("dx"), d2 = await driver("dy");
  for (const x of [d, d2]) await db.query("insert into app.wallets (user_id, kind, balance, allow_negative) values ($1,'driver',5000,true) on conflict (user_id, kind) do update set balance = 5000", [x.id]);
  const book = async (method = "cash", pax = P) => { const r = await call("POST", "/ride/request", pax.api_token, { ...trip, payment_method: method }); return r.json.data; };

  // --- cash trip ---
  let r = await book("cash");
  ok("other driver cannot move a ride that is not theirs", (await call("POST", `/driver/rides/${r.id}/arrived`, d.T)).status === 409);
  await call("POST", `/driver/requests/${r.id}/accept`, d.T);
  ok("cannot start before arriving", (await call("POST", `/driver/rides/${r.id}/start`, d.T)).status === 409);
  ok("cannot complete before starting", (await call("POST", `/driver/rides/${r.id}/complete`, d.T)).status === 409);
  ok("another driver cannot mark arrival", (await call("POST", `/driver/rides/${r.id}/arrived`, d2.T)).status === 409);
  ok("arrived", (await call("POST", `/driver/rides/${r.id}/arrived`, d.T)).json.data?.status === "arrived");
  ok("passenger sees arrived", (await call("GET", "/ride/current", P.api_token)).json.data?.status === "arrived");
  ok("started", (await call("POST", `/driver/rides/${r.id}/start`, d.T)).json.data?.status === "in_progress");
  const tr = await call("POST", "/ride/cancel", P.api_token, {});
  ok("passenger cannot cancel a started trip", tr.status === 409 && tr.json.code === "trip_in_progress");
  const w0 = await bal(d.id, "driver");
  const done = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  const fare = Number(r.fare), com = Math.round(fare * 10) / 100;
  ok("completed: cash, collect from rider, commission 10%", done.status === 200 && done.json.data.collect_cash === true && Math.abs(done.json.data.commission - com) < 0.011, JSON.stringify(done.json));
  ok("commission debited from driver wallet", Math.abs((await bal(d.id, "driver")) - (w0 - com)) < 0.011, `${await bal(d.id, "driver")} vs ${w0 - com}`);
  ok("completing twice changes nothing", (await call("POST", `/driver/rides/${r.id}/complete`, d.T)).status === 409 && Math.abs((await bal(d.id, "driver")) - (w0 - com)) < 0.011);
  ok("driver is available again", (await db.query("select is_available from app.users where id = $1", [d.id])).rows[0].is_available === true);
  ok("passenger has no open ride", (await call("GET", "/ride/current", P.api_token)).json.data === null);
  ok("passenger history shows it", (await call("GET", "/ride/history", P.api_token)).json.data[0]?.status === "completed");
  const h = await call("GET", "/driver/rides/history", d.T);
  ok("driver history shows earning", h.json.data[0]?.id === r.id && Math.abs(h.json.data[0].earning - (fare - com)) < 0.011);

  // --- wallet trip ---
  await db.query("insert into app.wallets (user_id, kind, balance) values ($1,'rider',5000) on conflict (user_id, kind) do update set balance = 5000", [P.id]);
  r = await book("wallet");
  const dw0 = await bal(d.id, "driver");
  await call("POST", `/driver/requests/${r.id}/accept`, d.T); await call("POST", `/driver/rides/${r.id}/arrived`, d.T); await call("POST", `/driver/rides/${r.id}/start`, d.T);
  const dw = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  const f2 = Number(r.fare), c2 = Math.round(f2 * 10) / 100;
  ok("wallet trip paid from rider wallet", dw.json.data?.paid_with === "wallet" && dw.json.data.collect_cash === false && Math.abs((await bal(P.id, "rider")) - (5000 - f2)) < 0.011, JSON.stringify(dw.json));
  ok("driver credited fare minus commission", Math.abs((await bal(d.id, "driver")) - (dw0 + f2 - c2)) < 0.011);

  // --- wallet trip but rider's money is gone -> settled as cash ---
  r = await book("wallet");
  await call("POST", `/driver/requests/${r.id}/accept`, d.T); await call("POST", `/driver/rides/${r.id}/arrived`, d.T); await call("POST", `/driver/rides/${r.id}/start`, d.T);
  await db.query("update app.wallets set balance = 0 where user_id = $1 and kind = 'rider'", [P.id]);
  const fb = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  ok("empty rider wallet falls back to cash", fb.json.data?.paid_with === "cash" && fb.json.data.collect_cash === true, JSON.stringify(fb.json));

  // --- driver backs out: request returns to others, not to him ---
  r = await book("cash");
  await call("POST", `/driver/requests/${r.id}/accept`, d.T);
  ok("driver cancels before trip", (await call("POST", `/driver/rides/${r.id}/cancel`, d.T)).status === 200);
  ok("ride is searching again, driver cleared", (await db.query("select status, driver_id from app.ride_requests where id = $1", [r.id])).rows[0].status === "searching");
  ok("same driver no longer sees it", (await call("GET", "/driver/requests", d.T)).json.requests.length === 0);
  ok("other driver sees it", (await call("GET", "/driver/requests", d2.T)).json.requests[0]?.id === r.id);

  // --- passenger cancels: free inside grace period, fee after arrival ---
  await call("POST", `/driver/requests/${r.id}/accept`, d2.T);
  await db.query("update app.wallets set balance = 1000 where user_id = $1 and kind = 'rider'", [P.id]);
  let cx = await call("POST", "/ride/cancel", P.api_token, {});
  ok("early cancel is free", cx.status === 200 && cx.json.cancellation_fee === 0, JSON.stringify(cx.json));
  r = await book("cash");
  await call("POST", `/driver/requests/${r.id}/accept`, d2.T); await call("POST", `/driver/rides/${r.id}/arrived`, d2.T);
  const dc0 = await bal(d2.id, "driver");
  cx = await call("POST", "/ride/cancel", P.api_token, {});
  ok("cancel after driver arrived costs the fee", cx.json.cancellation_fee === 300, JSON.stringify(cx.json));
  ok("fee taken from rider wallet", (await bal(P.id, "rider")) === 700);
  ok("driver gets fee minus commission", Math.abs((await bal(d2.id, "driver")) - (dc0 + 270)) < 0.011);
  // late cancel after grace
  r = await book("cash");
  await call("POST", `/driver/requests/${r.id}/accept`, d2.T);
  await db.query("update app.ride_requests set accepted_at = now() - interval '10 minutes' where id = $1", [r.id]);
  await db.query("update app.wallets set balance = 100 where user_id = $1 and kind = 'rider'", [P.id]);
  cx = await call("POST", "/ride/cancel", P.api_token, {});
  ok("late cancel charges only what the wallet has", cx.json.cancellation_fee === 100, JSON.stringify(cx.json));
} finally {
  if (oldMin !== undefined) await db.query("update app.settings set value = $1::jsonb where key = 'driver_min_wallet_balance'", [JSON.stringify(oldMin)]);
  await db.query("delete from app.ride_requests where service_id = $1", [svc]);
  await db.query("delete from app.services where id = $1", [svc]);
  await db.query("delete from app.regions where id = $1", [region]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
