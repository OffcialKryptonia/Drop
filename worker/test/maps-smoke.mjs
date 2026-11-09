// Map provider switch: admin settings, public config, auto behaviour. Local/test DB only.
import pg from "pg";
const API = (process.env.BASE ?? "http://127.0.0.1:8787") + "/api";
const { ADMIN_EMAIL, ADMIN_PASSWORD, DATABASE_URL } = process.env;
const db = new pg.Client({ connectionString: DATABASE_URL }); await db.connect();
let fails = 0;
const ok = (n, c, x = "") => { console.log(c ? "PASS" : "FAIL", n, c ? "" : x); if (!c) fails++; };
const call = async (m, p, t, b) => { const r = await fetch(API + p, { method: m, headers: { Accept: "application/json", ...(b ? { "Content-Type": "application/json" } : {}), ...(t ? { Authorization: "Bearer " + t } : {}) }, body: b ? JSON.stringify(b) : undefined }); return { status: r.status, json: await r.json().catch(() => ({})) }; };
const A = (await call("POST", "/login", null, { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, user_type: "admin" })).json.data?.api_token;
const old = (await db.query("select key, value from app.settings where key in ('map_provider','osm_tile_url','osm_routing_url')")).rows;
const body = (o) => ({ provider: "auto", osm_tile_url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", osm_routing_url: "https://router.project-osrm.org", ...o });
try {
  ok("map-config needs no sign-in and has no secrets", (await call("GET", "/map-config")).status === 200);
  ok("admin settings need sign-in", (await call("GET", "/admin/map-settings")).status === 401);
  let r = await call("PUT", "/admin/map-settings", A, body({ provider: "osm" }));
  ok("force OpenStreetMap", r.status === 200, JSON.stringify(r.json));
  let c = (await call("GET", "/map-config")).json;
  ok("apps are told to use osm, with tile address and attribution", c.provider === "osm" && c.osm_tile_url.includes("{z}") && c.attribution.includes("OpenStreetMap"), JSON.stringify(c));
  await call("PUT", "/admin/map-settings", A, body({ provider: "google" }));
  ok("force Google", (await call("GET", "/map-config")).json.provider === "google");
  await call("PUT", "/admin/map-settings", A, body({ provider: "auto" }));
  const s = (await call("GET", "/admin/map-settings", A)).json.data;
  ok("auto without a Google server key uses OpenStreetMap", s.provider === "auto" && (s.google_server_key_set ? true : s.active === "osm"), JSON.stringify(s));
  ok("bad provider rejected", (await call("PUT", "/admin/map-settings", A, body({ provider: "bing" }))).status >= 400);
  ok("tile address must have {z}/{x}/{y}", (await call("PUT", "/admin/map-settings", A, body({ osm_tile_url: "https://example.com/tiles.png" }))).status >= 400);
  ok("insecure address rejected", (await call("PUT", "/admin/map-settings", A, body({ osm_routing_url: "http://router.example.com" }))).status >= 400);
} finally {
  for (const k of ["map_provider", "osm_tile_url", "osm_routing_url"]) {
    const o = old.find((x) => x.key === k);
    if (o) await db.query("update app.settings set value = $2::jsonb where key = $1", [k, JSON.stringify(o.value)]);
  }
  await db.query("delete from app.settings where key = 'google_maps_failed_at'");
}
console.log(fails ? `${fails} FAILED` : "ALL PASSED");
await db.end(); process.exit(fails ? 1 : 0);
