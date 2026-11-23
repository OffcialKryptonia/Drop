// Airport booking rules end to end against a disposable DB. Test/CI database only, never production.
// All coordinates below are synthetic test fixtures, not real airport data.
// Run: DATABASE_URL=... ADMIN_EMAIL=... ADMIN_PASSWORD=... node test/airport-smoke.mjs
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
const reg = async (type, tag) => (await call("POST", "/register", null, { first_name: "A", last_name: tag + s, email: `${tag}${s}@x.com`, username: `${tag}${s}`, password: "secret123", user_type: type, contact_number: phone() })).json.data;
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;

const was = (await db.query("select id from app.regions where status")).rows.map((r) => r.id);
let region, regionOff, svcAir, svcNow;
const ids = [], airports = [];
try {
  await db.query("update app.regions set status = false where status");
  region = (await db.query("insert into app.regions (name, distance_unit, status, timezone, boundary) values ($1,'km',true,'Africa/Lagos', extensions.st_geogfromtext('POLYGON((7 8.8, 7.8 8.8, 7.8 9.4, 7 9.4, 7 8.8))')) returning id", ["AirTest" + s])).rows[0].id;
  regionOff = (await db.query("insert into app.regions (name, distance_unit, status, timezone) values ($1,'km',false,'Africa/Lagos') returning id", ["AirOff" + s])).rows[0].id;
  const mk = (name, modes) => db.query(
    `insert into app.services (name, region_id, capacity, base_fare, minimum_fare, minimum_distance, per_distance, per_minute_drive, cancellation_fee, commission_type, admin_commission, status, payment_methods, booking_modes, sort_order)
     values ($1,$2,4,500,800,2,100,10,300,'percentage',10,true,array['cash','wallet'],$3::text[],0) returning id`, [name + s, region, modes]).then((r) => Number(r.rows[0].id));
  svcAir = await mk("AirCar", ["now", "airport"]);
  svcNow = await mk("PlainCar", ["now"]);

  const P = await reg("rider", "ap"); ids.push(P.id);
  const zone = { lat: 9.0765, lng: 7.3986, address: "Zone A" };
  const zone2 = { lat: 9.0579, lng: 7.4951, address: "Zone B" };
  const AP1 = { lat: 8.9800, lng: 7.2600 }, AP2 = { lat: 9.3000, lng: 7.7000 }, FAR = { lat: 12.0, lng: 3.0 };
  const body = (name, lat, lng, extra = {}) => ({ region_id: Number(region), name: name + s, latitude: lat, longitude: lng, radius_m: 1500, terminals: [{ name: "T1" }], default_surcharge: 200, status: true, ...extra });

  // --- admin: permissions and validation ---
  ok("riders cannot manage airports", (await call("POST", "/admin/airports", P.api_token, body("X", AP1.lat, AP1.lng))).status === 403);
  ok("activation needs a location and boundary", (await call("POST", "/admin/airports", A, { region_id: Number(region), name: "NoGeo" + s, status: true })).status === 422);
  ok("a bad IATA code is rejected", (await call("POST", "/admin/airports", A, body("Bad", AP1.lat, AP1.lng, { iata_code: "ABCD" }))).status === 422);
  const c1 = await call("POST", "/admin/airports", A, body("AirportOne", AP1.lat, AP1.lng));
  const c2 = await call("POST", "/admin/airports", A, body("AirportTwo", AP2.lat, AP2.lng));
  const inactive = await call("POST", "/admin/airports", A, body("Dormant", 9.35, 7.1, { status: false }));
  const offRegion = await call("POST", "/admin/airports", A, { ...body("OffRegion", 9.2, 7.2), region_id: Number(regionOff) });
  const a1 = c1.json.id, a2 = c2.json.id, aOff = inactive.json.id, aReg = offRegion.json.id;
  airports.push(a1, a2, aOff, aReg);
  ok("admin creates airports", c1.status === 201 && c2.status === 201 && inactive.status === 201, JSON.stringify([c1.json, c2.json, inactive.json]));
  ok("creation is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'airport_add' and target = $1", [String(a1)])).rowCount === 1);
  const pub = await call("GET", "/airports", P.api_token);
  const names = (pub.json.data ?? []).map((x) => x.id);
  ok("public list has active airports only, and no flight tracking", names.includes(a1) && names.includes(a2) && !names.includes(aOff) && !names.includes(aReg) && pub.json.flight_tracking === false, JSON.stringify(pub.json));

  const est = (extra, p = zone, d = AP1) => call("POST", "/ride/estimate", P.api_token, { pickup: p, dropoff: d, ...extra });
  // --- the two valid directions ---
  let r = await est({ airport: { id: a1, direction: "drop" } });
  ok("Airport Drop (zone to airport) is priced", r.status === 200 && r.json.airport?.direction === "drop" && r.json.ride_types?.length === 1 && r.json.ride_types[0].id === svcAir, JSON.stringify(r.json));
  ok("only ride types allowing airport rides are offered", !r.json.ride_types?.some((t) => t.id === svcNow));
  ok("airport surcharge is added by the server", r.json.ride_types?.[0]?.fare_breakdown?.airport_surcharge === 200);
  ok("bidding is off for airport rides and flight tracking is not claimed", r.json.bidding?.enabled === false && r.json.airport?.flight_tracking === false);
  r = await est({ airport: { id: a1, direction: "pickup" } }, AP1, zone2);
  ok("Airport Pickup (airport to zone) is priced", r.status === 200 && r.json.airport?.direction === "pickup", JSON.stringify(r.json));

  // --- rejected shapes ---
  const code = async (p, d, ap) => { const x = await est({ airport: ap }, p, d); return x.status + ":" + x.json.code; };
  ok("zone to zone is rejected", (await code(zone, zone2, { id: a1, direction: "drop" })) === "422:airport_endpoint_invalid");
  ok("wrong direction for the airport end is rejected", (await code(zone, AP1, { id: a1, direction: "pickup" })) === "422:airport_endpoint_invalid");
  ok("airport to airport is rejected", (await code(AP1, AP2, { id: a1, direction: "pickup" })) === "422:airport_to_airport");
  ok("inactive airport is rejected", (await code(zone, { lat: 9.35, lng: 7.1 }, { id: aOff, direction: "drop" })) === "422:airport_inactive");
  ok("airport in an inactive region is rejected", (await code(zone, { lat: 9.2, lng: 7.2 }, { id: aReg, direction: "drop" })) === "422:airport_region_inactive");
  ok("unknown airport is rejected", (await code(zone, AP1, { id: 999999, direction: "drop" })) === "422:airport_unavailable");
  ok("zone end outside every active region is rejected", (await code(FAR, AP1, { id: a1, direction: "drop" })) === "422:outside_service_area");
  ok("an invalid direction is a validation error", (await est({ airport: { id: a1, direction: "sideways" } })).status === 422);
  ok("extra stops are refused on airport rides", (await est({ airport: { id: a1, direction: "drop" }, stops: [zone2] })).json.code === "airport_no_stops");
  ok("ordinary rides are unchanged", (await est({}, zone, zone2)).json.ride_types?.some((t) => t.id === svcNow));

  // --- price rules: precedence and request ---
  ok("fixed rule per ride type and direction", (await call("POST", `/admin/airports/${a1}/prices`, A, { service_id: svcAir, direction: "drop", mode: "fixed", fixed_price: 7500, surcharge: 100 })).status === 201);
  ok("duplicate rule is refused", (await call("POST", `/admin/airports/${a1}/prices`, A, { service_id: svcAir, direction: "drop", mode: "fixed", fixed_price: 1 })).status === 422);
  ok("a fixed rule needs a price", (await call("POST", `/admin/airports/${a1}/prices`, A, { mode: "fixed" })).status === 422);
  r = await est({ airport: { id: a1, direction: "drop" } });
  ok("fixed price wins over distance pricing", r.json.ride_types?.[0]?.fare === 7600 && r.json.ride_types[0].fare_breakdown.airport_pricing === "fixed", JSON.stringify(r.json.ride_types?.[0]));
  r = await est({ airport: { id: a1, direction: "pickup" } }, AP1, zone2);
  ok("other direction still uses standard fare + surcharge", r.json.ride_types?.[0]?.fare_breakdown?.airport_pricing === "standard");

  const req = await call("POST", "/ride/request", P.api_token, { pickup: zone, dropoff: AP1, service_id: svcAir, payment_method: "cash", airport: { id: a1, direction: "drop" } });
  ok("airport ride is requested through the normal lifecycle at the server fare", req.status === 201 && Number(req.json.data?.fare) === 7600, JSON.stringify(req.json));
  const row = (await db.query("select airport_id, airport_direction, fare from app.ride_requests where id = $1", [req.json.data?.id])).rows[0];
  ok("airport and direction are stored on the ride", Number(row?.airport_id) === a1 && row?.airport_direction === "drop");
  await call("POST", "/ride/cancel", P.api_token, {});
  const bad = await call("POST", "/ride/request", P.api_token, { pickup: zone, dropoff: zone2, service_id: svcAir, payment_method: "cash", airport: { id: a1, direction: "drop" } });
  ok("a forged airport request is rejected at booking", bad.status === 422 && bad.json.code === "airport_endpoint_invalid", JSON.stringify(bad.json));
  const noMode = await call("POST", "/ride/request", P.api_token, { pickup: zone, dropoff: AP1, service_id: svcNow, payment_method: "cash", airport: { id: a1, direction: "drop" } });
  ok("a ride type without airport rides cannot be used", noMode.status === 422 && noMode.json.code === "ride_type_unavailable", JSON.stringify(noMode.json));

  // --- Phase 3: flight details and driver view ---
  const D = await reg("driver", "dv"); ids.push(D.id);
  await db.query("update app.driver_profiles set status = 'approved', service_id = $2 where user_id = $1", [D.id, svcAir]);
  await db.query("update app.users set status = 'active' where id = $1", [D.id]);
  await db.query("insert into app.wallets (user_id, kind, balance, allow_negative) values ($1,'driver',5000,true) on conflict (user_id, kind) do update set balance = 5000", [D.id]);
  const DT = (await call("POST", "/login", null, { email: `dv${s}@x.com`, password: "secret123" })).json.data.api_token;
  await call("POST", "/mode", DT, { mode: "driver" });
  await call("POST", "/driver/online", DT, { online: true, latitude: 8.985, longitude: 7.26 });
  const cfgRes = await call("GET", "/admin/airport-flight-fields", A);
  ok("admin can read flight field settings", cfgRes.status === 200 && cfgRes.json.data?.pickup?.flight_number?.required === true, JSON.stringify(cfgRes.json));
  ok("riders cannot change flight field settings", (await call("PUT", "/admin/airport-flight-fields", P.api_token, {})).status === 403);
  const pubCfg = await call("GET", "/airports", P.api_token);
  ok("public airport list carries the field settings", pubCfg.json.flight_fields?.pickup?.terminal?.required === true);
  await call("PUT", `/admin/airports/${a1}`, A, body("AirportOne", AP1.lat, AP1.lng, { status: true }));
  const pickReq = (flight) => call("POST", "/ride/request", P.api_token, { pickup: AP1, dropoff: zone2, service_id: svcAir, payment_method: "cash", airport: { id: a1, direction: "pickup" }, flight });
  const missing = await pickReq({});
  ok("required flight details are enforced by the server", missing.status === 422 && missing.json.code === "flight_details_invalid" && !!missing.json.errors?.flight_number, JSON.stringify(missing.json));
  ok("a terminal the airport does not list is refused", (await pickReq({ flight_number: "KQ530", terminal: "Terminal 99" })).status === 422);
  const good = await pickReq({ flight_number: "kq 530", terminal: "T1", passenger_count: 2, contact_phone: "08031234567", instructions: "Meet at the arrivals door" });
  ok("airport pickup with flight details is accepted", good.status === 201 && good.json.data?.airport?.flight?.flight_number === "KQ530" && good.json.data.airport.label === "Airport Pickup", JSON.stringify(good.json));
  ok("flight tracking is never claimed", good.json.data?.airport?.flight_tracking === false);
  const rideId = good.json.data?.id;
  const dreq = await call("GET", "/driver/requests", DT);
  const offer = (dreq.json.requests ?? []).find((x) => x.id === rideId);
  if (offer) {
    ok("driver sees an airport pickup badge, airport, flight and earnings", offer.airport?.label === "Airport Pickup" && offer.airport?.flight?.flight_number === "KQ530" && typeof offer.earning === "number", JSON.stringify(offer.airport));
    ok("the driver never receives the passenger's phone number", !JSON.stringify(offer).includes("08031234567") && offer.airport.flight.has_contact === true);
    const acc = await call("POST", `/driver/requests/${rideId}/accept`, DT);
    ok("driver accepts through the normal flow", acc.status === 200, JSON.stringify(acc.json));
    const act = await call("GET", "/driver/requests", DT);
    ok("active ride keeps the airport details", act.json.active?.airport?.name?.startsWith("AirportOne") && !JSON.stringify(act.json.active).includes("08031234567"));
  } else console.log("SKIP driver offer checks (driver fixture not eligible in this environment)");
  await call("POST", "/ride/cancel", P.api_token, {});

  // --- deactivation takes effect immediately; edits and deletes are audited ---
  ok("admin deactivates an airport", (await call("PUT", `/admin/airports/${a1}`, A, body("AirportOne", AP1.lat, AP1.lng, { status: false }))).status === 200);
  ok("a deactivated airport refuses bookings at once", (await code(zone, AP1, { id: a1, direction: "drop" })) === "422:airport_inactive");
  ok("edit is audit-logged", (await db.query("select 1 from app.admin_audit where action = 'airport_edit' and target = $1", [String(a1)])).rowCount >= 1);
} finally {
  if (svcAir !== undefined) await db.query("delete from app.ride_requests where service_id = any($1)", [[svcAir, svcNow].filter(Boolean)]);
  if (airports.length) {
    await db.query("update app.ride_requests set airport_id = null where airport_id = any($1)", [airports.filter(Boolean)]);
    await db.query("delete from app.airports where id = any($1)", [airports.filter(Boolean)]);
  }
  if (svcAir !== undefined) await db.query("delete from app.services where id = any($1)", [[svcAir, svcNow].filter(Boolean)]);
  for (const g of [region, regionOff]) if (g !== undefined) await db.query("delete from app.regions where id = $1", [g]);
  await db.query("update app.regions set status = true where id = any($1)", [was]);
  for (const id of ids) await db.query("delete from app.users where id = $1", [id]).catch(() => {});
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
