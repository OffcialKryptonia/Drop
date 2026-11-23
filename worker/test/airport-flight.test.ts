import { strict as assert } from "node:assert";
import { DEFAULT_FLIGHT_FIELDS, driverFlight, mergeConfig, validateFlight } from "../src/lib/airport-flight";

const terms = [{ name: "Terminal 1" }, { name: "Terminal 2" }];
const cfg = mergeConfig(undefined);

// defaults: pickup needs flight number and terminal
let r = validateFlight(cfg, "pickup", {}, terms);
assert.ok(!r.ok && r.errors.flight_number && r.errors.terminal);
r = validateFlight(cfg, "pickup", { flight_number: "kq 530", terminal: "terminal 2", passenger_count: 2, luggage_count: "1", arrival_time: "07:45", arrival_date: "2026-12-01" }, terms);
assert.ok(r.ok && r.flight.flight_number === "KQ530" && r.flight.terminal === "Terminal 2" && r.flight.passenger_count === 2 && r.flight.luggage_count === 1);

// drop: nothing required by default; disabled fields are dropped
r = validateFlight(cfg, "drop", { arrival_date: "2026-12-01", airline: "X", passenger_count: 3 }, terms);
assert.ok(r.ok && r.flight.arrival_date === undefined && r.flight.airline === undefined && r.flight.passenger_count === 3);

// shape checks
for (const bad of [{ flight_number: "???", terminal: "Terminal 1" }, { flight_number: "KQ530", terminal: "Terminal 9" }, { flight_number: "KQ530", terminal: "Terminal 1", arrival_date: "2026-02-30" },
  { flight_number: "KQ530", terminal: "Terminal 1", arrival_time: "25:00" }, { flight_number: "KQ530", terminal: "Terminal 1", passenger_count: 0 }, { flight_number: "KQ530", terminal: "Terminal 1", contact_phone: "abc" }])
  assert.ok(!validateFlight(cfg, "pickup", bad, terms).ok, JSON.stringify(bad));

// airport with no listed terminals accepts free text
assert.ok(validateFlight(cfg, "pickup", { flight_number: "KQ530", terminal: "Arrivals hall" }, []).ok);

// admin changes apply: make drop flight number off, pickup contact required; a required field cannot be disabled
const custom = mergeConfig({ drop: { flight_number: { enabled: false, required: false } }, pickup: { contact_phone: { enabled: false, required: true }, flight_number: { enabled: true, required: false } } });
assert.equal(custom.drop.flight_number.enabled, false);
assert.deepEqual(custom.pickup.contact_phone, { enabled: true, required: true });
assert.ok(!validateFlight(custom, "pickup", { terminal: "Terminal 1" }, terms).ok);
assert.ok(validateFlight(custom, "pickup", { terminal: "Terminal 1", contact_phone: "+2348012345678" }, terms).ok);
assert.deepEqual(mergeConfig("junk"), DEFAULT_FLIGHT_FIELDS);

// drivers never receive a phone number
assert.deepEqual(driverFlight({ flight_number: "KQ530", contact_phone: "0801" }), { flight_number: "KQ530", has_contact: true });
assert.equal(driverFlight(null), null);
console.log("airport flight checks passed");
