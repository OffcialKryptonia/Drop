// Fare bidding rules, no database or network. Run: npx tsx test/bidding.test.ts
import assert from "node:assert/strict";
import { LIVE, SELECTABLE, checkOffer, limitsFor, normalizeSettings, transition, type Action, type RespStatus } from "../src/lib/bidding";

const on = normalizeSettings({ enabled: true });

const tests: [string, () => void][] = [
  ["bidding is OFF unless an admin switches it on", () => {
    assert.equal(normalizeSettings({}).enabled, false);
    assert.equal(normalizeSettings(null).enabled, false);
    assert.equal(limitsFor(normalizeSettings({}), 5500, 1, 1).enabled, false);
  }],
  ["settings are clamped to safe values", () => {
    const s = normalizeSettings({ enabled: true, min_percent: 1, max_percent: 9999, max_rounds: 99, bid_expiry_seconds: 1, max_active_bids: 0 });
    assert.equal(s.min_percent, 10); assert.equal(s.max_percent, 500); assert.equal(s.max_rounds, 10);
    assert.equal(s.bid_expiry_seconds, 30); assert.equal(s.max_active_bids, 1);
  }],
  ["limits follow the percentage of DROP's estimate (₦5,500 → ₦3,850 to ₦8,250 at 70%–150%)", () => {
    const l = limitsFor(on, 5500, 1, 1);
    assert.equal(l.enabled, true); assert.equal(l.min, 3850); assert.equal(l.max, 8250);
  }],
  ["absolute floor and ceiling tighten the range", () => {
    const l = limitsFor(normalizeSettings({ enabled: true, absolute_min: 4000, absolute_max: 7000 }), 5500, 1, 1);
    assert.equal(l.min, 4000); assert.equal(l.max, 7000);
  }],
  ["a ride-type override beats the global rule; region+type beats type alone", () => {
    const s = normalizeSettings({ enabled: true, overrides: [
      { service_id: 2, max_percent: 120 },
      { service_id: 2, region_id: 9, max_percent: 110 },
      { service_id: 3, enabled: false },
    ] });
    assert.equal(limitsFor(s, 1000, 1, 1).max, 1500);
    assert.equal(limitsFor(s, 1000, 1, 2).max, 1200);
    assert.equal(limitsFor(s, 1000, 9, 2).max, 1100);
    assert.equal(limitsFor(s, 1000, 1, 3).enabled, false);
  }],
  ["an override cannot switch bidding on when the global switch is off", () => {
    const s = normalizeSettings({ enabled: false, overrides: [{ service_id: 2, enabled: true }] });
    assert.equal(limitsFor(s, 1000, 1, 2).enabled, false);
  }],
  ["offers outside the range are rejected with a clear message", () => {
    const l = limitsFor(on, 5500, 1, 1);
    const low = checkOffer(1000, l, "NGN"); assert.equal(low.ok, false);
    if (!low.ok) { assert.equal(low.code, "below_min"); assert.match(low.message, /3,850/); assert.match(low.message, /8,250/); }
    const high = checkOffer("99999", l, "NGN"); assert.equal(high.ok, false);
    if (!high.ok) assert.equal(high.code, "above_max");
  }],
  ["junk amounts are rejected, valid ones are rounded to kobo", () => {
    const l = limitsFor(on, 5500, 1, 1);
    for (const bad of [null, undefined, "", "abc", 0, -5, NaN]) assert.equal(checkOffer(bad, l, "NGN").ok, false, String(bad));
    const good = checkOffer("4,500.456", l, "NGN");
    assert.equal(good.ok, true); if (good.ok) assert.equal(good.amount, 4500.46);
  }],
  ["a driver may accept, counter or decline a fresh bid", () => {
    assert.equal(transition(null, "driver_accept"), "driver_accepted_offer");
    assert.equal(transition(null, "driver_counter"), "counteroffered");
    assert.equal(transition(null, "driver_decline"), "declined");
  }],
  ["a passenger cannot act before a driver has answered", () => {
    for (const a of ["rider_accept", "rider_reject", "rider_revise", "select"] as Action[]) assert.equal(transition(null, a), null, a);
  }],
  ["counteroffer → passenger accepts, rejects or revises", () => {
    assert.equal(transition("counteroffered", "rider_accept"), "passenger_accepted_counteroffer");
    assert.equal(transition("counteroffered", "rider_reject"), "rejected");
    assert.equal(transition("counteroffered", "rider_revise"), "rider_revised");
  }],
  ["a revised passenger offer can be accepted, countered or declined by the driver", () => {
    assert.equal(transition("rider_revised", "driver_accept"), "passenger_accepted_counteroffer");
    assert.equal(transition("rider_revised", "driver_counter"), "counteroffered");
    assert.equal(transition("rider_revised", "driver_decline"), "declined");
  }],
  ["only an agreed thread can be selected", () => {
    for (const st of SELECTABLE) assert.equal(transition(st, "select"), "selected");
    for (const st of ["counteroffered", "rider_revised"] as RespStatus[]) assert.equal(transition(st, "select"), null, st);
  }],
  ["no action revives a finished thread (stale responses are rejected)", () => {
    const finished: RespStatus[] = ["selected", "declined", "rejected", "expired", "lost"];
    const all: Action[] = ["driver_accept", "driver_counter", "driver_decline", "rider_accept", "rider_reject", "rider_revise", "select"];
    for (const st of finished) for (const a of all) assert.equal(transition(st, a), null, `${st} + ${a}`);
  }],
  ["a driver cannot answer the same turn twice", () => {
    assert.equal(transition("driver_accepted_offer", "driver_accept"), null);
    assert.equal(transition("counteroffered", "driver_counter"), null);
    assert.equal(transition("counteroffered", "driver_accept"), null);
  }],
  ["every live status can end somehow, and no finished status is live", () => {
    for (const st of LIVE) assert.ok(transition(st, "driver_decline") || transition(st, "rider_reject"), st);
    for (const st of ["selected", "declined", "rejected", "expired", "lost"] as RespStatus[]) assert.equal(LIVE.includes(st), false);
  }],
];

let failed = 0;
for (const [name, fn] of tests) {
  try { fn(); console.log("PASS", name); } catch (e) { failed++; console.log("FAIL", name, (e as Error).message); }
}
console.log(failed ? `${failed} FAILED` : "ALL PASSED");
process.exit(failed ? 1 : 0);
