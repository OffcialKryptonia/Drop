import { Hono } from "hono";
import type { Client } from "pg";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { loadGateway, loadSecrets } from "../lib/gateway-creds";
import { creditPaidLink, getPayLinkSettings } from "../lib/paymyride";
import { postToWallet, toMoney } from "../lib/wallet";
import { readBody, validationFailed } from "../lib/legacy";

export const payMyRideRoutes = new Hono<AppEnv>();

const KORAPAY = "https://api.korapay.com";
const OPEN = ["accepted", "arrived", "in_progress"];

const newToken = () => {
  const b = crypto.getRandomValues(new Uint8Array(18));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

/** Passenger: get (or reuse) the pay link for the trip in progress. */
payMyRideRoutes.post("/ride/pay-link", withDb, requireAuth, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const settings = await getPayLinkSettings(db);
  if (!settings.enabled) return c.json({ message: "PayMyRide is switched off for now." }, 403);
  const ride = (await db.query("select id, fare, payment_method from app.ride_requests where rider_id = $1 and status = any($2) order by id desc limit 1", [me.id, OPEN])).rows[0];
  if (!ride) return c.json({ message: "Once a driver accepts your ride, you can ask someone to pay for it." }, 409);
  if (ride.payment_method === "wallet") return c.json({ message: "This ride is already set to be paid from your wallet." }, 409);
  const amount = toMoney(ride.fare);
  if (!amount) return c.json({ message: "This ride has no fare to pay." }, 409);

  let link = (await db.query("select token from app.ride_pay_links where ride_request_id = $1 and status = 'pending' and expires_at > now() limit 1", [ride.id])).rows[0];
  if (!link) {
    link = (await db.query(
      "insert into app.ride_pay_links (token, ride_request_id, user_id, amount, expires_at) values ($1,$2,$3,$4, now() + ($5 || ' hours')::interval) returning token",
      [newToken(), ride.id, me.id, amount, String(settings.link_hours)])).rows[0];
  }
  const url = `${new URL(c.req.url).origin}/pay/${link.token}`;
  const first = String(me.first_name ?? me.display_name ?? "A friend").trim() || "A friend";
  return c.json({ url, token: link.token, amount: Number(amount), message: `${first} is asking you to pay for a DROP ride (₦${Number(amount).toLocaleString("en-NG")}). Pay securely here: ${url}` });
});

payMyRideRoutes.post("/ride/pay-link/stop", withDb, requireAuth, async (c) => {
  await c.get("db").query("update app.ride_pay_links set status = 'cancelled' where user_id = $1 and status = 'pending'", [c.get("user").id]);
  return c.json({ message: "Pay link cancelled" });
});

const linkRow = async (db: Client, token: string) =>
  (await db.query(
    `select l.id, l.user_id, l.ride_request_id, l.amount, l.status, l.expires_at, r.status as ride_status,
            r.pickup_address, r.dropoff_address, u.first_name as rider_name
       from app.ride_pay_links l join app.ride_requests r on r.id = l.ride_request_id join app.users u on u.id = l.user_id
      where l.token = $1`, [token])).rows[0];

const korapayKey = async (c: any): Promise<string | null> => {
  const gw = await loadGateway(c.get("db"), "korapay", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => null);
  return gw && gw.enabled && gw.creds.secret_key ? gw.creds.secret_key : null;
};

/** Public: what the person with the link sees. No phone numbers, no account details of the passenger beyond a first name. */
payMyRideRoutes.get("/pay/:token", withDb, async (c) => {
  const db = c.get("db");
  c.header("Cache-Control", "no-store");
  c.header("X-Robots-Tag", "noindex");
  const l = await linkRow(db, c.req.param("token"));
  if (!l) return c.json({ state: "gone" }, 404);
  const settings = await getPayLinkSettings(db);
  let state: string;
  if (l.status === "paid") state = "paid";
  else if (!settings.enabled || l.status === "cancelled" || new Date(l.expires_at).getTime() < Date.now() || !OPEN.includes(l.ride_status)) state = "closed";
  else state = "pending";

  const methods: { type: string; title: string; bank?: Record<string, string> }[] = [];
  if (state === "pending") {
    if (await korapayKey(c)) methods.push({ type: "korapay", title: "Card, bank or USSD" });
    const pf = await loadGateway(db, "pocketfi", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => null);
    if (pf?.enabled) {
      const acct = (await db.query("select bank_name, account_number, account_name from app.virtual_accounts where user_id = $1 and wallet_kind = 'rider' and provider = 'pocketfi' and status = 'active' limit 1", [l.user_id])).rows[0];
      if (acct) methods.push({ type: "pocketfi", title: "Bank transfer", bank: acct });
    }
  }
  return c.json({ state, amount: Number(l.amount), rider: l.rider_name, from: l.pickup_address, to: l.dropoff_address, methods });
});

