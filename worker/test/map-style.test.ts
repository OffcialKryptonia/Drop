// The hosted dark map style used by the MapLibre / OpenStreetMap map. Run: npx tsx test/map-style.test.ts
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const style = JSON.parse(readFileSync(new URL("../public/map-styles/drop-dark.json", import.meta.url), "utf8"));
const text = JSON.stringify(style);
const lum = (hex: string) => { const n = hex.replace("#", ""); const v = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)); return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]; };

const tests: [string, () => void][] = [
  ["is a version 8 style with layers and unique layer ids", () => {
    assert.equal(style.version, 8); assert.ok(style.layers.length > 20);
    const ids = style.layers.map((l: any) => l.id); assert.equal(new Set(ids).size, ids.length);
  }],
  ["needs no API key and calls no paid third party", () => {
    assert.ok(!/maptiler|\{key\}|access_token|mapbox\.com/i.test(text));
    assert.equal(style.sources.openmaptiles.url, "https://tiles.openfreemap.org/planet");
    assert.ok(style.glyphs.startsWith("https://tiles.openfreemap.org/fonts/"));
  }],
  ["every layer's source exists and every font is one OpenFreeMap serves", () => {
    const ok = new Set(["Noto Sans Regular", "Noto Sans Italic", "Noto Sans Bold"]);
    for (const l of style.layers) {
      if (l.source) assert.ok(style.sources[l.source], `layer ${l.id} source`);
      for (const f of l.layout?.["text-font"] ?? []) assert.ok(ok.has(f), `${l.id} font ${f}`);
    }
  }],
  ["the background is genuinely dark", () => {
    const bg = style.layers.find((l: any) => l.type === "background");
    const m = String(bg.paint["background-color"]).match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
    assert.ok(m, "expected an rgb() background");
    assert.ok(lum("#" + [1, 2, 3].map((i) => Number(m![i]).toString(16).padStart(2, "0")).join("")) < 0.05);
  }],
  ["credits the data and style sources", () => {
    assert.ok(/OpenStreetMap/.test(style.sources.openmaptiles.attribution)); assert.ok(/OpenMapTiles/.test(style.metadata.attribution));
  }],
];
let failed = 0;
for (const [n, fn] of tests) { try { fn(); console.log("ok   -", n); } catch (e) { failed++; console.log("FAIL -", n, (e as Error).message); } }
if (failed) process.exit(1);
console.log(`\nall ${tests.length} map style checks passed`);
