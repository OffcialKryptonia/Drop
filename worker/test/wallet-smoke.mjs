// Wallet + Pocketfi checks against a running `wrangler dev` on a LOCAL/test database, with a mock Pocketfi.
// Start the dev server with:  npx wrangler dev --var POCKETFI_BASE_URL:http://127.0.0.1:9911
// Run:  ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/wallet-smoke.mjs
import http from "node:http";
import crypto from "node:crypto";

const BASE = process.env.BASE ?? "http://127.0.0.1:8787", API = BASE + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD } = process.env;
if (!ADMIN_EMAIL || !ADMIN_PASSWORD) throw new Error("set ADMIN_EMAIL and ADMIN_PASSWORD");
const SECRET = "test-webhook-secret-" + crypto.randomUUID();
const CUSTOMER_ID = 700000 + Math.floor(Math.random() * 99999);
const ACCOUNT = String(7000000000 + Math.floor(Math.random() * 999999999));

// --- mock Pocketfi ---
let created = 0;
const mock = http.createServer((req, res) => {
  res.setHeader("content-type", "application/json");
  if (req.headers.authorization !== "Bearer test-token") { res.statusCode = 401; return res.end("{}"); }
  if (req.method === "POST" && req.url === "/virtual-accounts/create") {
    created++; return res.end(JSON.stringify({ status: true, service: "CREATE_VIRTUAL_ACCOUNT", businessId: 1, banks: [{ bankName: "kuda", accountNumber: ACCOUNT, accountName: "Test Rider" }] }));
  }
  if (req.method === "GET" && req.url.startsWith("/virtual-accounts/fetch")) {
    return res.end(JSON.stringify({ status: true, accounts: [{ id: 1, name: "Test", bank: "kuda", account: ACCOUNT, businessId: 1, user_id: CUSTOMER_ID }] }));
  }
  res.statusCode = 404; res.end("{}");
});
await new Promise((r) => mock.listen(9911, r));

let fails = 0;
const ok = (name, cond, extra = "") => { console.log(cond ? "PASS" : "FAIL", name, cond ? "" : extra); if (!cond) fails++; };
const call = async (method, path, { token, body, headers } = {}) => {
  const r = await fetch(API + path, { method, headers: { Accept: "application/json", ...(body !== undefined && typeof body !== "string" ? { "Content-Type": "application/json" } : {}), ...(token ? { Authorization: "Bearer " + token } : {}), ...headers }, body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body) });
  return { status: r.status, json: await r.json().catch(() => ({})) };
};
const sign = (raw) => crypto.createHmac("sha512", SECRET).update(raw).digest("hex");
const hook = (payload, sig) => { const raw = JSON.stringify(payload); return call("POST", "/webhooks/pocketfi", { body: raw, headers: { "Content-Type": "application/json", "Pocketfi-Signature": sig ?? sign(raw) } }); };
const event = (ref, amount, customer = CUSTOMER_ID) => ({ order: { amount, settlement_amount: Number(amount) - 0.9, fee: 0.9, description: "x" }, transaction: { reference: ref }, account_number: "******1234", customer: { id: customer } });

try {
  const adm = await call("POST", "/login", { body: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" } });
  const A = adm.json.data?.api_token; ok("admin login", !!A);
  const set = await call("PUT", "/admin/payment-gateways/pocketfi", { token: A, body: { is_test: true, status: true, credentials: { test: { business_id: "1", api_token: "test-token", secret_key: SECRET } } } });
  ok("save pocketfi test keys", set.status === 200, JSON.stringify(set.json));

  const s = crypto.randomUUID().slice(0, 8);
  const reg = await call("POST", "/register", { body: { first_name: "Test", last_name: "Rider", email: `w${s}@x.com`, username: `w${s}`, password: "secret123", contact_number: "08031234567" } });
  const R = reg.json.data?.api_token; ok("register rider", !!R, JSON.stringify(reg.json));
  const bare = await call("POST", "/register", { body: { first_name: "No", last_name: "Phone", email: `n${s}@x.com`, username: `n${s}`, password: "secret123" } });

  ok("balance starts at 0", (await call("GET", "/wallet-detail", { token: R })).json.total_amount === 0);
  ok("gateway list has no keys", JSON.stringify((await call("GET", "/payment-gateway-list?status=1", { token: R })).json).includes("test-token") === false);
  ok("no phone -> 422", (await call("GET", "/wallet/virtual-account", { token: bare.json.data?.api_token })).status === 422);

  const va = await call("GET", "/wallet/virtual-account", { token: R });
  ok("virtual account created", va.json.data?.account_number === ACCOUNT, JSON.stringify(va.json));
  const va2 = await call("GET", "/wallet/virtual-account", { token: R });
  ok("virtual account reused (one Pocketfi call)", va2.json.data?.account_number === ACCOUNT && created === 1, `created=${created}`);

  ok("bad signature rejected", (await hook(event("PFI|bad", "100.00"), "00")).status === 400);
  ok("missing signature rejected", (await call("POST", "/webhooks/pocketfi", { body: "{}" })).status === 400);
  await new Promise((r) => setTimeout(r, 400)); // let the background customer-id lookup finish
  const REF = "PFI|" + s;
  const h1 = await hook(event(REF, "5000.00"));
  ok("webhook credits", h1.status === 200 && !h1.json.flagged, JSON.stringify(h1.json));
  ok("balance 5000", (await call("GET", "/wallet-detail", { token: R })).json.total_amount === 5000);
  const h2 = await hook(event(REF, "5000.00"));
  ok("replay is harmless", h2.status === 200 && h2.json.duplicate === true);
  ok("balance still 5000", (await call("GET", "/wallet-detail", { token: R })).json.total_amount === 5000);
  const h3 = await hook(event("PFI|x" + s, "250.50"));
  ok("second transfer adds", (await call("GET", "/wallet-detail", { token: R })).json.total_amount === 5250.5, JSON.stringify(h3.json));
  const h4 = await hook(event("PFI|u" + s, "100.00", 999999999));
  ok("unknown customer flagged, not credited", h4.json.flagged === true);
  const h5 = await hook(event("PFI|z" + s, "-5"));
  ok("bad amount flagged", h5.json.flagged === true);

  const PREF = "PFI|p" + s;
  const burst = await Promise.all(Array.from({ length: 6 }, () => hook(event(PREF, "100.00"))));
  ok("6 simultaneous deliveries credit once", burst.every((b) => b.status === 200) && burst.filter((b) => !b.json.duplicate).length === 1, JSON.stringify(burst.map((b) => b.json)));
  ok("balance 5350.50 after burst", (await call("GET", "/wallet-detail", { token: R })).json.total_amount === 5350.5);

  const list = await call("GET", "/wallet-list?page=1", { token: R });
  ok("history has 3 rows", list.json.data?.length === 3 && list.json.pagination.total_items === 3, JSON.stringify(list.json));
  ok("history row shape", list.json.data?.[0].type === "credit" && list.json.data[0].balance === 5350.5);
  ok("other users cannot see it", (await call("GET", "/wallet-list", { token: bare.json.data?.api_token })).json.data?.length === 0);
} finally { mock.close(); }
console.log(fails ? `${fails} FAILED` : "ALL PASSED"); process.exit(fails ? 1 : 0);
