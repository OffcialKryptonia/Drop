// Driver wallet admin checks against a running `wrangler dev` on a LOCAL/test database.
// Run: ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/driver-wallet-smoke.mjs
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD) throw new Error("set ADMIN_EMAIL and ADMIN_PASSWORD");
let fails = 0;
const ok = (n, c, extra = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : extra); if (!c) fails++; };
const call = async (method, path, token, body) => {
  const r = await fetch(API + path, { method, headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: "Bearer " + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, json: await r.json().catch(() => ({})) };
};
const s = Math.random().toString(36).slice(2, 8);

const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
ok("admin login", !!A);
const reg = (type) => call("POST", "/register", null, { first_name: "Dee", last_name: type + s, email: `${type}${s}@x.com`, username: `${type}${s}`, password: "secret123", user_type: type, contact_number: "0803" + Math.floor(1000000 + Math.random() * 8999999) });
const drv = (await reg("driver")).json.data, rdr = (await reg("rider")).json.data;
ok("driver and rider created", !!drv?.id && !!rdr?.id);

await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
const q = encodeURIComponent("driver" + s);
let l = await call("GET", `/admin/driver-wallets?filter=all&q=${q}`, A);
ok("driver listed with balance 0, not blocked", l.json.data?.[0]?.id === drv.id && l.json.data[0].balance === 0 && l.json.data[0].blocked === false, JSON.stringify(l.json));
ok("not in the blocked list", ((await call("GET", `/admin/driver-wallets?filter=blocked&q=${q}`, A)).json.data ?? []).length === 0);

ok("minimum can be raised", (await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 100 })).status === 200);
ok("now blocked", ((await call("GET", `/admin/driver-wallets?filter=blocked&q=${q}`, A)).json.data ?? []).length === 1);
const D = drv.api_token;
ok("driver app sees the minimum", (await call("GET", "/wallet-detail", D)).json.min_amount_to_get_ride === 100);
ok("rider app does not", (await call("GET", "/wallet-detail", rdr.api_token)).json.min_amount_to_get_ride === 0);

const credit = await call("POST", `/admin/driver-wallets/${drv.id}/adjust`, A, { direction: "credit", amount: 150, reason: "Cash handed in" });
ok("credit 150", credit.status === 200 && credit.json.balance === 150, JSON.stringify(credit.json));
ok("no longer blocked", ((await call("GET", `/admin/driver-wallets?filter=blocked&q=${q}`, A)).json.data ?? []).length === 0);
const debit = await call("POST", `/admin/driver-wallets/${drv.id}/adjust`, A, { direction: "debit", amount: 400, reason: "Commission correction" });
ok("debit 400 takes balance to -250", debit.status === 200 && debit.json.balance === -250, JSON.stringify(debit.json));
ok("driver sees the negative balance", (await call("GET", "/wallet-detail", D)).json.total_amount === -250);
const led = await call("GET", `/admin/driver-wallets/${drv.id}/ledger`, A);
ok("history has both rows", led.json.data?.length === 2 && led.json.data[0].balance_after === -250);

ok("reason is required", (await call("POST", `/admin/driver-wallets/${drv.id}/adjust`, A, { direction: "credit", amount: 5, reason: "x" })).status === 422);
ok("amount must be positive", (await call("POST", `/admin/driver-wallets/${drv.id}/adjust`, A, { direction: "credit", amount: -5, reason: "negative" })).status === 422);
ok("riders cannot be adjusted here", (await call("POST", `/admin/driver-wallets/${rdr.id}/adjust`, A, { direction: "debit", amount: 5, reason: "nope nope" })).status === 404);

// permissions: a role that may only LIST driver wallets
const role = await call("POST", "/admin/roles", A, { name: "dw" + s, label: "DW viewer", permissions: ["driver_wallet list"] });
const sub = await call("POST", "/admin/sub-admins", A, { first_name: "Vi", last_name: "Ewer", email: `v${s}@x.com`, username: `v${s}`, contact_number: null, admin_role_id: role.json.id, status: "active", password: "viewer-pass-123" });
const V = (await call("POST", "/login", null, { email: `v${s}@x.com`, password: "viewer-pass-123", user_type: "admin" })).json.data?.api_token;
ok("viewer can list", (await call("GET", "/admin/driver-wallets?filter=all", V)).status === 200);
ok("viewer cannot adjust", (await call("POST", `/admin/driver-wallets/${drv.id}/adjust`, V, { direction: "credit", amount: 5, reason: "not allowed" })).status === 403);
ok("viewer cannot change the minimum", (await call("PUT", "/admin/wallet-settings", V, { driver_min_wallet_balance: 5 })).status === 403);
ok("a driver cannot reach admin wallets", (await call("GET", "/admin/driver-wallets", D)).status === 403);

await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
console.log(fails ? `${fails} FAILED` : "ALL PASSED"); process.exit(fails ? 1 : 0);
