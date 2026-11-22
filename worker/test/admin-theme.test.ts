// Admin theme: pure logic and stylesheet checks, no browser. Run: npx tsx test/admin-theme.test.ts
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const theme = require("../public/admin/theme.js");
const css = readFileSync(new URL("../public/admin/admin.css", import.meta.url), "utf8");
const html = readFileSync(new URL("../public/admin/index.html", import.meta.url), "utf8");
const js = readFileSync(new URL("../public/admin/admin.js", import.meta.url), "utf8");

function block(selector: string): Record<string, string> {
  const start = css.indexOf(selector + " {");
  assert.ok(start >= 0, `missing ${selector}`);
  const body = css.slice(css.indexOf("{", start) + 1, css.indexOf("}", start));
  const out: Record<string, string> = {};
  for (const m of body.matchAll(/--([\w-]+):\s*([^;]+);/g)) out[m[1]] = m[2].trim();
  return out;
}
function lum(hex: string) {
  const n = hex.replace("#", ""); const v = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
}
const ratio = (a: string, b: string) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };

const light = block(":root");
const dark = { ...light, ...block(':root[data-theme="dark"]') };

const tests: [string, () => void][] = [
  ["unknown or missing preferences fall back to System", () => {
    for (const v of [null, undefined, "", "blue", "DARK", 3]) assert.equal(theme.normalize(v), "system");
    for (const v of ["light", "dark", "system"]) assert.equal(theme.normalize(v), v);
  }],
  ["System follows the OS, explicit choices ignore it", () => {
    assert.equal(theme.resolve("system", true), "dark");
    assert.equal(theme.resolve("system", false), "light");
    assert.equal(theme.resolve("light", true), "light");
    assert.equal(theme.resolve("dark", false), "dark");
  }],
  ["both themes define every colour token the stylesheet uses", () => {
    const used = new Set([...css.matchAll(/var\(--([\w-]+)/g)].map((m) => m[1]));
    for (const t of used) { assert.ok(light[t], `light lacks --${t}`); assert.ok(dark[t], `dark lacks --${t}`); }
  }],
  ["text, muted text and links meet WCAG AA (4.5:1) on page and card backgrounds in both themes", () => {
    for (const [name, p] of [["light", light], ["dark", dark]] as const) {
      for (const fg of ["text", "muted", "link"]) for (const bg of ["bg", "card", "input"]) {
        const r = ratio(p[fg], p[bg]);
        assert.ok(r >= 4.5, `${name}: --${fg} on --${bg} is ${r.toFixed(2)}:1`);
      }
      for (const fg of ["ok", "bad"]) assert.ok(ratio(p[fg], p.card) >= 4.5, `${name}: --${fg} on card`);
      assert.ok(ratio(p.ok, p["msg-ok-bg"]) >= 4.5 && ratio(p.bad, p["msg-err-bg"]) >= 4.5, `${name}: message banners`);
    }
  }],
  ["no hardcoded colours remain outside the theme token blocks (rgba shadows excepted)", () => {
    const outside = css.slice(css.indexOf("* { box-sizing"));
    const hex = [...outside.matchAll(/#[0-9a-fA-F]{3,8}\b/g)].map((m) => m[0].toLowerCase());
    // #fff on accent-gradient chips, the map vertex marker and the .mark logo are brand-fixed.
    const allowed = new Set(["#fff", "#fc9600"]);
    assert.deepEqual(hex.filter((h) => !allowed.has(h)), []);
  }],
  ["admin.js has no light-only inline colours", () => {
    assert.ok(!/var\(--line,#eee\)/.test(js));
    assert.ok(!/background:#f1f1f1/.test(js));
  }],
  ["page loads the theme script in <head> before the stylesheet, and has a toggle slot on sign-in and in the app", () => {
    assert.ok(html.indexOf("/admin/theme.js") > 0 && html.indexOf("/admin/theme.js") < html.indexOf("/admin/admin.css"));
    assert.ok(html.indexOf("/admin/theme.js") < html.indexOf("</head>"));
    assert.equal((html.match(/class="theme-slot"/g) || []).length, 2);
  }],
  ["reduced-motion users get no theme animation", () => {
    assert.ok(/prefers-reduced-motion: reduce\) \{ html\.theme-anim/.test(css));
  }],
  ["storage failures never throw", () => {
    // In Node there is no window.localStorage; read/write must degrade quietly.
    assert.equal(theme.read(), "system");
    assert.doesNotThrow(() => theme.write("dark"));
  }],
];

let failed = 0;
for (const [name, fn] of tests) {
  try { fn(); console.log("ok   -", name); } catch (e) { failed++; console.log("FAIL -", name, "\n      ", (e as Error).message); }
}
if (failed) { console.log(`\n${failed} of ${tests.length} failed`); process.exit(1); }
console.log(`\nall ${tests.length} admin theme checks passed`);
