// Optional fare bidding, end to end against a disposable DB. Local/test DB only, never production.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/rides-bidding-smoke.mjs
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
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "B", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
const oldBid = (await db.query("select value from app.settings where key = 'bidding'")).rows[0]?.value;
let region, svc, oldMin;
const ids = [];
const settings = { enabled: true, min_percent: 70, max_percent: 150, absolute_min: 0, absolute_max: 0, max_rounds: 3, bid_expiry_seconds: 180, offer_expiry_seconds: 90, max_active_bids: 1, max_bids_per_hour: 10, max_cancelled_per_day: 6, overrides: [] };
try {
  await db.query("update app.regions set status = false where status");
  region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["BidTest" + s])).rows[0].id;
  svc = (await db.query(
    `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, cancellation_fee, commission_type, admin_commission, status, payment_methods, booking_modes, sort_order)
     values ($1,$2,4,500,800,2,100,10,300,'percentage',10,true,array['cash','wallet'],array['now'],0) returning id`, ["Car" + s, region])).rows[0].id;
  const trip = { pickup: { lat: 9.0765, lng: 7.3986, address: "Wuse" }, dropoff: { lat: 9.0579, lng: 7.4951, address: "Gwarinpa" }, service_id: Number(svc), payment_method: "cash" };
  const stops = [{ lat: 9.0700, lng: 7.4200, address: "First stop" }, { lat: 9.0600, lng: 7.4500, address: "Second stop" }];
  const driver = async (tag, bids) => {
    const D = await reg("driver", tag); ids.push(D.id);
    await db.query("update app.driver_profiles set status = 'approved', service_id = $2 where user_id = $1", [D.id, svc]);
    await db.query("update app.users set status = 'active' where id = $1", [D.id]);
    await db.query("insert into app.wallets (user_id, kind, balance, allow_negative) values ($1,'driver',5000,true) on conflict (user_id, kind) do update set balance = 5000", [D.id]);
    const T = (await call("POST", "/login", null, { email: `${tag}${s}@x.com`, password: "secret123" })).json.data.api_token;
    await call("POST", "/mode", T, { mode: "driver" });
    await call("POST", "/driver/online", T, { online: true, latitude: 9.08, longitude: 7.4 });
    if (bids) await call("PUT", "/driver/preferences", T, { accepts_bids: true });
    return { id: D.id, T };
  };
  const bal = async (id, kind) => Number((await db.query("select balance from app.wallets where user_id = $1 and kind = $2", [id, kind])).rows[0]?.balance ?? 0);
  oldMin = (await db.query("select value from app.settings where key = 'driver_min_wallet_balance'")).rows[0]?.value;
  await call("PUT", "/admin/wallet-settings", A, { driver_min_wallet_balance: 0 });
  const P = await reg("rider", "bp"), P2 = await reg("rider", "bq"); ids.push(P.id, P2.id);
  const d1 = await driver("bd1", true), d2 = await driver("bd2", true), d3 = await driver("bd3", false);
  const setBid = (patch) => call("PUT", "/admin/bid-settings", A, { ...settings, ...patch });
  const verifyPickup = async (rideId, d, pax) => {
    const code = (await call("GET", "/ride/current", pax.api_token)).json.data?.pickup_code?.code;
    return code ? call("POST", `/driver/rides/${rideId}/verify-pickup`, d.T, { code }) : null;
  };

  // --- OFF by default: standard booking is untouched ---
  await setBid({ enabled: false });
  let r = await call("POST", "/ride/bids", P.api_token, { ...trip, offer: 1000 });
  ok("bidding is refused while the admin switch is off", r.status === 403 && r.json.code === "bidding_disabled", JSON.stringify(r.json));
  const std0 = await call("POST", "/ride/request", P.api_token, trip);
  ok("standard booking works with bidding off", std0.status === 201 && std0.json.data?.status === "searching", JSON.stringify(std0.json));
  await call("POST", "/ride/cancel", P.api_token, {});

  // --- ON: ranges come from the server ---
  ok("only an admin can read or change bid settings", (await call("GET", "/admin/bid-settings", P.api_token)).status === 403 && (await call("PUT", "/admin/bid-settings", d1.T, settings)).status === 403);
  ok("settings are validated on save", (await call("PUT", "/admin/bid-settings", A, { ...settings, min_percent: 60, absolute_min: 9000, absolute_max: 100 })).status === 422);
  ok("admin turns bidding on", (await setBid({})).status === 200);
  const est = await call("POST", "/ride/estimate", P.api_token, { ...trip, stops });
  const range = est.json.bidding?.per_type?.[String(svc)];
  ok("estimate carries the bidding range per ride type", est.json.bidding?.enabled === true && range?.enabled && range.min > 0 && range.max > range.min, JSON.stringify(est.json.bidding));
  const fare = est.json.ride_types.find((t) => t.id === Number(svc)).fare;
  ok("range follows the 70%-150% rule", range.min === Math.ceil(fare * 0.7) && range.max === Math.floor(fare * 1.5), `${fare} ${JSON.stringify(range)}`);
  const mid = Math.round((range.min + range.max) / 2);

  // --- driver preferences are independent and persisted ---
  let pref = await call("GET", "/driver/preferences", d3.T);
  ok("defaults: standard ON, bids OFF", pref.json.data?.accepts_standard === true && pref.json.data?.accepts_bids === false, JSON.stringify(pref.json));
  pref = await call("PUT", "/driver/preferences", d1.T, { accepts_standard: true, accepts_bids: true });
  ok("a driver can turn bids on and it is saved", pref.json.data?.accepts_bids === true && (await db.query("select accepts_bids from app.driver_profiles where user_id = $1", [d1.id])).rows[0].accepts_bids === true);
  ok("preferences ride along with the driver status", (await call("GET", "/driver/status", d1.T)).json.preferences?.accepts_bids === true);
  ok("riders cannot change driver preferences", (await call("PUT", "/driver/preferences", P.api_token, { accepts_bids: true })).status >= 400);

  // --- creating a bid: server-side validation ---
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: 1 });
  ok("an offer below the range is rejected with the range", r.status === 422 && r.json.code === "below_min" && r.json.limits?.min === range.min, JSON.stringify(r.json));
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: fare * 10 });
  ok("an offer above the range is rejected", r.status === 422 && r.json.code === "above_max");
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: "abc" });
  ok("a junk amount is rejected", r.status === 422 && r.json.code === "bad_amount");
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: mid, service_id: 999999999 });
  ok("an unknown ride type is rejected", r.status === 422);

  const key = "key-" + s + "-1234";
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: mid, client_key: key });
  const bid = r.json.data;
  ok("a valid bid is created and open", r.status === 201 && bid?.status === "open" && bid.offer_fare === mid && bid.estimate_fare === fare, JSON.stringify(r.json));
  ok("the bid carries the whole route", bid.stops.length === 2 && bid.stops[0].address === "First stop" && bid.pickup.address === "Wuse" && bid.dropoff.address === "Gwarinpa");
  const dup = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: mid, client_key: key });
  ok("a double tap returns the same bid", dup.status === 200 && dup.json.data?.id === bid.id && dup.json.duplicate === true);
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, stops, offer: mid });
  ok("a second live bid is refused", r.status === 409 && r.json.code === "bid_in_progress");
  r = await call("POST", "/ride/request", P.api_token, trip);
  ok("a standard request is refused while a bid is open", r.status === 409 && r.json.code === "bid_in_progress");
  ok("a bid is not a ride yet", (await db.query("select count(*)::int as n from app.ride_requests where bid_id = $1", [bid.id])).rows[0].n === 0);

  // --- who receives it ---
  const l1 = await call("GET", "/driver/bids", d1.T), l2 = await call("GET", "/driver/bids", d2.T), l3 = await call("GET", "/driver/bids", d3.T);
  ok("a driver with bids ON sees the bid with the full route", l1.json.bids?.[0]?.id === bid.id && l1.json.bids[0].stops.length === 2 && l1.json.bids[0].offer_fare === mid && l1.json.bids[0].pickup_distance_km >= 0);
  ok("the driver card shows what they would earn after DROP's commission", l1.json.bids[0].commission > 0 && Math.abs(l1.json.bids[0].earning - (mid - l1.json.bids[0].commission)) < 0.011);
  ok("the second opted-in driver also sees it", l2.json.bids?.[0]?.id === bid.id);
  ok("a driver with bids OFF sees nothing", l3.json.bids?.length === 0);
  ok("the driver request poll carries the bids too", (await call("GET", "/driver/requests", d1.T)).json.bids?.[0]?.id === bid.id);
  ok("the bid never appears among standard requests", (await call("GET", "/driver/requests", d1.T)).json.requests.length === 0);
  ok("bids-OFF driver cannot answer", (await call("POST", `/driver/bids/${bid.id}/accept`, d3.T)).status === 403);
  ok("another passenger cannot read the bid", (await call("GET", `/ride/bids/${bid.id}`, P2.api_token)).status === 404);
  for (const act of ["cancel"]) ok("another passenger cannot " + act + " the bid", (await call("POST", `/ride/bids/${bid.id}/${act}`, P2.api_token, {})).status === 404);
  ok("a driver cannot use passenger endpoints", (await call("GET", `/ride/bids/${bid.id}`, d1.T)).status >= 400);
  ok("guessing bid ids finds nothing", (await call("GET", "/ride/bids/999999999", P.api_token)).status === 404);

  // --- standard and bids are independent ---
  await call("PUT", "/driver/preferences", d2.T, { accepts_standard: false });
  const std = await call("POST", "/ride/request", P2.api_token, trip);
  ok("a standard request is created for the other passenger", std.status === 201);
  ok("driver with standard OFF gets no standard requests", (await call("GET", "/driver/requests", d2.T)).json.requests.length === 0);
  ok("driver with standard ON gets it", (await call("GET", "/driver/requests", d1.T)).json.requests[0]?.id === std.json.data.id);
  ok("driver with standard OFF still sees bids", (await call("GET", "/driver/requests", d2.T)).json.bids?.[0]?.id === bid.id);
  const blocked = await call("POST", `/driver/requests/${std.json.data.id}/accept`, d2.T);
  ok("driver with standard OFF cannot accept a standard ride", blocked.status === 403 && blocked.json.code === "standard_requests_off");
  await call("PUT", "/driver/preferences", d3.T, { accepts_standard: false });
  const none = await call("GET", "/driver/requests", d3.T);
  ok("both OFF receives nothing", none.json.requests.length === 0 && none.json.bids.length === 0);
  await call("PUT", "/driver/preferences", d3.T, { accepts_standard: true });
  await call("PUT", "/driver/preferences", d2.T, { accepts_standard: true });
  await call("POST", "/ride/cancel", P2.api_token, {});

  // --- negotiation ---
  r = await call("POST", `/driver/bids/${bid.id}/accept`, d1.T);
  ok("driver accepts the passenger's offer", r.status === 200 && r.json.bids?.[0]?.thread?.status === "driver_accepted_offer" && r.json.bids[0].thread.amount === mid, JSON.stringify(r.json));
  ok("answering twice is refused", (await call("POST", `/driver/bids/${bid.id}/accept`, d1.T)).status === 409);
  ok("a counteroffer outside the range is refused", (await call("POST", `/driver/bids/${bid.id}/counter`, d2.T, { amount: 1 })).status === 422);
  ok("a counteroffer equal to the offer is refused", (await call("POST", `/driver/bids/${bid.id}/counter`, d2.T, { amount: mid })).status === 422);
  const c1 = Math.min(range.max, mid + 200);
  r = await call("POST", `/driver/bids/${bid.id}/counter`, d2.T, { amount: c1 });
  ok("driver counteroffers", r.status === 200 && r.json.bids[0].thread.status === "counteroffered" && r.json.bids[0].thread.amount === c1, JSON.stringify(r.json));
  ok("a counteroffer does not assign the driver", (await db.query("select count(*)::int as n from app.ride_requests where bid_id = $1", [bid.id])).rows[0].n === 0);
  let view = (await call("GET", `/ride/bids/${bid.id}`, P.api_token)).json.data;
  const t1 = view.responses.find((x) => x.driver.id === d1.id), t2 = view.responses.find((x) => x.driver.id === d2.id);
  ok("the passenger sees both drivers with name, vehicle and fare", view.responses.length === 2 && t1.status === "driver_accepted_offer" && t2.status === "counteroffered" && t2.amount === c1 && typeof t1.driver.name === "string" && "vehicle" in t1.driver && "completed_rides" in t1.driver, JSON.stringify(view.responses));
  ok("the history records every step in order", view.history.map((h) => h.action).join(",") === "offered,driver_accepted,driver_countered", view.history.map((h) => h.action).join(","));
  ok("an undecided counteroffer cannot be selected", (await call("POST", `/ride/bids/${bid.id}/select`, P.api_token, { response_id: t2.id })).status === 409);
  r = await call("POST", `/ride/bids/${bid.id}/responses/${t2.id}/revise`, P.api_token, { amount: 1 });
  ok("a passenger revision outside the range is refused", r.status === 422);
  const rev = Math.max(range.min, c1 - 100);
  r = await call("POST", `/ride/bids/${bid.id}/responses/${t2.id}/revise`, P.api_token, { amount: rev });
  ok("passenger revises one driver's counteroffer", r.status === 200 && r.json.data.responses.find((x) => x.id === t2.id).status === "rider_revised" && r.json.data.responses.find((x) => x.id === t2.id).amount === rev, JSON.stringify(r.json));
  ok("the passenger cannot revise twice in a row", (await call("POST", `/ride/bids/${bid.id}/responses/${t2.id}/revise`, P.api_token, { amount: rev + 1 })).status === 409);
  const c3 = Math.min(range.max, c1 + 50);
  ok("the driver counters again (round 3)", (await call("POST", `/driver/bids/${bid.id}/counter`, d2.T, { amount: c3 })).status === 200);
  r = await call("POST", `/ride/bids/${bid.id}/responses/${t2.id}/revise`, P.api_token, { amount: rev });
  ok("the passenger cannot exceed the negotiation limit", r.status === 422 && r.json.code === "rounds_exhausted", JSON.stringify(r.json));
  view = (await call("GET", `/ride/bids/${bid.id}`, P.api_token)).json.data;
  ok("rounds are counted per thread", view.responses.find((x) => x.id === t2.id).rounds === 3 && view.responses.find((x) => x.id === t2.id).rounds_left === 0 && view.responses.find((x) => x.id === t2.id).can_revise === false);
  // force the driver's turn at the cap: the driver is limited too
  await db.query("update app.ride_bid_responses set status = 'rider_revised' where id = $1", [t2.id]);
  const capped = await call("POST", `/driver/bids/${bid.id}/counter`, d2.T, { amount: Math.min(range.max, c3 + 50) });
  ok("the driver cannot exceed the negotiation limit either", capped.status === 422 && capped.json.code === "rounds_exhausted", JSON.stringify(capped.json));
  ok("the driver can still accept the passenger's number", (await call("POST", `/driver/bids/${bid.id}/accept`, d2.T)).status === 200);
  view = (await call("GET", `/ride/bids/${bid.id}`, P.api_token)).json.data;
  ok("the thread is now agreed and selectable", view.responses.find((x) => x.id === t2.id).status === "passenger_accepted_counteroffer" && view.responses.find((x) => x.id === t2.id).amount === c3 && view.responses.find((x) => x.id === t2.id).selectable === true);

  // --- one driver wins, atomically ---
  const race = await Promise.all([
    call("POST", `/ride/bids/${bid.id}/select`, P.api_token, { response_id: t1.id }),
    call("POST", `/ride/bids/${bid.id}/select`, P.api_token, { response_id: t2.id }),
    call("POST", `/ride/bids/${bid.id}/select`, P.api_token, { response_id: t1.id }),
  ]);
  const won = race.filter((x) => x.status === 200);
  ok("concurrent selections: exactly one succeeds", won.length === 1 && race.filter((x) => x.status === 409).length === 2, JSON.stringify(race.map((x) => [x.status, x.json.code])));
  const ride = (await db.query("select * from app.ride_requests where bid_id = $1", [bid.id])).rows;
  ok("exactly one ride exists for the bid", ride.length === 1 && ride[0].status === "accepted");
  const winner = ride[0].driver_id === d1.id ? d1 : d2, loser = winner === d1 ? d2 : d1;
  const agreed = Number(ride[0].fare);
  ok("the ride fare is the agreed fare", agreed === (winner === d1 ? mid : c3), `${agreed}`);
  ok("the fare is marked negotiated", ride[0].fare_breakdown.negotiated === true && ride[0].fare_breakdown.estimate === fare && ride[0].fare_breakdown.total === agreed);
  const rows = (await db.query("select driver_id, status from app.ride_bid_responses where bid_id = $1", [bid.id])).rows;
  ok("the winning thread is selected and the other is closed", rows.find((x) => x.driver_id === winner.id).status === "selected" && rows.find((x) => x.driver_id === loser.id).status === "lost");
  ok("the bid is confirmed with the agreed fare", (await db.query("select status, agreed_fare, selected_driver_id, ride_request_id from app.ride_bids where id = $1", [bid.id])).rows.every((x) => x.status === "confirmed" && Number(x.agreed_fare) === agreed && x.selected_driver_id === winner.id && x.ride_request_id === ride[0].id));
  ok("the winner is busy, the loser is still free", (await db.query("select is_available from app.users where id = $1", [winner.id])).rows[0].is_available === false && (await db.query("select is_available from app.users where id = $1", [loser.id])).rows[0].is_available === true);
  const stopsRows = (await db.query("select sequence, address from app.ride_request_stops where ride_request_id = $1 order by sequence", [ride[0].id])).rows;
  ok("the multi-stop route came across in order", stopsRows.length === 2 && stopsRows[0].address === "First stop" && stopsRows[1].address === "Second stop");
  ok("a pickup code was issued", !!(await call("GET", "/ride/current", P.api_token)).json.data?.pickup_code?.code);
  ok("stale answers after confirmation are refused", (await call("POST", `/driver/bids/${bid.id}/accept`, loser.T)).status === 409 && (await call("POST", `/ride/bids/${bid.id}/revise`, P.api_token, { offer: mid })).status === 409 && (await call("POST", `/ride/bids/${bid.id}/cancel`, P.api_token, {})).status === 409);
  ok("the passenger now has an ordinary ride", (await call("GET", "/ride/current", P.api_token)).json.data?.id === ride[0].id && (await call("GET", "/ride/current", P.api_token)).json.data?.fare === agreed);

  // --- the normal ride lifecycle, unchanged ---
  const rid = ride[0].id;
  ok("start is blocked until the pickup code is verified", (await call("POST", `/driver/rides/${rid}/arrived`, winner.T)).status === 200 && (await call("POST", `/driver/rides/${rid}/start`, winner.T)).status === 409);
  await verifyPickup(rid, winner, P);
  ok("the trip starts after the code", (await call("POST", `/driver/rides/${rid}/start`, winner.T)).status === 200);
  const sr = (await db.query("select id from app.ride_request_stops where ride_request_id = $1 order by sequence", [rid])).rows;
  ok("stops are still sequential", (await call("POST", `/driver/rides/${rid}/stops/${sr[1].id}/arrived`, winner.T)).status === 409);
  for (const st of sr) { await call("POST", `/driver/rides/${rid}/stops/${st.id}/arrived`, winner.T); await call("POST", `/driver/rides/${rid}/stops/${st.id}/complete`, winner.T); }
  const w0 = await bal(winner.id, "driver");
  const done = await call("POST", `/driver/rides/${rid}/complete`, winner.T);
  const commission = Math.round(agreed * 10) / 100;
  ok("the driver's earning and DROP's commission use the agreed fare", done.status === 200 && done.json.data.fare === agreed && Math.abs(done.json.data.commission - commission) < 0.011 && Math.abs(done.json.data.earning - (agreed - commission)) < 0.011, JSON.stringify(done.json));
  ok("cash trip: the commission was debited from the driver wallet", Math.abs((await bal(winner.id, "driver")) - (w0 - commission)) < 0.011);
  const rr = await call("GET", `/ride/${rid}/receipt`, P.api_token), dr = await call("GET", `/driver/rides/${rid}/receipt`, winner.T);
  ok("both receipts show the agreed fare", rr.json.data?.total === agreed && rr.json.data.lines[0].label === "Agreed fare" && dr.json.data?.fare === agreed && Math.abs(dr.json.data.commission - commission) < 0.011, JSON.stringify([rr.json, dr.json]));
  ok("ride history shows the agreed fare", (await call("GET", "/ride/history", P.api_token)).json.data[0].fare === agreed && (await call("GET", "/driver/rides/history", winner.T)).json.data[0].fare === agreed);

  // --- cancelling a bid ---
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, offer: mid });
  const b2 = r.json.data;
  ok("a new bid opens after the last one finished", r.status === 201);
  await call("POST", `/driver/bids/${b2.id}/accept`, d1.T);
  r = await call("POST", `/ride/bids/${b2.id}/cancel`, P.api_token, {});
  ok("the passenger cancels the bid", r.status === 200 && r.json.data.status === "cancelled");
  ok("the driver's thread is closed", (await db.query("select status from app.ride_bid_responses where bid_id = $1", [b2.id])).rows[0].status === "lost");
  ok("a cancelled bid cannot be answered", (await call("POST", `/driver/bids/${b2.id}/accept`, d2.T)).status === 409);
  ok("a cancelled bid disappears from the driver's list", (await call("GET", "/driver/bids", d1.T)).json.bids.length === 0);

  // --- expiry ---
  r = await call("POST", "/ride/bids", P.api_token, { ...trip, offer: mid });
  const b3 = r.json.data;
  await call("POST", `/driver/bids/${b3.id}/accept`, d1.T);
  const th = (await db.query("select id from app.ride_bid_responses where bid_id = $1", [b3.id])).rows[0].id;
  await db.query("update app.ride_bid_responses set expires_at = now() - interval '1 second' where id = $1", [th]);
  r = await call("POST", `/ride/bids/${b3.id}/select`, P.api_token, { response_id: th });
  ok("an expired driver response cannot be selected", r.status === 410 && r.json.code === "offer_expired", JSON.stringify(r.json));
  await db.query("update app.ride_bids set expires_at = now() - interval '1 second' where id = $1", [b3.id]);
  ok("an expired bid reads as expired", (await call("GET", `/ride/bids/${b3.id}`, P.api_token)).json.data.status === "expired" && (await call("GET", "/ride/bids/current", P.api_token)).json.data === null);
  ok("an expired bid cannot be answered or selected", (await call("POST", `/driver/bids/${b3.id}/accept`, d2.T)).status === 409 && (await call("POST", `/ride/bids/${b3.id}/select`, P.api_token, { response_id: th })).status === 410);
  ok("after expiry the passenger can book a standard ride", (await call("POST", "/ride/request", P.api_token, trip)).status === 201);
  await call("POST", "/ride/cancel", P.api_token, {});

  // --- one driver, two bids, two simultaneous selections ---
  const q1 = (await call("POST", "/ride/bids", P.api_token, { ...trip, offer: mid })).json.data;
  const q2 = (await call("POST", "/ride/bids", P2.api_token, { ...trip, offer: mid })).json.data;
  ok("two passengers bid at once", !!q1?.id && !!q2?.id);
  await call("POST", `/driver/bids/${q1.id}/accept`, d1.T); await call("POST", `/driver/bids/${q2.id}/accept`, d1.T);
  const rs1 = (await db.query("select id from app.ride_bid_responses where bid_id = $1", [q1.id])).rows[0].id;
  const rs2 = (await db.query("select id from app.ride_bid_responses where bid_id = $1", [q2.id])).rows[0].id;
  const two = await Promise.all([call("POST", `/ride/bids/${q1.id}/select`, P.api_token, { response_id: rs1 }), call("POST", `/ride/bids/${q2.id}/select`, P2.api_token, { response_id: rs2 })]);
  ok("a driver can only be assigned one ride", two.filter((x) => x.status === 200).length === 1 && two.filter((x) => x.status === 409).length === 1, JSON.stringify(two.map((x) => [x.status, x.json.code])));
  ok("only one open ride exists for that driver", (await db.query("select count(*)::int as n from app.ride_requests where driver_id = $1 and status in ('accepted','arrived','in_progress')", [d1.id])).rows[0].n === 1);
  // a driver who cancels a bid ride must not push the negotiated fare back into the open pool
  const live = (await db.query("select id from app.ride_requests where driver_id = $1 and status = 'accepted'", [d1.id])).rows[0].id;
  ok("driver cancels the agreed ride", (await call("POST", `/driver/rides/${live}/cancel`, d1.T)).status === 200);
  ok("a cancelled bid ride is not re-opened to other drivers", (await db.query("select status, cancelled_by from app.ride_requests where id = $1", [live])).rows[0].status === "cancelled" && (await call("GET", "/driver/requests", d2.T)).json.requests.length === 0);
  await db.query("update app.ride_bids set status = 'cancelled', closed_at = now() where status = 'open' and rider_id = any($1)", [[P.id, P2.id]]);
  await db.query("update app.ride_requests set status = 'cancelled' where rider_id = any($1) and status in ('searching','accepted','arrived','in_progress')", [[P.id, P2.id]]);

  // --- turning bids OFF never breaks an agreement already made ---
  const q3 = (await call("POST", "/ride/bids", P.api_token, { ...trip, offer: mid })).json.data;
  await call("POST", `/driver/bids/${q3.id}/accept`, d2.T);
  await call("PUT", "/driver/preferences", d2.T, { accepts_bids: false });
  const th3 = (await call("GET", `/ride/bids/${q3.id}`, P.api_token)).json.data.responses[0];
  ok("a driver who switched bids off keeps the agreement they already made", th3.selectable === true && (await call("GET", "/driver/bids", d2.T)).json.bids?.[0]?.id === q3.id);
  ok("the passenger can still confirm that driver", (await call("POST", `/ride/bids/${q3.id}/select`, P.api_token, { response_id: th3.id })).status === 200);
  ok("a driver with bids off gets no NEW bids", (await call("GET", "/driver/bids", d2.T)).json.bids.length === 0);
  await db.query("update app.ride_requests set status = 'cancelled' where rider_id = $1 and status = 'accepted'", [P.id]);
  await db.query("update app.users set is_available = true where id = $1", [d2.id]);

  // --- anti-spam and admin ---
  await setBid({ max_bids_per_hour: 1 });
  const lim = await call("POST", "/ride/bids", P2.api_token, { ...trip, offer: mid });
  ok("bids are rate limited per passenger", lim.status === 429 && lim.json.code === "bid_rate_limited", JSON.stringify(lim.json));
  await setBid({});
  await setBid({ overrides: [{ service_id: Number(svc), enabled: false }] });
  r = await call("POST", "/ride/bids", P2.api_token, { ...trip, offer: mid });
  ok("an admin can switch bidding off for one ride type", r.status === 422 && r.json.code === "bidding_unavailable");
  await setBid({});
  const an = await call("GET", "/admin/bids?days=1", A);
  ok("admin analytics report real numbers", an.status === 200 && an.json.summary.total >= 5 && an.json.summary.confirmed >= 3 && an.json.summary.avg_agreed > 0 && an.json.comparison.bidding.completed >= 1 && an.json.recent.length > 0, JSON.stringify(an.json.summary));
  ok("analytics are admin only", (await call("GET", "/admin/bids", P.api_token)).status === 403);

  // --- standard booking regression ---
  const sr0 = await call("POST", "/ride/request", P.api_token, trip);
  ok("standard booking still works after all of this", sr0.status === 201 && Number(sr0.json.data.fare) > 0);
  const acc = await call("POST", `/driver/requests/${sr0.json.data.id}/accept`, d1.T);
  ok("a standard request is still accepted first-come", acc.status === 200 && acc.json.data?.fare === sr0.json.data.fare);
  ok("a standard ride's fare breakdown is not marked negotiated", !(await db.query("select fare_breakdown from app.ride_requests where id = $1", [sr0.json.data.id])).rows[0].fare_breakdown.negotiated);
} finally {
  if (oldMin !== undefined) await db.query("update app.settings set value = $1::jsonb where key = 'driver_min_wallet_balance'", [JSON.stringify(oldMin)]);
  if (oldBid !== undefined) await db.query("update app.settings set value = $1::jsonb where key = 'bidding'", [JSON.stringify(oldBid)]);
  if (svc !== undefined) {
    await db.query("update app.ride_requests set bid_id = null where service_id = $1", [svc]);
    await db.query("delete from app.ride_bids where service_id = $1", [svc]);
    await db.query("delete from app.ride_requests where service_id = $1", [svc]);
    await db.query("delete from app.services where id = $1", [svc]);
  }
  if (region !== undefined) await db.query("delete from app.regions where id = $1", [region]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
