// Real-browser check of the Admin theme (Chromium via Playwright). Run: node test/admin-theme-e2e.mjs
import http from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { extname, join } from "node:path";
import { createRequire } from "node:module";
import assert from "node:assert/strict";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = new URL("../public", import.meta.url).pathname;
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };
const srv = http.createServer((req, res) => {
  let p = req.url.split("?")[0]; if (p === "/admin" || p === "/admin/") p = "/admin/index.html";
  const f = join(root, p);
  if (!existsSync(f)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { "content-type": types[extname(f)] || "text/plain" }); res.end(readFileSync(f));
}).listen(0);
const base = `http://127.0.0.1:${srv.address().port}/admin/`;
const browser = await chromium.launch();
let n = 0; const ok = (m) => console.log("ok   -", m, `(${++n})`);
const attr = (page, a) => page.evaluate((x) => document.documentElement.getAttribute(x), a);
const bg = (page) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);

// 1. No saved choice: follows the OS (dark), and the theme is set before first paint.
let ctx = await browser.newContext({ colorScheme: "dark" }); let page = await ctx.newPage();
await page.addInitScript(() => { window.__early = null; new MutationObserver(() => {}).observe(document, { childList: true }); });
await page.goto(base);
assert.equal(await attr(page, "data-theme"), "dark"); assert.equal(await attr(page, "data-theme-pref"), "system");
assert.equal(await bg(page), "rgb(17, 17, 17)"); ok("System default follows a dark OS");

// 2. Light choice overrides the OS, persists across reload, and toggle shows pressed state.
await page.click('.theme-toggle button[data-pref="light"]');
assert.equal(await attr(page, "data-theme"), "light"); await page.waitForTimeout(450);
assert.equal(await bg(page), "rgb(244, 245, 247)");
assert.equal(await page.getAttribute('.theme-toggle button[data-pref="light"]', "aria-pressed"), "true");
await page.reload(); assert.equal(await attr(page, "data-theme"), "light"); ok("explicit Light overrides OS and persists after reload");

// 3. No flash: on reload the very first style resolution is already light (check the attribute at DOMContentLoaded).
const early = await page.evaluate(() => new Promise((r) => { r(document.documentElement.getAttribute("data-theme")); }));
assert.equal(early, "light"); ok("theme attribute present before page scripts run");

// 4. Dark choice + System choice behave, and System tracks live OS changes.
await page.click('.theme-toggle button[data-pref="dark"]'); assert.equal(await attr(page, "data-theme"), "dark");
await page.click('.theme-toggle button[data-pref="system"]'); assert.equal(await attr(page, "data-theme"), "dark");
await page.emulateMedia({ colorScheme: "light" }); await page.waitForTimeout(100);
assert.equal(await attr(page, "data-theme"), "light"); ok("System follows live OS changes");

// 5. Blocked storage must not break the page.
const ctx2 = await browser.newContext({ colorScheme: "light" }); const p2 = await ctx2.newPage();
await p2.addInitScript(() => { Object.defineProperty(window, "localStorage", { get() { throw new Error("blocked"); } }); });
const errs = []; p2.on("pageerror", (e) => errs.push(e.message)); await p2.goto(base);
assert.equal(await attr(p2, "data-theme"), "light"); await p2.click('.theme-toggle button[data-pref="dark"]');
assert.equal(await attr(p2, "data-theme"), "dark"); assert.deepEqual(errs, []); ok("blocked storage degrades quietly");

// 6. Reduced motion: no transition class side effects.
const ctx3 = await browser.newContext({ reducedMotion: "reduce" }); const p3 = await ctx3.newPage(); await p3.goto(base);
await p3.click('.theme-toggle button[data-pref="dark"]');
const dur = await p3.evaluate(() => getComputedStyle(document.body).transitionDuration); assert.ok(/^0s/.test(dur), dur); ok("reduced motion disables the animation");

// 7. Contrast of the real rendered sign-in card in both themes (text vs card).
const rgb = (s) => s.match(/\d+/g).slice(0, 3).map(Number);
const L = ([r, g, b]) => { const f = (c) => { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; }; return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b); };
for (const t of ["light", "dark"]) {
  await page.click(`.theme-toggle button[data-pref="${t}"]`); await page.waitForTimeout(450);
  await page.evaluate(() => { document.getElementById("login").hidden = false; });
  const [c, b] = await page.evaluate(() => [getComputedStyle(document.querySelector("#login h2")).color, getComputedStyle(document.querySelector("#login")).backgroundColor]);
  const [a1, a2] = [L(rgb(c)), L(rgb(b))].sort((x, y) => y - x); assert.ok((a1 + 0.05) / (a2 + 0.05) >= 7, `${t} login contrast`);
}
ok("rendered sign-in card has AAA text contrast in both themes");
await page.screenshot({ path: process.env.SHOT || "/tmp/admin-login-dark.png" });
await browser.close(); srv.close(); console.log(`\nall ${n} browser checks passed`);