/** Public: start a hosted Korapay payment for this link and return where to send the payer. */
payMyRideRoutes.post("/pay/:token/start", withDb, async (c) => {
  const db = c.get("db");
  const b = await readBody(c);
  const name = String(b.name ?? "").trim().slice(0, 80);
  const email = String(b.email ?? "").trim().toLowerCase().slice(0, 120);
  if (!name) return validationFailed(c, { name: ["Enter your name."] });
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return validationFailed(c, { email: ["Enter a valid email address."] });
  const l = await linkRow(db, c.req.param("token"));
  if (!l || l.status !== "pending" || new Date(l.expires_at).getTime() < Date.now() || !OPEN.includes(l.ride_status)) return c.json({ message: "This payment link is no longer active." }, 410);
  const key = await korapayKey(c);
  if (!key) return c.json({ message: "Card payment is not available right now." }, 503);

  const origin = new URL(c.req.url).origin;
  const reference = `pmr-${l.id}-${crypto.randomUUID().replace(/-/g, "").slice(0, 12)}`;
  await db.query("update app.ride_pay_links set payer_name = $2, payer_email = $3 where id = $1", [l.id, name, email]);
  let res: Response;
  try {
    res = await fetch(`${KORAPAY}/merchant/api/v1/charges/initialize`, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        reference, amount: Number(l.amount), currency: "NGN", narration: "DROP ride payment",
        redirect_url: `${origin}/pay/${c.req.param("token")}?done=1`, notification_url: `${origin}/api/webhooks/korapay`,
        customer: { name, email }, merchant_bears_cost: false,
      }),
    });
  } catch {
    return c.json({ message: "Could not reach the payment service. Please try again." }, 502);
  }
  const j = (await res.json().catch(() => null)) as { status?: boolean; data?: { checkout_url?: string } } | null;
  if (!res.ok || !j?.status || !j.data?.checkout_url) return c.json({ message: "The payment service did not accept this payment. Please try again." }, 502);
  return c.json({ checkout_url: j.data.checkout_url });
});

const hmacHex = async (secret: string, body: string) => {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return [...new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(body)))].map((x) => x.toString(16).padStart(2, "0")).join("");
};
const same = (a: string, b: string) => {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
};

/**
 * Korapay says a payment succeeded. We verify its signature, then ask Korapay directly whether that
 * reference really succeeded and for how much, and only then add the money. Once per reference.
 */
