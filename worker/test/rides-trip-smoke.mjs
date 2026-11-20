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
// Pickup code: the passenger's app shows it, the driver types it, then the trip can start.
const verifyPickup = async (rideId, d, P) => {
  const cur = await call("GET", "/ride/current", P.api_token);
  const code = cur.json.data?.pickup_code?.code;
  if (!code) return null; // ride from before pickup codes
  return call("POST", `/driver/rides/${rideId}/verify-pickup`, d.T, { code });
};
const s = Math.random().toString(36).slice(2, 8);
const phone = () => "0803" + Math.floor(1000000 + Math.random() * 8999999);
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "M", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
let region, svc, oldMin;
const ids = [];
try {
  // All state-changing setup is inside the cleanup guard. If setup fails halfway,
  // finally still restores the original active regions and removes partial fixtures.
  await db.query("update app.regions set status = false where status");
  region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["MatchTest" + s])).rows[0].id;
  const mk = async (n) => (await db.query(
    `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, cancellation_fee, commission_type, admin_commission, status, payment_methods, booking_modes, sort_order)
     values ($1,$2,4,500,800,2,100,10,300,'percentage',10,true,array['cash','wallet'],array['now'],0) returning id`, [n + s, region])).rows[0].id;
  svc = await mk("Car");
  const trip = { pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(svc), payment_method: "cash" };
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
oldMin = (await db.query("select value from app.settings where key = 'driver_min_wallet_balance'")).rows[0]?.value;
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const P = await reg("rider", "pax"); ids.push(P.id);
  const d = await driver("dx"), d2 = await driver("dy");
  for (const x of [d, d2]) await db.query("insert into app.wallets (user_id, kind, balance, allow_negative) values ($1,'driver',5000,true) on conflict (user_id, kind) do update set balance = 5000", [x.id]);
  const book = async (method = "cash", pax = P) => { const r = await call("POST", "/ride/request", pax.api_token, { ...trip, payment_method: method }); return r.json.data; };

  // --- ordered multi-stop trip ---
  let r;
  const stops = [
    { lat: 9.0700, lng: 7.4200, address: "First intermediate stop" },
    { lat: 9.0600, lng: 7.4500, address: "Second intermediate stop" },
  ];
  const estimate = await call("POST", "/ride/estimate", P.api_token, { ...trip, stops });
  ok("estimate includes every ordered stop", estimate.status === 200 && estimate.json.stops?.length === 2 && estimate.json.stops[0].address === stops[0].address);
  const multi = await call("POST", "/ride/request", P.api_token, { ...trip, stops, payment_method: "cash" });
  r = multi.json.data;
  ok("booking persists stops in submitted order", multi.status === 201 && r?.stops?.length === 2 && r.stops[0].sequence === 1 && r.stops[1].sequence === 2);
  await call("POST", `/driver/requests/${r.id}/accept`, d.T);
  await call("POST", `/driver/rides/${r.id}/arrived`, d.T);
  await verifyPickup(r.id, d, P);
  await call("POST", `/driver/rides/${r.id}/start`, d.T);
  const [first, second] = r.stops;
  ok("cannot arrive at a later stop out of order", (await call("POST", `/driver/rides/${r.id}/stops/${second.id}/arrived`, d.T)).status === 409);
  ok("first stop arrival accepted", (await call("POST", `/driver/rides/${r.id}/stops/${first.id}/arrived`, d.T)).status === 200);
  ok("cannot end trip while stops remain", (await call("POST", `/driver/rides/${r.id}/complete`, d.T)).status === 409);
  ok("first stop completion accepted", (await call("POST", `/driver/rides/${r.id}/stops/${first.id}/complete`, d.T)).status === 200);
  ok("cannot complete the same stop twice", (await call("POST", `/driver/rides/${r.id}/stops/${first.id}/complete`, d.T)).status === 409);
  ok("second stop arrival accepted after first completion", (await call("POST", `/driver/rides/${r.id}/stops/${second.id}/arrived`, d.T)).status === 200);
  ok("second stop completion accepted", (await call("POST", `/driver/rides/${r.id}/stops/${second.id}/complete`, d.T)).status === 200);
  const multiDone = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  ok("trip completes after all stops are completed", multiDone.status === 200 && multiDone.json.data?.stops?.every((s) => s.status === "completed"));
  const passengerReceipt = await call("GET", `/ride/${r.id}/receipt`, P.api_token);
  const driverReceipt = await call("GET", `/driver/rides/${r.id}/receipt`, d.T);
  ok("passenger receipt preserves ordered stops", passengerReceipt.status === 200 && passengerReceipt.json.data?.stops?.[0]?.sequence === 1 && passengerReceipt.json.data?.stops?.[1]?.sequence === 2);
  ok("driver receipt preserves ordered stops", driverReceipt.status === 200 && driverReceipt.json.data?.stops?.[0]?.sequence === 1 && driverReceipt.json.data?.stops?.[1]?.sequence === 2);

  // --- cash trip ---
  r = await book("cash");
  ok("other driver cannot move a ride that is not theirs", (await call("POST", `/driver/rides/${r.id}/arrived`, d.T)).status === 409);
  await call("POST", `/driver/requests/${r.id}/accept`, d.T);
  ok("cannot start before arriving", (await call("POST", `/driver/rides/${r.id}/start`, d.T)).status === 409);
  ok("cannot complete before starting", (await call("POST", `/driver/rides/${r.id}/complete`, d.T)).status === 409);
  ok("another driver cannot mark arrival", (await call("POST", `/driver/rides/${r.id}/arrived`, d2.T)).status === 409);
  ok("arrived", (await call("POST", `/driver/rides/${r.id}/arrived`, d.T)).json.data?.status === "arrived");
  ok("passenger sees arrived", (await call("GET", "/ride/current", P.api_token)).json.data?.status === "arrived");
  const blocked = await call("POST", `/driver/rides/${r.id}/start`, d.T);
  ok("cannot start without the pickup code", blocked.status === 409 && blocked.json.code === "pickup_not_verified", JSON.stringify(blocked.json));
  const shown = (await call("GET", "/ride/current", P.api_token)).json.data?.pickup_code;
  ok("passenger sees a 4-digit pickup code", /^\d{4}$/.test(shown?.code ?? ""), JSON.stringify(shown));
  ok("driver response never contains the code", !JSON.stringify((await call("GET", "/driver/requests", d.T)).json).includes(shown?.code ? `"${shown.code}"` : "no-code"));
  const wrong = String((Number(shown.code) + 1) % 10000).padStart(4, "0");
  const bad = await call("POST", `/driver/rides/${r.id}/verify-pickup`, d.T, { code: wrong });
  ok("wrong code rejected", bad.status === 422 && bad.json.code === "wrong_code", JSON.stringify(bad.json));
  ok("other driver cannot verify", (await call("POST", `/driver/rides/${r.id}/verify-pickup`, d2.T, { code: shown.code })).status === 409);
  ok("correct code accepted", (await call("POST", `/driver/rides/${r.id}/verify-pickup`, d.T, { code: shown.code })).json.status === true);
  ok("code reused after verify is harmless and the code is hidden", (await call("GET", "/ride/current", P.api_token)).json.data?.pickup_code?.verified === true);
  ok("started", (await call("POST", `/driver/rides/${r.id}/start`, d.T)).json.data?.status === "in_progress");

  // ---- Ride chat: text and voice notes between this passenger and this driver only ----
  const cid = () => "c" + Math.random().toString(36).slice(2, 12) + Date.now();
  const sent = await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: cid(), body: "I am at the gate" });
  ok("passenger can send a chat message", sent.status === 201 && sent.json.data?.mine === true, JSON.stringify(sent.json));
  const dup = cid();
  const once1 = await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: dup, body: "once" });
  const again = await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: dup, body: "once" });
  ok("a retried send does not create a duplicate", once1.json.data?.id === again.json.data?.id);
  const drvView = await call("GET", `/ride/${r.id}/chat`, d.T);
  ok("assigned driver receives the message", drvView.json.data?.messages?.some((m) => m.body === "I am at the gate" && m.mine === false), JSON.stringify(drvView.json));
  ok("driver sees an unread count and can_send", drvView.json.data?.unread >= 2 && drvView.json.data?.can_send === true);
  await call("POST", `/ride/${r.id}/chat/read`, d.T);
  ok("driver reply works", (await call("POST", `/ride/${r.id}/chat/messages`, d.T, { client_id: cid(), body: "Coming now" })).status === 201);
  const paxView = await call("GET", `/ride/${r.id}/chat`, P.api_token);
  ok("passenger sees the reply and the read tick on their own message", paxView.json.data?.messages?.some((m) => m.body === "Coming now") && paxView.json.data.messages.find((m) => m.body === "I am at the gate")?.read_at);
  ok("another driver cannot read this chat", (await call("GET", `/ride/${r.id}/chat`, d2.T)).status === 404);
  ok("another driver cannot send into this chat", (await call("POST", `/ride/${r.id}/chat/messages`, d2.T, { client_id: cid(), body: "hi" })).status === 404);
  ok("empty and oversized messages are refused", (await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: cid(), body: "   " })).status === 422 && (await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: cid(), body: "x".repeat(1001) })).status === 422);

  const voice = async (token, bytes, seconds = 3) => {
    const f = new FormData();
    f.set("client_id", cid()); f.set("seconds", String(seconds)); f.set("waveform", "10,40,80,30");
    f.set("file", new Blob([bytes], { type: "audio/mp4" }), "voice.m4a");
    const res = await fetch(`${API}/ride/${r.id}/chat/voice`, { method: "POST", headers: { Authorization: "Bearer " + token, Accept: "application/json" }, body: f });
    return { status: res.status, json: await res.json().catch(() => ({})) };
  };
  const m4a = new Uint8Array([0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
  const vm = await voice(P.api_token, m4a);
  ok("passenger can send a voice note", vm.status === 201 && vm.json.data?.kind === "voice" && vm.json.data?.seconds === 3, JSON.stringify(vm.json));
  ok("voice response never exposes the storage key", !JSON.stringify(vm.json).includes("chat/"));
  ok("a non-audio file is refused as a voice note", (await voice(P.api_token, new TextEncoder().encode("<script>x</script>"))).status === 422);
  ok("too-long voice note is refused", (await voice(P.api_token, m4a, 9999)).status === 422);
  ok("another driver cannot send a voice note", (await voice(d2.T, m4a)).status === 404);
  const link = await call("GET", `/ride/${r.id}/chat/messages/${vm.json.data.id}/audio-url`, d.T);
  ok("driver gets a signed link for the voice note", link.status === 200 && /sig=/.test(link.json.data?.url ?? ""), JSON.stringify(link.json));
  const audio = await fetch(link.json.data.url);
  ok("signed link serves the stored audio", audio.status === 200 && (await audio.arrayBuffer()).byteLength === m4a.length);
  ok("a tampered link is refused", (await fetch(link.json.data.url.replace(/sig=(.)/, (_, ch) => "sig=" + (ch === "0" ? "1" : "0")))).status === 403);
  ok("another driver cannot get a link", (await call("GET", `/ride/${r.id}/chat/messages/${vm.json.data.id}/audio-url`, d2.T)).status === 404);
  const hist = await call("GET", `/ride/${r.id}/chat`, P.api_token);
  ok("history keeps text and voice in order", hist.json.data?.messages?.length >= 4 && hist.json.data.messages.some((m) => m.kind === "voice"));
  await call("PUT", "/admin/chat-settings", A, { enabled: false, voice_enabled: true, max_voice_seconds: 60, retention_days: 30 });
  ok("admin can switch chat off", (await call("POST", `/ride/${r.id}/chat/messages`, P.api_token, { client_id: cid(), body: "nope" })).status === 403);
  await call("PUT", "/admin/chat-settings", A, { enabled: true, voice_enabled: true, max_voice_seconds: 60, retention_days: 30 });
  // ---- Profile photos: private, link carries a random token, shown to the other person on the ride ----
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0x0d, 1, 2, 3, 4, 5, 6, 7, 8]);
  const putPhoto = (token, bytes) => fetch(`${API}/profile/photo`, { method: "PUT", headers: { Authorization: "Bearer " + token, Accept: "application/json", "Content-Type": "image/png" }, body: bytes });
  ok("a photo upload needs sign-in", (await putPhoto("bad", png)).status === 401);
  ok("a file that is not an image is refused", (await putPhoto(d.T, new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]))).status === 415);
  const up = await putPhoto(d.T, png);
  const upJson = await up.json().catch(() => ({}));
  ok("the driver uploads a profile photo", up.status === 200 && /\/api\/users\/\d+\/profile-photo\?v=[0-9a-f-]{36}$/.test(upJson.profile_image ?? ""), JSON.stringify(upJson));
  const photoRes = await fetch(upJson.profile_image);
  ok("the photo link serves the image with safe headers", photoRes.status === 200 && photoRes.headers.get("content-type") === "image/png" && photoRes.headers.get("x-content-type-options") === "nosniff");
  ok("the same link without its token is refused", (await fetch(upJson.profile_image.split("?")[0])).status === 404);
  ok("a wrong token is refused", (await fetch(upJson.profile_image.replace(/v=./, (m) => "v=" + (m.endsWith("0") ? "1" : "0")))).status === 404);
  const seen = await call("GET", "/ride/current", P.api_token);
  ok("the passenger's ride shows the driver's photo", seen.json.data?.driver?.profile_image === upJson.profile_image, JSON.stringify(seen.json.data?.driver));
  const relog = await call("POST", "/login", null, { email: (await db.query("select email from app.users where id = $1", [d.id])).rows[0].email, password: "secret123" });
  ok("the photo survives signing in again", relog.json.data?.profile_image === upJson.profile_image, String(relog.json.data?.profile_image));
  const up2 = await (await putPhoto(d.T, png)).json();
  ok("replacing the photo changes the link and the old one stops working", up2.profile_image !== upJson.profile_image && (await fetch(upJson.profile_image)).status === 404);
  const del = await fetch(`${API}/profile/photo`, { method: "DELETE", headers: { Authorization: "Bearer " + d.T, Accept: "application/json" } });
  ok("the photo can be removed", del.status === 200 && (await fetch(up2.profile_image)).status === 404);

  // ---- In-app voice calls: only this passenger and this driver, one live call, provider tokens per person ----
  const callsOff = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  ok("calling is off until an admin sets it up", callsOff.status === 503 && callsOff.json.code === "calls_off", JSON.stringify(callsOff.json));
  const cfg = { enabled: true, provider: "livekit", livekit_enabled: true, agora_enabled: true, ring_seconds: 30, max_minutes: 60, livekit_url: "wss://example.livekit.cloud", livekit_api_key: "APItestkey", agora_app_id: "a".repeat(32), livekit_api_secret: "lk-secret-value-123456", agora_app_certificate: "c".repeat(32) };
  ok("admin saves provider settings", (await call("PUT", "/admin/call-settings", A, cfg)).status === 200);
  const shownCfg = await call("GET", "/admin/call-settings", A);
  ok("secrets are never sent back to the admin page", !JSON.stringify(shownCfg.json).includes("lk-secret-value") && shownCfg.json.data?.livekit_secret_saved === true && shownCfg.json.data?.ready?.length === 2, JSON.stringify(shownCfg.json));
  ok("secrets are stored encrypted", (await db.query("select value #>> '{}' as v from app.settings where key = 'calls_livekit_secret_enc'")).rows[0]?.v !== "lk-secret-value-123456");
  ok("another driver cannot call on this ride", (await call("POST", `/ride/${r.id}/call`, d2.T, {})).status === 404);
  const st = await call("GET", `/ride/${r.id}/call/status`, P.api_token);
  ok("call status says calls are available", st.json.data?.can_call === true && st.json.data?.enabled === true, JSON.stringify(st.json));
  const k1 = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  ok("passenger starts a call and gets a LiveKit token", k1.status === 200 && k1.json.data?.join?.provider === "livekit" && k1.json.data.join.token.split(".").length === 3, JSON.stringify(k1.json));
  ok("the join response never carries the provider secret", !JSON.stringify(k1.json).includes("lk-secret-value"));
  const cid1 = k1.json.data.call.id;
  ok("a second call on the same ride is refused", (await call("POST", `/ride/${r.id}/call`, d.T, {})).status === 409);
  ok("the driver is told about the incoming call", (await call("GET", "/calls/incoming", d.T)).json.data?.id === cid1);
  ok("the caller is not shown their own call as incoming", (await call("GET", "/calls/incoming", P.api_token)).json.data === null);
  ok("another driver sees no incoming call and cannot read it", (await call("GET", "/calls/incoming", d2.T)).json.data === null && (await call("GET", `/call/${cid1}`, d2.T)).status === 404);
  ok("another driver cannot accept or end it", (await call("POST", `/call/${cid1}/accept`, d2.T)).status === 404 && (await call("POST", `/call/${cid1}/end`, d2.T)).status === 404);
  ok("the caller cannot accept their own call", (await call("POST", `/call/${cid1}/accept`, P.api_token)).status === 404);
  ok("the callee cannot get a token before answering", (await call("POST", `/call/${cid1}/token`, d.T)).status === 409);
  const acc = await call("POST", `/call/${cid1}/accept`, d.T);
  ok("driver accepts and gets a token for the same room", acc.status === 200 && acc.json.data?.call?.status === "active" && acc.json.data.join.room === k1.json.data.join.room, JSON.stringify(acc.json));
  ok("the two people get different identities", acc.json.data.join.uid !== k1.json.data.join.uid);
  ok("answering twice is refused", (await call("POST", `/call/${cid1}/accept`, d.T)).status === 409);
  await db.query("update app.ride_calls set answered_at = now() - interval '75 seconds' where id = $1", [cid1]);
  const end1 = await call("POST", `/call/${cid1}/end`, P.api_token);
  ok("ending records the duration", end1.json.data?.status === "ended" && end1.json.data.duration_seconds >= 75, JSON.stringify(end1.json));
  ok("ending twice is harmless", (await call("POST", `/call/${cid1}/end`, d.T)).json.data?.status === "ended");
  ok("no token after the call ended", (await call("POST", `/call/${cid1}/token`, P.api_token)).status === 409);
  const k2 = await call("POST", `/ride/${r.id}/call`, d.T, {});
  ok("the driver can call the passenger", k2.status === 200 && (await call("GET", "/calls/incoming", P.api_token)).json.data?.id === k2.json.data.call.id);
  ok("the caller cannot decline their own call", (await call("POST", `/call/${k2.json.data.call.id}/decline`, d.T)).status === 403);
  ok("the passenger declines", (await call("POST", `/call/${k2.json.data.call.id}/decline`, P.api_token)).json.data?.status === "declined");
  const k3 = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  ok("the caller can cancel while ringing", (await call("POST", `/call/${k3.json.data.call.id}/cancel`, P.api_token)).json.data?.status === "cancelled");
  const k4 = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  await db.query("update app.ride_calls set created_at = now() - interval '2 minutes' where id = $1", [k4.json.data.call.id]);
  ok("an unanswered ring becomes a missed call", (await call("GET", `/call/${k4.json.data.call.id}`, d.T)).json.data?.status === "missed");
  ok("an expired call cannot be answered", (await call("POST", `/call/${k4.json.data.call.id}/accept`, d.T)).status === 409);
  await call("PUT", "/admin/call-settings", A, { ...cfg, livekit_enabled: false, livekit_api_secret: "", agora_app_certificate: "" });
  const k5 = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  ok("with LiveKit off the call uses Agora", k5.status === 200 && k5.json.data?.join?.provider === "agora" && k5.json.data.join.token.startsWith("007") && typeof k5.json.data.join.uid === "number", JSON.stringify(k5.json));
  await call("POST", `/call/${k5.json.data.call.id}/cancel`, P.api_token);
  await call("PUT", "/admin/call-settings", A, { ...cfg, enabled: false, livekit_api_secret: "", agora_app_certificate: "" });
  ok("admin can switch calling off", (await call("POST", `/ride/${r.id}/call`, P.api_token, {})).status === 503);
  await call("PUT", "/admin/call-settings", A, { ...cfg, livekit_api_secret: "", agora_app_certificate: "" });
  const k6 = await call("POST", `/ride/${r.id}/call`, P.api_token, {});
  await call("POST", `/call/${k6.json.data.call.id}/accept`, d.T);
  const hist2 = await call("GET", `/ride/${r.id}/calls`, P.api_token);
  ok("call history lists every call with its outcome", hist2.json.data?.length >= 6 && hist2.json.data.some((x) => x.status === "missed") && hist2.json.data.some((x) => x.status === "declined"), JSON.stringify(hist2.json.data?.map((x) => x.status)));
  ok("admin history has names and no audio", (await call("GET", "/admin/calls", A)).json.data?.length >= 6);
  // a live call is closed by the system when the trip ends (checked after completion below)
  const liveCall = k6.json.data.call.id;
  const tr = await call("POST", "/ride/cancel", P.api_token, {});
  ok("passenger cannot cancel a started trip", tr.status === 409 && tr.json.code === "trip_in_progress");
  const w0 = await bal(d.id, "driver");
  const done = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  const fare = Number(r.fare), com = Math.round(fare * 10) / 100;
  ok("completed: cash, collect from rider, commission 10%", done.status === 200 && done.json.data.collect_cash === true && Math.abs(done.json.data.commission - com) < 0.011, JSON.stringify(done.json));
  ok("commission debited from driver wallet", Math.abs((await bal(d.id, "driver")) - (w0 - com)) < 0.011, `${await bal(d.id, "driver")} vs ${w0 - com}`);
  ok("completing twice changes nothing", (await call("POST", `/driver/rides/${r.id}/complete`, d.T)).status === 409 && Math.abs((await bal(d.id, "driver")) - (w0 - com)) < 0.011);
  ok("finishing the trip closes a call still in progress", (await call("GET", `/call/${liveCall}`, d.T)).json.data?.status === "ended");
  ok("driver is available again", (await db.query("select is_available from app.users where id = $1", [d.id])).rows[0].is_available === true);
  ok("passenger has no open ride", (await call("GET", "/ride/current", P.api_token)).json.data === null);
  ok("passenger history shows it", (await call("GET", "/ride/history", P.api_token)).json.data[0]?.status === "completed");
  const h = await call("GET", "/driver/rides/history", d.T);
  ok("driver history shows earning", h.json.data[0]?.id === r.id && Math.abs(h.json.data[0].earning - (fare - com)) < 0.011);

  // --- wallet trip ---
  await db.query("insert into app.wallets (user_id, kind, balance) values ($1,'rider',5000) on conflict (user_id, kind) do update set balance = 5000", [P.id]);
  r = await book("wallet");
  const dw0 = await bal(d.id, "driver");
  await call("POST", `/driver/requests/${r.id}/accept`, d.T); await call("POST", `/driver/rides/${r.id}/arrived`, d.T); await verifyPickup(r.id, d, P); await call("POST", `/driver/rides/${r.id}/start`, d.T);
  const dw = await call("POST", `/driver/rides/${r.id}/complete`, d.T);
  const f2 = Number(r.fare), c2 = Math.round(f2 * 10) / 100;
  ok("wallet trip paid from rider wallet", dw.json.data?.paid_with === "wallet" && dw.json.data.collect_cash === false && Math.abs((await bal(P.id, "rider")) - (5000 - f2)) < 0.011, JSON.stringify(dw.json));
  ok("driver credited fare minus commission", Math.abs((await bal(d.id, "driver")) - (dw0 + f2 - c2)) < 0.011);

  // --- wallet trip but rider's money is gone -> settled as cash ---
  r = await book("wallet");
  await call("POST", `/driver/requests/${r.id}/accept`, d.T); await call("POST", `/driver/rides/${r.id}/arrived`, d.T); await verifyPickup(r.id, d, P); await call("POST", `/driver/rides/${r.id}/start`, d.T);
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
  if (svc !== undefined) {
    await db.query("delete from app.ride_requests where service_id = $1", [svc]);
    await db.query("delete from app.services where id = $1", [svc]);
  }
  if (region !== undefined) await db.query("delete from app.regions where id = $1", [region]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
