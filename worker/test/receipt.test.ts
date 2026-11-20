// Pure receipt maths, no database. Run: npx tsx test/receipt.test.ts
import assert from "node:assert/strict";
import { driverReceipt, riderReceipt } from "../src/lib/receipt";

const ride = { id: 7, fare: 2000, commission: 300, paid_with: "wallet", currency: "NGN", status: "completed", distance: 5, distance_unit: "km", duration_minutes: 12,
  fare_breakdown: { base_fare: 500, distance_charge: 1000, time_charge: 500, options_total: 0, minimum_fare_applied: false, total: 2000 } };
const extras = [
  { kind: "toll", amount: "400.00", status: "paid", paid_with: "cash", commission: "0.00" },
  { kind: "parking", amount: "100.00", status: "declined", paid_with: null, commission: "0.00" },
];

const tests: [string, () => void][] = [
  ["numbers come from the trip id", () => {
    assert.equal(riderReceipt(ride).number, "DROP-R-000007");
    assert.equal(driverReceipt(ride).number, "DROP-D-000007");
  }],
  ["rider total adds only paid extras", () => {
    const r = riderReceipt(ride, extras);
    assert.equal(r.total, 2400);
    assert.ok(r.lines.map((l) => l.label).includes("Toll"));
    assert.ok(!r.lines.map((l) => l.label).includes("Parking"));
  }],
  ["driver earning includes paid extras and flags cash to collect", () => {
    const d = driverReceipt(ride, extras);
    assert.equal(d.fare, 2400);
    assert.equal(d.earning, 2100);
    assert.equal(d.collect_cash, true);
    assert.equal(d.cash_extras, 400);
  }],
  ["admin-named charge shows its label and its commission joins the trip commission", () => {
    const x = [{ kind: "fuel_hike", label: "Fuel hike", amount: "500.00", status: "paid", paid_with: "wallet", commission: "75.00" }];
    const d = driverReceipt(ride, x);
    assert.equal(d.commission, 375);
    assert.equal(d.earning, 2125);
    assert.ok(d.lines.map((l) => l.label).includes("Fuel hike"));
  }],
  ["ordered intermediate stops are included in both rider and driver receipts", () => {
    const withStops = { ...ride, stops: [
      { id: 2, sequence: 2, address: "Second stop", status: "completed" },
      { id: 1, sequence: 1, address: "First stop", status: "completed" },
    ] };
    assert.deepEqual(riderReceipt(withStops).stops, withStops.stops);
    assert.deepEqual(driverReceipt(withStops).stops, withStops.stops);
  }],
  ["without extras nothing changes", () => {
    const d = driverReceipt(ride);
    assert.equal(d.earning, 1700);
    assert.equal(d.collect_cash, false);
  }],
];

for (const [name, fn] of tests) { fn(); console.log("ok -", name); }