payMyRideRoutes.post("/webhooks/korapay", withDb, async (c) => {
  const db = c.get("db");
  const raw = await c.req.text();
  let p: any;
  try { p = JSON.parse(raw); } catch { return c.json({ message: "Bad payload" }, 400); }
  const sig = (c.req.header("x-korapay-signature") ?? "").toLowerCase();
  const secrets = await loadSecrets(db, "korapay", "secret_key", c.env.SETTINGS_ENCRYPTION_KEY).catch(() => []);
  let ok = false;
  const signed = JSON.stringify(p?.data ?? {});
  for (const s of secrets) if (sig && same(await hmacHex(s, signed), sig)) ok = true;
  if (!ok) return c.json({ message: "Invalid signature" }, 400);
  if (p?.event !== "charge.success") return c.json({ message: "ignored" });

  const reference = String(p?.data?.reference ?? "");
  const m = /^pmr-(\d+)-/.exec(reference);
  if (!m) return c.json({ message: "ignored" });

  const key = await korapayKey(c);
  if (!key) return c.json({ message: "Gateway not configured" }, 500);
  const v = (await fetch(`${KORAPAY}/merchant/api/v1/charges/${encodeURIComponent(reference)}`, { headers: { Authorization: `Bearer ${key}` } })
    .then((r) => r.json()).catch(() => null)) as { data?: { status?: string; amount?: number | string } } | null;
  if (v?.data?.status !== "success") return c.json({ message: "Payment not confirmed yet" }, 500); // Korapay retries
  const amount = toMoney(v.data.amount);
  if (!amount) return c.json({ message: "Bad amount" }, 400);

  try {
    await db.query("begin");
    const ev = await db.query(
      "insert into app.payment_events (provider, provider_reference, amount, fee, payload) values ('korapay', $1, $2, '0', $3::jsonb) on conflict (provider, provider_reference) do nothing returning id",
      [reference, amount, JSON.stringify(p)]);
    if (!ev.rowCount) { await db.query("commit"); return c.json({ message: "success", duplicate: true }); }
    const link = (await db.query("select id, user_id, ride_request_id, amount, payer_name from app.ride_pay_links where id = $1", [m[1]])).rows[0];
    if (!link) {
      await db.query("update app.payment_events set status = 'flagged', note = 'No pay link for this reference' where id = $1", [ev.rows[0].id]);
      await db.query("commit");
      return c.json({ message: "success", flagged: true });
    }
    if (Number(amount) >= Number(link.amount)) {
      await creditPaidLink(db, link, { amount, gateway: "korapay", reference, payerName: link.payer_name });
    } else {
      // Paid less than the fare: the money is still the passenger's, but the ride is not covered yet.
      await postToWallet(db, { userId: Number(link.user_id), direction: "credit", amount, kind: "paymyride", wallet: "rider", idempotencyKey: `paymyride:korapay:${reference}`, description: "Part payment for a ride" });
      await db.query("update app.payment_events set note = 'Paid less than the fare' where id = $1", [ev.rows[0].id]);
    }
    await db.query("update app.payment_events set status = 'credited', user_id = $2 where id = $1", [ev.rows[0].id, link.user_id]);
    await db.query("commit");
    return c.json({ message: "success" });
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    console.error("korapay webhook failed", (e as Error).message);
    return c.json({ message: "Temporary error, please retry" }, 500);
  }
});

/** The pay page. Plain HTML; it reads /api/pay/:token and posts to /api/pay/:token/start. */
payMyRideRoutes.get("/pay/:token/page", (c) => c.redirect(`/pay/${c.req.param("token")}`));
export const payPage = new Hono<AppEnv>();
payPage.get("/pay/:token", (c) => {
  c.header("Cache-Control", "no-store");
  c.header("X-Robots-Tag", "noindex");
  return c.html(PAGE);
});

