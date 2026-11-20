// Pure pickup-code maths, no database. Run: npx tsx test/pickup.test.ts
import assert from "node:assert/strict";
import { randomCode, sameText, startAllowedSql } from "../src/lib/pickup";
import { decryptValue, encryptValue } from "../src/lib/crypto";

const tests: [string, () => void | Promise<void>][] = [
  ["codes are always four digits", () => {
    for (let i = 0; i < 2000; i++) assert.match(randomCode(), /^\d{4}$/);
  }],
  ["codes are spread over the whole range (not stuck or biased)", () => {
    const seen = new Set<string>();
    let low = 0;
    for (let i = 0; i < 5000; i++) { const c = randomCode(); seen.add(c); if (Number(c) < 5000) low++; }
    assert.ok(seen.size > 3000, `only ${seen.size} different codes`);
    assert.ok(low > 2300 && low < 2700, `low half count ${low}`);
  }],
  ["comparison is exact", () => {
    assert.equal(sameText("abcd", "abcd"), true);
    assert.equal(sameText("abcd", "abce"), false);
    assert.equal(sameText("abcd", "abc"), false);
  }],
  ["the code survives encryption for the passenger's screen", async () => {
    const secret = "x".repeat(40);
    const enc = await encryptValue("4827", secret);
    assert.notEqual(enc, "4827");
    assert.equal(await decryptValue(enc, secret), "4827");
  }],
  ["start guard uses the given parameter and checks verified or overridden", () => {
    const sql = startAllowedSql(5);
    assert.ok(sql.includes("$5::boolean"));
    assert.ok(sql.includes("verified_at is not null") && sql.includes("overridden_at is not null"));
  }],
];

let failed = 0;
for (const [name, fn] of tests) {
  try { await fn(); console.log("ok -", name); } catch (e) { failed++; console.log("FAIL -", name, (e as Error).message); }
}
if (failed) process.exit(1);
