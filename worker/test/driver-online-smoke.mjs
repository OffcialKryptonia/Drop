// Driver online toggle against a running `wrangler dev` on a LOCAL/test database.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/driver-online-smoke.mjs
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
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const reg = await call("POST", "/register", null, { first_name: "On", last_name: "Line" + s, email: `on${s}@x.com`, username: `on${s}`, password: "secret123", user_type: "driver", contact_number: "0803" + Math.floor(1000000 + Math.random() * 8999999) });
const d = reg.json.data;
const login = (await call("POST", "/login", null, { email: `on${s}@x.com`, password: "secret123" })).json.data;
const T = login.api_token;
const pos = { latitude: 9.0765, longitude: 7.3986 };

ok("passenger-only user cannot use driver status", (await call("GET", "/driver/status", (await call("POST", "/register", null, { first_name: "P", last_name: "X" + s, email: `px${s}@x.com`, username: `px${s}`, password: "secret123", user_type: "rider", contact_number: "0803" + Math.floor(1000000 + Math.random() * 8999999) })).json.data.api_token)).status === 403);
ok("unapproved applicant refused", (await call("GET", "/driver/status", T)).status === 403);

await db.query("update app.driver_profiles set status = 'approved' where user_id = $1", [d.id]);
await db.query("update app.users set status = 'active' where id = $1", [d.id]);
await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 100 });

let st = await call("GET", "/driver/status", T);
ok("approved: status ok, offline, wallet 0 of 100, blocked by wallet", st.status === 200 && st.json.is_online === false && st.json.wallet.minimum === 100 && st.json.online_block?.code === "wallet_below_minimum", JSON.stringify(st.json));

let on = await call("POST", "/driver/online", T, { online: true, ...pos });
ok("not in driver mode: cannot go online", on.status === 409 && on.json.code === "not_in_driver_mode", JSON.stringify(on.json));
await call("POST", "/mode", T, { mode: "driver" });
on = await call("POST", "/driver/online", T, { online: true, ...pos });
ok("wallet below minimum: cannot go online", on.status === 403 && on.json.code === "wallet_below_minimum" && on.json.minimum === 100, JSON.stringify(on.json));

await call("POST", `/admin/driver-wallets/${d.id}/adjust`, A, { direction: "credit", amount: 150, reason: "Test credit" });
ok("location required to go online", (await call("POST", "/driver/online", T, { online: true })).status === 422);
on = await call("POST", "/driver/online", T, { online: true, ...pos });
ok("funded: goes online", on.status === 200 && on.json.is_online === true, JSON.stringify(on.json));
let row = (await db.query("select is_online, is_available, latitude, longitude from app.users where id = $1", [d.id])).rows[0];
ok("database shows online and available at the position", row.is_online && row.is_available && Math.abs(row.latitude - 9.0765) < 1e-6, JSON.stringify(row));
const ping = await call("POST", "/driver/location", T, { latitude: 9.1, longitude: 7.4 });
ok("location ping updates while online", ping.json.updated === true);
ok("bad location refused", (await call("POST", "/driver/location", T, { latitude: 999, longitude: 7 })).status === 422);

await db.query("insert into app.driver_documents (driver_id, document_id, file_key, content_type, size_bytes, expire_date, is_verified) select $1, id, 'x', 'image/jpeg', 1, current_date - 5, 1 from app.documents where is_required and type = 'driver' limit 1", [d.id]);
const reqDocs = (await db.query("select count(*)::int n from app.documents where is_required and type = 'driver'")).rows[0].n;
if (reqDocs) {
  await call("POST", "/driver/online", T, { online: false });
  on = await call("POST", "/driver/online", T, { online: true, ...pos });
  ok("expired required document blocks going online", on.status === 403 && on.json.code === "documents_expired", JSON.stringify(on.json));
  await db.query("delete from app.driver_documents where driver_id = $1", [d.id]);
} else console.log("SKIP expired document check (no required driver documents defined)");

on = await call("POST", "/driver/online", T, { online: true, ...pos });
ok("goes online again", on.status === 200);
const off = await call("POST", "/driver/online", T, { online: false });
ok("goes offline", off.status === 200 && off.json.is_online === false);
ok("ping ignored when offline", (await call("POST", "/driver/location", T, { latitude: 9.2, longitude: 7.5 })).json.updated === false);
await call("POST", "/driver/online", T, { online: true, ...pos });
await call("POST", "/mode", T, { mode: "rider" });
row = (await db.query("select is_online from app.users where id = $1", [d.id])).rows[0];
ok("switching to passenger mode forces offline", row.is_online === false);

await db.query("delete from app.users where id = $1", [d.id]).catch(() => {});
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