const PAGE = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>Pay for a DROP ride</title>
<style>
:root{--bg:#fff;--fg:#14110f;--mut:#6b6560;--card:#fff8f4;--line:#00000022;--pri:#e8461a}
@media(prefers-color-scheme:dark){:root{--bg:#000;--fg:#fff;--mut:#b9b2ac;--card:#1a1715;--line:#ffffff2a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.45 system-ui,sans-serif}
main{max-width:440px;margin:0 auto;padding:24px 16px 48px}
.logo{font-weight:900;font-size:26px;letter-spacing:.5px;color:var(--pri);margin-bottom:18px}
.card{background:var(--card);border-radius:20px;padding:20px;margin-bottom:16px}
h1{font-size:22px;margin:0 0 6px}.m{color:var(--mut);font-size:14px;margin:3px 0}.amt{font-size:36px;font-weight:800;margin:10px 0}
label{display:block;font-size:13px;color:var(--mut);margin:12px 0 4px}
input{width:100%;padding:14px;border-radius:12px;border:1px solid var(--line);background:var(--bg);color:var(--fg);font-size:16px}
button{width:100%;margin-top:16px;padding:16px;border:0;border-radius:14px;background:var(--pri);color:#fff;font-size:17px;font-weight:700}
button[disabled]{opacity:.5}.sec{background:transparent;color:var(--fg);border:1px solid var(--line);margin-top:8px;padding:10px;font-size:14px}
.row{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-top:1px solid var(--line)}.row b{word-break:break-all}
.err{color:#d33;margin-top:10px;font-size:14px}.ok{color:#1fa463}
</style></head><body><main>
<div class="logo">DROP</div>
<div id="root"><div class="card"><div class="m">Loading…</div></div></div>
</main>
<script>
var token=location.pathname.split('/').pop();
function $(i){return document.getElementById(i)}
function esc(s){var d=document.createElement('div');d.textContent=s==null?'':String(s);return d.innerHTML}
function naira(n){return '\\u20A6'+Number(n).toLocaleString('en-NG')}
function render(j){
  var r=$('root');
  if(j.state==='gone'){r.innerHTML='<div class="card"><h1>Link not found</h1><p class="m">Check that you copied the whole link.</p></div>';return}
  if(j.state==='paid'){r.innerHTML='<div class="card"><h1 class="ok">Payment received \\u2713</h1><p class="m">Thank you. '+esc(j.rider||'The passenger')+"'s ride is paid for.</p></div>";return}
  if(j.state==='closed'){r.innerHTML='<div class="card"><h1>This link is no longer active</h1><p class="m">The ride ended or the link expired. If you already paid, the money went to the passenger\\u2019s DROP wallet.</p></div>';return}
  var h='<div class="card"><h1>Pay for '+esc(j.rider||'a friend')+"'s ride</h1>";
  if(j.from||j.to)h+='<div class="m">'+esc(j.from||'')+' \\u2192 '+esc(j.to||'')+'</div>';
  h+='<div class="amt">'+naira(j.amount)+'</div><div class="m">The money goes to '+esc(j.rider||'their')+"\\u2019s DROP wallet and pays for this ride. No account needed.</div></div>";
  var hasK=false,bank=null;
  j.methods.forEach(function(m){if(m.type==='korapay')hasK=true;if(m.type==='pocketfi')bank=m.bank});
  if(hasK){h+='<div class="card"><label>Your name</label><input id="nm" autocomplete="name"><label>Your email (for the receipt)</label><input id="em" type="email" autocomplete="email"><button id="go">Pay '+naira(j.amount)+'</button><div id="er" class="err"></div></div>'}
  if(bank){h+='<div class="card"><h1 style="font-size:18px">Or pay by bank transfer</h1><div class="m">Transfer exactly '+naira(j.amount)+' to:</div><div class="row"><span>Bank</span><b>'+esc(bank.bank_name)+'</b></div><div class="row"><span>Account number</span><b id="an">'+esc(bank.account_number)+'</b></div><div class="row"><span>Account name</span><b>'+esc(bank.account_name)+'</b></div><button class="sec" id="cp">Copy account number</button><div class="m">This page updates by itself when the transfer arrives.</div></div>'}
  if(!hasK&&!bank)h+='<div class="card"><p class="m">Payment is not available right now. Please ask '+esc(j.rider||'them')+' to try again later.</p></div>';
  r.innerHTML=h;
  if($('go'))$('go').onclick=function(){
    var b=$('go');b.disabled=true;$('er').textContent='';
    fetch('/api/pay/'+token+'/start',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:$('nm').value,email:$('em').value})})
    .then(function(x){return x.json().then(function(d){return{ok:x.ok,d:d}})}).then(function(x){
      if(x.ok&&x.d.checkout_url){location.href=x.d.checkout_url;return}
      b.disabled=false;var e=x.d.errors?Object.values(x.d.errors)[0]:null;$('er').textContent=(e&&e[0])||x.d.message||'Something went wrong.'
    }).catch(function(){b.disabled=false;$('er').textContent='No connection. Try again.'})};
  if($('cp'))$('cp').onclick=function(){try{navigator.clipboard.writeText($('an').textContent);$('cp').textContent='Copied \\u2713'}catch(e){}};
}
var shown=null;
function poll(){fetch('/api/pay/'+token,{cache:'no-store'}).then(function(r){return r.json()}).then(function(j){
  var sig=j.state+'|'+JSON.stringify(j.methods||[]);
  if(sig!==shown){var typing=document.activeElement&&document.activeElement.tagName==='INPUT';if(!typing||j.state!=='pending'){render(j);shown=sig}}
  if(j.state==='pending'||location.search.indexOf('done=1')>=0&&j.state!=='paid')setTimeout(poll,5000)
}).catch(function(){setTimeout(poll,8000)})}
poll();
</script></body></html>`;
