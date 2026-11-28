// Phase 7 pure logic: incident rules and masking, period parsing, rates, money grouping, cohort maturity, online time, CSV safety,
// and a static check that every state-changing admin route writes an audit row. Run: npx tsx test/safety-analytics.test.ts
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import {
  INCIDENT_STATUSES, TRANSITIONS, canTransition, incidentView, isActive, maskName, approxCoord, needsNote, STATUS_LABEL, CATEGORIES, SEVERITIES,
} from "../src/lib/safety-center";
import { avg, cohortMature, csvCell, freqBucket, moneyList, onlineSeconds, parsePeriod, rate, round2, toCsv, validTz } from "../src/lib/analytics";

let n = 0;
const t = (name: string, fn: () => void) => { fn(); n++; console.log("PASS", name); };

// ---- incidents
t("six states with plain labels, stored 'open' shows as New", () => {
  assert.deepEqual([...INCIDENT_STATUSES], ["open", "acknowledged", "investigating", "escalated", "resolved", "closed"]);
  assert.equal(STATUS_LABEL.open, "New");
  assert.equal(CATEGORIES.length, 9); assert.equal(SEVERITIES.length, 4);
});
t("closed is final and nothing moves backwards to New", () => {
  assert.deepEqual(TRANSITIONS.closed, []);
  for (const s of INCIDENT_STATUSES) assert.ok(!canTransition(s, "open"), `${s} -> open`);
});
t("only listed transitions are allowed, and unknown values never are", () => {
  assert.ok(canTransition("open", "acknowledged")); assert.ok(canTransition("resolved", "closed")); assert.ok(canTransition("resolved", "investigating"));
  assert.ok(!canTransition("open", "closed")); assert.ok(!canTransition("escalated", "acknowledged")); assert.ok(!canTransition("closed", "resolved"));
  assert.ok(!canTransition("bogus", "open")); assert.ok(!canTransition("open", "bogus"));
  for (const s of INCIDENT_STATUSES) for (const to of INCIDENT_STATUSES) assert.equal(canTransition(s, to), TRANSITIONS[s].includes(to));
});
t("every non-closed state can reach Closed", () => {
  for (const s of INCIDENT_STATUSES) {
    const seen = new Set<string>([s]); const q = [s];
    while (q.length) for (const nx of TRANSITIONS[q.shift() as typeof s]) if (!seen.has(nx)) { seen.add(nx); q.push(nx); }
    assert.ok(seen.has("closed"), `${s} cannot reach closed`);
  }
});
t("resolving and escalating need a note; active means not resolved or closed", () => {
  assert.ok(needsNote("resolved") && needsNote("escalated") && !needsNote("acknowledged"));
  assert.ok(isActive("open") && isActive("escalated") && !isActive("resolved") && !isActive("closed"));
});
t("names are masked to first name and last initial", () => {
  assert.equal(maskName("Ada Obi"), "Ada O."); assert.equal(maskName("Ada Chidi Obi"), "Ada O."); assert.equal(maskName("Ada"), "Ada");
  assert.equal(maskName(""), "Unknown"); assert.equal(maskName(null), "Unknown"); assert.equal(maskName("  Ngozi   okafor "), "Ngozi O.");
});
t("coordinates are rounded to about a kilometre", () => {
  assert.equal(approxCoord(9.0765123), 9.08); assert.equal(approxCoord("7.3986456"), 7.4); assert.equal(approxCoord(null), null); assert.equal(approxCoord("x"), null);
});
t("the incident view hides the surname and exact place and never carries a phone", () => {
  const row = { id: 5, status: "open", category: "sos", severity: "high", source: "app", role: "rider", ride_request_id: 9, latitude: 9.0765123, longitude: 7.3986456, message: "help",
    created_at: new Date().toISOString(), context: { person: { name: "Ada Obi", phone: "+2348031234567" }, other_party: { name: "Tunde Bello", phone: "+2348039999999" } } };
  const v = incidentView(row, { pii: false });
  const s = JSON.stringify(v);
  assert.equal(v.person.name, "Ada O."); assert.equal(v.other_party?.name, "Tunde B.");
  assert.ok(!s.includes("803") && !s.includes("9.0765123") && !s.includes("Obi") && !s.includes("Bello"));
  assert.deepEqual(v.location, { approximate: true, lat: 9.08, lng: 7.4 });
  assert.equal(incidentView({ ...row, latitude: null, longitude: null }, { pii: false }).location, null);
});

