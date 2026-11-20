import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import type { MiddlewareHandler } from "hono";
import { parseSessionCookie, validateSession } from "../lib/web-session";
import { readBody, validationFailed } from "../lib/legacy";
import { haversineKm } from "../lib/routing";
import { mapSettings } from "../lib/maps";

/** Place search and the passenger's saved places (Home, Work, others). */
export const placeRoutes = new Hono<AppEnv>();

/**
 * Browser sessions use the HttpOnly drop_session cookie, while mobile clients
 * use Bearer tokens. Allow either transport for authenticated place search.
 */
const requireWebOrBearer: MiddlewareHandler<AppEnv> = async (c, next) => {
  if (c.req.header("authorization")) return requireAuth(c, next);
  const parsed = parseSessionCookie(c);
  if (!parsed) return c.json({ message: "Unauthenticated.", status: 401 }, 401);
  const session = await validateSession(c.get("db"), parsed);
  if (!session) return c.json({ message: "Unauthenticated.", status: 401 }, 401);
  c.set("user", session.user);
  c.set("tokenId", session.tokenId);
  await next();
};

type Hit = { title: string; subtitle: string; lat: number; lng: number; distance_km: number | null };

/** Search for a place near the passenger. Google Places when Google is the active map, otherwise OpenStreetMap (Nominatim). */
placeRoutes.get("/places/search", withDb, requireWebOrBearer, async (c) => {
  const q = String(c.req.query("q") ?? "").trim().slice(0, 120);
  const lat = Number(c.req.query("lat")), lng = Number(c.req.query("lng"));
  const near = Number.isFinite(lat) && Number.isFinite(lng) && (lat !== 0 || lng !== 0) ? { lat, lng } : null;
  if (q.length < 2) return c.json({ data: [] });
  const s = await mapSettings(c.get("db"), c.env);
  let hits: Hit[] | null = null;

  if (s.active === "google" && c.env.GOOGLE_MAPS_SERVER_KEY) {
    try {
      const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Goog-Api-Key": c.env.GOOGLE_MAPS_SERVER_KEY, "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location" },
        body: JSON.stringify({
          textQuery: q,
          pageSize: 8,
          ...(near ? { locationBias: { circle: { center: { latitude: near.lat, longitude: near.lng }, radius: 30000 } } } : {}),
        }),
        signal: AbortSignal.timeout(4000),
      });
      if (res.ok) {
        const j = (await res.json()) as { places?: { displayName?: { text?: string }; formattedAddress?: string; location?: { latitude: number; longitude: number } }[] };
        hits = (j.places ?? []).filter((p) => p.location).map((p) => ({
          title: p.displayName?.text ?? p.formattedAddress ?? q,
          subtitle: p.formattedAddress ?? "",
          lat: p.location!.latitude,
          lng: p.location!.longitude,
          distance_km: null,
        }));
      }
    } catch { /* fall through to OpenStreetMap */ }
  }

  if (!hits) {
    try {
      const view = near ? `&viewbox=${near.lng - 0.4},${near.lat + 0.4},${near.lng + 0.4},${near.lat - 0.4}` : "";
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&addressdetails=0&q=${encodeURIComponent(q)}${view}`, {
        headers: { "User-Agent": "DROP-ride-hailing/1.0 (officialkryptonia.workers.dev)", "Accept-Language": "en" },
        signal: AbortSignal.timeout(4000),
      });
      if (res.ok) {
        const j = (await res.json()) as { display_name: string; name?: string; lat: string; lon: string }[];
        hits = j.map((p) => {
          const parts = p.display_name.split(",").map((x) => x.trim());
          return { title: p.name || parts[0], subtitle: parts.slice(1, 4).join(", "), lat: Number(p.lat), lng: Number(p.lon), distance_km: null };
        });
      }
    } catch { /* no results */ }
  }

  const out = (hits ?? []).map((h) => ({ ...h, distance_km: near ? Math.round(haversineKm(near, { lat: h.lat, lng: h.lng }) * 10) / 10 : null }));
  if (near) out.sort((a, b) => (a.distance_km ?? 0) - (b.distance_km ?? 0));
  return c.json({ data: out });
});

const placeBody = (b: Record<string, unknown>) => {
  const lat = Number(b.lat), lng = Number(b.lng);
  const address = String(b.address ?? "").trim().slice(0, 200);
  if (!address || !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng, address };
};

const shape = (r: Record<string, unknown>) => ({ id: Number(r.id), kind: r.kind, label: r.label, address: r.address, lat: Number(r.lat), lng: Number(r.lng) });

placeRoutes.get("/places/saved", withDb, requireAuth, async (c) => {
  const rows = (await c.get("db").query("select id, kind, label, address, lat, lng from app.saved_places where user_id = $1 order by kind desc, id", [c.get("user").id])).rows;
  return c.json({ data: rows.map(shape) });
});

/** Set or replace Home or Work. */
placeRoutes.put("/places/saved/:kind", withDb, requireAuth, async (c) => {
  const kind = c.req.param("kind");
  if (kind !== "home" && kind !== "work") return c.json({ message: "Not found", status: 404 }, 404);
  const p = placeBody(await readBody(c));
  if (!p) return validationFailed(c, { place: ["Choose a place first."] });
  const row = (await c.get("db").query(
    `insert into app.saved_places (user_id, kind, label, address, lat, lng) values ($1, $2, $3, $4, $5, $6)
     on conflict (user_id, kind) where kind in ('home', 'work') do update set address = excluded.address, lat = excluded.lat, lng = excluded.lng
     returning id, kind, label, address, lat, lng`,
    [c.get("user").id, kind, kind === "home" ? "Home" : "Work", p.address, p.lat, p.lng])).rows[0];
  return c.json({ data: shape(row) });
});

/** Another place with a name of the passenger's choice. Up to 10. */
placeRoutes.post("/places/saved", withDb, requireAuth, async (c) => {
  const b = await readBody(c);
  const p = placeBody(b);
  const label = String(b.label ?? "").trim().slice(0, 40) || p?.address.split(",")[0] || "";
  if (!p || !label) return validationFailed(c, { place: ["Choose a place first."] });
  const db = c.get("db");
  const n = Number((await db.query("select count(*) from app.saved_places where user_id = $1 and kind = 'other'", [c.get("user").id])).rows[0].count);
  if (n >= 10) return c.json({ message: "You can save up to 10 other places. Remove one first.", status: 422 }, 422);
  const row = (await db.query("insert into app.saved_places (user_id, kind, label, address, lat, lng) values ($1, 'other', $2, $3, $4, $5) returning id, kind, label, address, lat, lng", [c.get("user").id, label, p.address, p.lat, p.lng])).rows[0];
  return c.json({ data: shape(row) });
});

placeRoutes.delete("/places/saved/:id", withDb, requireAuth, async (c) => {
  await c.get("db").query("delete from app.saved_places where id = $1 and user_id = $2", [c.req.param("id"), c.get("user").id]);
  return c.json({ message: "Removed." });
});
