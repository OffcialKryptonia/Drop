// Roles and mode switching against a running `wrangler dev` on a LOCAL/test database.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/roles-smoke.mjs
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
const reg = (type, tag) => call("POST", "/register", null, { first_name: "Mo", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: "0803" + Math.floor(1000000 + Math.random() * 8999999) });
const login = (tag, extra = {}) => call("POST", "/login", null, { email: `${tag}${s}@x.com`, password: "secret123", ...extra });

const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

// --- a plain rider ---
const r = (await reg("rider", "rid")).json.data;
ok("rider: roles [rider], mode rider, no driver status", JSON.stringify(r.roles) === '["rider"]' && r.active_mode === "rider" && r.driver_status === null, JSON.stringify(r));
let m = await call("POST", "/mode", r.api_token, { mode: "driver" });
ok("rider cannot switch to driver mode", m.status === 403 && m.json.code === "not_driver", JSON.stringify(m.json));
ok("bad mode value refused", (await call("POST", "/mode", r.api_token, { mode: "pilot" })).status === 422);
ok("switching to rider mode while already rider is fine", (await call("POST", "/mode", r.api_token, { mode: "rider" })).status === 200);
ok("mode needs sign-in", (await call("POST", "/mode", null, { mode: "rider" })).status === 401);
ok("admin cannot use mode switching", (await call("POST", "/mode", A, { mode: "rider" })).status === 403);

// --- an applicant (old driver sign-up files an application) ---
const d = (await reg("driver", "drv")).json.data;
ok("applicant: has driver role, status submitted", d.roles.includes("driver") && d.driver_status === "submitted", JSON.stringify(d));
const dl = (await login("drv")).json.data;
ok("unified login (no user_type) opens in rider mode", dl.active_mode === "rider");
m = await call("POST", "/mode", dl.api_token, { mode: "driver" });
ok("not approved yet: driver mode refused", m.status === 403 && m.json.code === "not_approved", JSON.stringify(m.json));

// --- approved driver ---
await db.query("update app.driver_profiles set status = 'approved' where user_id = $1", [d.id]);
await db.query("update app.users set status = 'active' where id = $1", [d.id]);
m = await call("POST", "/mode", dl.api_token, { mode: "driver" });
ok("approved: switch to driver mode works", m.status === 200 && m.json.data.active_mode === "driver" && m.json.data.driver_status === "approved", JSON.stringify(m.json));
await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 100 });
ok("driver mode shows driver wallet and minimum", (await call("GET", "/wallet-detail", dl.api_token)).json.min_amount_to_get_ride === 100);
const cr = await call("POST", `/admin/driver-wallets/${d.id}/adjust`, A, { direction: "credit", amount: 50, reason: "Test credit" });
ok("admin credits the DRIVER wallet", cr.status === 200 && cr.json.balance === 50, JSON.stringify(cr.json));
ok("driver mode balance 50", (await call("GET", "/wallet-detail", dl.api_token)).json.total_amount === 50);
await call("POST", "/mode", dl.api_token, { mode: "rider" });
const rw = await call("GET", "/wallet-detail", dl.api_token);
ok("passenger mode shows the separate rider wallet (0, no minimum)", rw.json.total_amount === 0 && rw.json.min_amount_to_get_ride === 0, JSON.stringify(rw.json));
await db.query("update app.users set is_online = true where id = $1", [d.id]);
await call("POST", "/mode", dl.api_token, { mode: "driver" });
const lg = (await login("drv")).json.data;
ok("driver still online keeps driver mode on login", lg.active_mode === "driver");
await call("POST", "/mode", lg.api_token, { mode: "rider" });
const off = (await db.query("select is_online from app.users where id = $1", [d.id])).rows[0].is_online;
ok("switching to passenger mode takes the driver offline", off === false);
ok("old driver app login (user_type driver) lands in driver mode", (await login("drv", { user_type: "driver" })).json.data.active_mode === "driver");

// --- suspended ---
await db.query("update app.driver_profiles set status = 'suspended' where user_id = $1", [d.id]);
m = await call("POST", "/mode", lg.api_token, { mode: "driver" });
ok("suspended driver cannot switch to driver mode", m.status === 403 && m.json.code === "suspended");
ok("suspended driver can still use passenger mode", (await call("POST", "/mode", lg.api_token, { mode: "rider" })).status === 200);

await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
await db.end();
console.log(fails ? `${fails} FAILED` : "ALL PASSED"); process.exit(fails ? 1 : 0);