// ---- periods
const NOW = Date.parse("2026-11-28T10:00:00Z");
t("a missing period is the last 30 days including today, in Lagos time", () => {
  const p = parsePeriod({}, NOW) as { from: string; to: string; days: number; tz: string; defaulted: boolean };
  assert.equal(p.to, "2026-11-28"); assert.equal(p.from, "2026-10-30"); assert.equal(p.days, 30); assert.equal(p.tz, "Africa/Lagos"); assert.ok(p.defaulted);
});
t("23:30 UTC is already the next day in Lagos (UTC+1)", () => {
  assert.equal((parsePeriod({}, Date.parse("2026-11-28T23:30:00Z")) as { to: string }).to, "2026-11-29");
});
t("an explicit period is inclusive of both ends", () => {
  const p = parsePeriod({ from: "2026-11-01", to: "2026-11-30" }, NOW) as { days: number };
  assert.equal(p.days, 30);
  assert.equal((parsePeriod({ from: "2026-11-05", to: "2026-11-05" }, NOW) as { days: number }).days, 1);
});
t("bad dates, reversed ranges and over-long ranges are refused, not guessed", () => {
  for (const q of [{ from: "nope", to: "2026-11-01" }, { from: "2026-02-30", to: "2026-03-01" }, { from: "2026-11-02", to: "2026-11-01" }, { from: "2024-01-01", to: "2026-01-01" }, { from: "2026-11-01", to: "11/30/2026" }])
    assert.ok("error" in (parsePeriod(q, NOW) as object), JSON.stringify(q));
  assert.ok(!("error" in (parsePeriod({ from: "2026-01-01", to: "2026-12-31" }, NOW) as object)));
});
t("an unknown time zone falls back to Lagos", () => {
  assert.equal(validTz("Not/AZone"), "Africa/Lagos"); assert.equal(validTz("Europe/London"), "Europe/London"); assert.equal(validTz(undefined), "Africa/Lagos");
});

// ---- rates and money
t("rates are null with nothing to divide, never 0%", () => {
  assert.equal(rate(0, 0), null); assert.equal(rate(0, 5), 0); assert.equal(rate(1, 3), 33.33); assert.equal(rate(5, 5), 100);
  assert.equal(avg(0, 0), null); assert.equal(avg(9, 2), 4.5); assert.equal(round2("12.345"), 12.35); assert.equal(round2(undefined), 0);
});
t("money is grouped by currency and never mixed", () => {
  assert.deepEqual(moneyList([{ currency: "NGN", amount: 100.5 }, { currency: "USD", amount: 3 }, { currency: "NGN", amount: 50 }, { currency: " NGN ", amount: 0.25 }]),
    [{ currency: "NGN", amount: 150.75 }, { currency: "USD", amount: 3 }]);
  assert.deepEqual(moneyList([]), []); assert.deepEqual(moneyList([{ amount: 5 }]), [{ currency: "NGN", amount: 5 }]);
});
t("trip frequency buckets", () => {
  assert.deepEqual([1, 2, 3, 4, 9, 10, 40].map(freqBucket), ["1", "2-3", "2-3", "4-9", "4-9", "10+", "10+"]);
});
t("a retention cohort is reported only after everyone has had the whole window", () => {
  assert.ok(!cohortMature("2026-11-30", 30, "2026-12-15"));
  assert.ok(!cohortMature("2026-11-30", 30, "2026-12-30"));
  assert.ok(cohortMature("2026-11-30", 30, "2026-12-31"));
  assert.ok(cohortMature("2026-10-31", 30, "2026-12-01"));
});

