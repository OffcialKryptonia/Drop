import { strict as assert } from "node:assert";
import { CATEGORIES, EVENTS, EVENT_BY_KEY, placeholders, renderText, safeDeepLink, sampleValues, usesSensitive, validateTemplate, VARIABLES } from "../src/lib/push-templates";

const base = { name: "Test", category: "ride", audience: "passenger", title: "Hi", body: "Body" };
const ctx = { allowedLinkHosts: ["links.example.com"], checkKey: false };
const errs = (o: Record<string, unknown>) => validateTemplate({ ...base, ...o } as never, ctx).errors;

// ---- placeholders: only {{name}} with letters/underscores
assert.deepEqual(placeholders("Hi {{passenger_name}} and {{ driver_name }}").names, ["passenger_name", "driver_name"]);
assert.ok(placeholders("{{passenger_name").malformed && placeholders("x }} y").malformed);

// ---- unknown, hostile and inherited names are refused, never evaluated
for (const bad of ["{{process.env.SECRET}}", "{{constructor}}", "{{__proto__}}", "{{toString}}", "{{ otp", "{{#each}}", "${1+1}{{"])
  assert.ok(errs({ body: bad }).body, bad);
assert.ok(!errs({ body: "Hi {{passenger_name}}, ride {{ride_id}}" }).body);
assert.equal(renderText("{{constructor}}|{{__proto__}}|{{tostring}}", {}), "||");
assert.equal(renderText("{{constructor}}", { constructor: "leak" }), "");

// ---- rendering: single pass, sanitised, capped, maskable
assert.equal(renderText("Hi {{passenger_name}}", { passenger_name: "{{otp}}", otp: "9999" }), "Hi {{otp}}", "a value is never expanded again");
assert.equal(renderText("A {{note}} B", { note: "x\u0000y\n\nz w" }), "A x y z w B");
assert.equal(renderText("{{airport_code}}", { airport_code: "ABCDEFGH" }), "ABCD");
assert.equal(renderText("Code {{otp}}", { otp: "1234" }, { mask: true }), "Code ••••");
assert.equal(renderText("{{amount}} · {{pickup_location}}", { amount: "₦500", pickup_location: "" }), "₦500", "dangling separator is removed");
assert.equal(renderText("drop://ride/{{ride_id}}?x={{note}}", { ride_id: "12", note: "a b&c" }, { encode: true }), "drop://ride/12?x=a%20b%26c");
assert.equal(renderText("{{fare}}", {}), "", "a missing value renders empty");

// ---- sensitive variables
assert.ok(usesSensitive("Your code is {{otp}}") && usesSensitive("x", "bal {{wallet_balance}}") && !usesSensitive("{{fare}}"));
assert.ok(errs({ deep_link: "drop://x/{{otp}}" }).deep_link, "no pickup code in a link");

// ---- deep links and images
for (const ok of ["drop://ride/12", "drop://wallet", "https://links.example.com/a?b=1"]) assert.ok(safeDeepLink(ok, ctx.allowedLinkHosts), ok);
for (const bad of ["javascript:alert(1)", "data:text/html,x", "http://links.example.com/", "https://evil.com/", "https://links.example.com:8443/", "https://user:pw@links.example.com/", "drop://", "drop://a b", "//links.example.com", "file:///etc/passwd"])
  assert.ok(!safeDeepLink(bad, ctx.allowedLinkHosts), bad);
assert.ok(!errs({ deep_link: "drop://ride/{{ride_id}}" }).deep_link);
assert.ok(errs({ deep_link: "https://evil.com/{{ride_id}}" }).deep_link);
assert.ok(!errs({ image_url: "https://cdn.example.com/a.png" }).image_url);
for (const bad of ["http://cdn.example.com/a.png", "javascript:x", "https://cdn.example.com/{{note}}.png", "https://a b.com/x.png"]) assert.ok(errs({ image_url: bad }).image_url, bad);

// ---- field rules
assert.ok(errs({ title: "" }).title && errs({ title: "x".repeat(81) }).title && errs({ body: "x".repeat(301) }).body);
assert.ok(errs({ category: "nope" }).category && errs({ audience: "everyone" }).audience && errs({ name: "a" }).name);
assert.ok(errs({ action_label: "x".repeat(31) }).action_label && !errs({ action_label: "Open" }).action_label);
const keyCtx = { allowedLinkHosts: [] };
for (const bad of ["Passenger.X", "nodot", "a..b", "a.b-c", ".a.b", "x".repeat(81) + ".y"]) assert.ok(validateTemplate({ ...base, key: bad } as never, keyCtx).errors.key, bad);
assert.ok(!validateTemplate({ ...base, key: "passenger.promo_weekend" } as never, keyCtx).errors.key);
assert.deepEqual(validateTemplate({ ...base, body: "{{fare}} {{fare}} {{driver_name}}" } as never, ctx).variables, ["fare", "driver_name"], "variables are derived by the server");

// ---- the built-in catalogue is itself valid, unique and complete
const keys = new Set<string>();
for (const e of EVENTS) {
  assert.ok(!keys.has(e.key), "duplicate key " + e.key); keys.add(e.key);
  assert.ok(CATEGORIES[e.category], e.key + " category");
  assert.ok(e.key.startsWith(e.audience === "all" ? "ride." : e.audience + "."), e.key + " prefix matches audience");
  const v = validateTemplate({ name: e.name, category: e.category, audience: e.audience, title: e.title, body: e.body, key: e.key }, { allowedLinkHosts: [] });
  assert.deepEqual(v.errors, {}, e.key + " " + JSON.stringify(v.errors));
  assert.ok(e.wired || e.note, e.key + " unconnected templates must say why");
  assert.ok(!usesSensitive(e.title, e.body), e.key + " defaults carry no sensitive value");
}
assert.equal(EVENT_BY_KEY.size, EVENTS.length);

// ---- spec coverage: every category in the Phase 4 brief has a template
for (const k of ["passenger.welcome", "passenger.ride_requested", "passenger.driver_assigned", "passenger.driver_approaching", "passenger.driver_arrived", "passenger.pickup_otp", "passenger.ride_started",
  "passenger.stop_completed", "passenger.ride_completed", "passenger.ride_cancelled_by_driver", "passenger.payment_confirmed", "passenger.extra_charge_refunded", "passenger.wallet_credited",
  "passenger.scheduled_reminder", "passenger.airport_pickup_reminder", "passenger.airport_drop_reminder", "passenger.promotion", "passenger.referral", "passenger.support_update", "passenger.safety_alert",
  "driver.new_ride_request", "driver.ride_assigned", "driver.ride_cancelled_by_passenger", "driver.passenger_arrived", "driver.pickup_authorised", "driver.stop_update", "driver.ride_completed",
  "driver.earnings", "driver.payout_update", "driver.wallet_credited", "driver.application_approved", "driver.document_approved", "driver.document_rejected", "driver.document_expiring",
  "driver.account_warning", "driver.account_suspended", "driver.airport_booking_assigned", "driver.scheduled_reminder", "passenger.airport_pickup_confirmed"])
  assert.ok(EVENT_BY_KEY.has(k), "missing " + k);

// ---- every variable named in the brief exists
for (const v of ["passenger_name", "driver_name", "ride_id", "pickup_location", "destination", "airport_name", "airport_code", "terminal", "eta", "fare", "wallet_balance", "otp"])
  assert.ok(VARIABLES[v], v);
assert.equal(Object.keys(sampleValues()).length, Object.keys(VARIABLES).length);

console.log("push-templates.test: all assertions passed");
