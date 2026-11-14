import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { mapSettings } from "../lib/maps";

export const mapRoutes = new Hono<AppEnv>();

/** What the app needs to draw its map. No sign-in needed: it contains no secrets. */
mapRoutes.get("/map-config", withDb, async (c) => {
  const s = await mapSettings(c.get("db"), c.env);
  const origin = new URL(c.req.url).origin;
  const icons = (await c.get("db").query("select key, version from app.map_icons where file_key is not null")).rows;
  return c.json({
    status: true,
    provider: s.active,
    osm_tile_url: s.osm_tile_url,
    attribution: "© OpenStreetMap contributors",
    /** Admin-uploaded vehicle pictures by key. Keys not listed use the icons bundled in the app. */
    vehicle_icons: Object.fromEntries(icons.map((r) => [r.key, `${origin}/api/map-icons/${r.key}/image?v=${r.version}`])),
  });
});

mapRoutes.get("/admin/map-settings", ...guard("map_settings list"), async (c) => c.json({ data: await mapSettings(c.get("db"), c.env) }));

mapRoutes.put("/admin/map-settings", ...guard("map_settings edit"), async (c) => {
  const p = z
    .object({
      provider: z.enum(["auto", "google", "osm"]),
      osm_tile_url: z.string().trim().url().max(300).refine((u) => u.startsWith("https://") && u.includes("{z}") && u.includes("{x}") && u.includes("{y}"), "Use an https:// tile address containing {z}, {x} and {y}."),
      osm_routing_url: z.string().trim().url().max(300).refine((u) => u.startsWith("https://"), "Use an https:// address."),
    })
    .safeParse(await readBody(c));
  if (!p.success) {
    const errors: Record<string, string[]> = {};
    for (const i of p.error.issues) (errors[String(i.path[0] ?? "map")] ??= []).push(i.message);
    return validationFailed(c, errors);
  }
  const db = c.get("db");
  for (const [k, v] of Object.entries({ map_provider: p.data.provider, osm_tile_url: p.data.osm_tile_url, osm_routing_url: p.data.osm_routing_url })) {
    await db.query("insert into app.settings (key, value) values ($1, to_jsonb($2::text)) on conflict (key) do update set value = excluded.value", [k, v]);
  }
  // A forced choice or a fresh save clears the remembered Google failure so "auto" tries Google again.
  await db.query("delete from app.settings where key = 'google_maps_failed_at'");
  await audit(c, "map_settings", "map_provider", { provider: p.data.provider });
  return c.json({ message: "Saved" });
});