// ---- online time
t("online time is clipped to the window and open sessions count to now", () => {
  const H = 3600_000, base = Date.parse("2026-11-28T00:00:00Z");
  assert.equal(onlineSeconds([{ started_at: base, ended_at: base + 2 * H }], base, base + 24 * H, base + 24 * H), 7200);
  assert.equal(onlineSeconds([{ started_at: base - H, ended_at: base + H }], base, base + 24 * H, base + 24 * H), 3600);
  assert.equal(onlineSeconds([{ started_at: base + 22 * H, ended_at: null }], base, base + 24 * H, base + 23 * H), 3600);
  assert.equal(onlineSeconds([{ started_at: base + 22 * H, ended_at: null }], base, base + 24 * H, base + 30 * H), 7200);
  assert.equal(onlineSeconds([{ started_at: base + 30 * H, ended_at: null }], base, base + 24 * H, base + 30 * H), 0);
  assert.equal(onlineSeconds([], base, base + H, base), 0);
});

// ---- CSV
t("CSV neutralises formulas and quotes properly", () => {
  assert.equal(csvCell("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\""); assert.equal(csvCell("+234"), "'+234"); assert.equal(csvCell("-1+1"), "'-1+1");
  assert.equal(csvCell("@sum"), "'@sum"); assert.equal(csvCell("\tx"), "'\tx");
  assert.equal(csvCell(-5), "-5"); assert.equal(csvCell(12.5), "12.5"); assert.equal(csvCell(null), ""); assert.equal(csvCell(undefined), "");
  assert.equal(csvCell("a,b"), "\"a,b\""); assert.equal(csvCell("line\nbreak"), "\"line\nbreak\""); assert.equal(csvCell(new Date("2026-11-28T00:00:00Z")), "2026-11-28T00:00:00.000Z");
});
t("a CSV has a header row, CRLF line ends and one line per row", () => {
  const out = toCsv([{ key: "a", label: "A" }, { key: "b", label: "B" }], [{ a: 1, b: "x" }, { a: 2, b: "=1" }]);
  assert.ok(out.startsWith("﻿A,B\r\n")); assert.equal(out.trim().split("\r\n").length, 3); assert.ok(out.includes("2,'=1"));
});

// ---- every state-changing admin route writes an audit row
t("each state-changing /admin route handler records an audit entry", () => {
  const dir = new URL("../src/routes/", import.meta.url);
  // Not sensitive actions: one-time setup protected by a bootstrap token, and route-level estimates that change nothing.
  const exempt = new Set([
    "/admin/bootstrap", "/admin/order-ride/estimate", "/admin/email-templates/preview", "/admin/push-templates/preview", // setup token / previews: change nothing
    // These hand the work to a shared helper that writes the audit row; the integration smoke tests assert the row exists.
    "/admin/airports", "/admin/airports/:id", "/admin/roles", "/admin/roles/:id",
    "/admin/ops/rides/:id/assign", "/admin/ops/rides/:id/reassign", "/admin/ops/rides/:id/cancel",
    "/admin/safety/incidents/:id/status", "/admin/safety/incidents/:id/assign", "/admin/safety/incidents/:id/classify", "/admin/safety/incidents/:id/notes",
    "/admin-sos-notify", // a rider/driver action, not an admin one
  ]);
  const missing: string[] = [];
  for (const f of readdirSync(dir).filter((x) => x.endsWith(".ts"))) {
    const src = readFileSync(new URL(f, dir), "utf8");
    const re = /\.(post|put|patch|delete)\(\s*"(\/admin[^"]*)"/g;
    const hits = [...src.matchAll(re)];
    const starts = [...src.matchAll(/^\w+\.(get|post|put|patch|delete)\(/gm)].map((m) => m.index as number);
    for (const h of hits) {
      if (exempt.has(h[2])) continue;
      const at = h.index as number;
      const end = starts.find((s) => s > at) ?? src.length;
      const body = src.slice(at, end);
      if (!/\baudit\(|admin_audit|audit[A-Z]\w*\(/.test(body)) missing.push(`${f}: ${h[1].toUpperCase()} ${h[2]}`);
    }
  }
  assert.deepEqual(missing, [], "state-changing admin routes without an audit entry:\n" + missing.join("\n"));
});

console.log(`\n${n} passed`);
