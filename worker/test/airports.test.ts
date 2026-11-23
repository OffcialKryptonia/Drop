import { strict as assert } from "node:assert";
import { airportFare, parseDirection, pickPriceRule, type PriceRule } from "../src/lib/airports";

const svc = { base_fare: 500, minimum_fare: 1000, minimum_distance: 1, per_distance: 100, per_minute_drive: 10 };
const rules: PriceRule[] = [
  { service_id: null, direction: null, mode: "standard", fixed_price: null, surcharge: 300 },
  { service_id: null, direction: "pickup", mode: "fixed", fixed_price: 9000, surcharge: 0 },
  { service_id: 7, direction: null, mode: "fixed", fixed_price: 12000, surcharge: 500 },
  { service_id: 7, direction: "drop", mode: "fixed", fixed_price: 8000, surcharge: 200 },
];

assert.equal(parseDirection("drop"), "drop");
assert.equal(parseDirection("pickup"), "pickup");
assert.equal(parseDirection("x"), null);
assert.equal(parseDirection(undefined), null);

assert.equal(pickPriceRule(rules, 7, "drop")?.fixed_price, 8000);
assert.equal(pickPriceRule(rules, 7, "pickup")?.fixed_price, 12000);
assert.equal(pickPriceRule(rules, 3, "pickup")?.fixed_price, 9000);
assert.equal(pickPriceRule(rules, 3, "drop")?.mode, "standard");
assert.equal(pickPriceRule([], 3, "drop"), null);
assert.equal(pickPriceRule([{ service_id: 9, direction: null, mode: "standard", fixed_price: null, surcharge: 1 }], 3, "drop"), null);

const f = airportFare(svc, 25, 40, 150, rules[3], 0);
assert.equal(f.total, 8000 + 200 + 150);
assert.equal(f.airport_pricing, "fixed");
assert.equal(f.distance_charge, 0);

const std = airportFare(svc, 10, 20, 0, rules[0], 999);
assert.equal(std.airport_surcharge, 300);
assert.equal(std.total, 500 + 9 * 100 + 200 + 300);
assert.equal(airportFare(svc, 10, 20, 0, null, 250).airport_surcharge, 250);
assert.equal(airportFare(svc, 0.1, 1, 0, null, 0).total, 1000);

console.log("airport unit checks passed");
