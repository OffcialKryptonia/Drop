import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { decryptValue, encryptValue } from "../lib/crypto";
import { DEFAULT_MAPBOX_STYLE, mapSettings } from "../lib/maps";

export const mapRoutes = new Hono<AppEnv>();
async function saveSetting(db: import("pg").Client, key: string, value: string) {
  await db.query("insert into app.settings (key, value) values ($1, to_jsonb($2::text)) on conflict (key) do update set value = excluded.value", [key, value]);
}

/** Public map configuration contains only a restricted public Mapbox token, never an sk. secret. */
mapRoutes.get("/map-config", withDb, async (c) => {
  const s = await mapSettings(c.get("db"), c.env);
  const origin = new URL(c.req.url).origin;
  const icons = (await c.get("db").query("select key, version from app.map_icons where file_key is not null")).rows;
  return c.json({
    status: true, provider: s.active, osm_tile_url: s.osm_tile_url,
    attribution: s.active === "mapbox" ? "© Mapbox" : "© OpenStreetMap contributors",
    mapbox_style_uri: s.active === "mapbox" ? s.mapbox_style_uri : null,
    mapbox_public_token: s.active === "mapbox" ? s.mapbox_public_token : null,
    mapbox_region_bordering_enabled: s.mapbox_region_bordering_enabled,
    mapbox_fallback_reason: s.fallback_reason,
    vehicle_icons: Object.fromEntries(icons.map((r) => [r.key, origin + "/api/map-icons/" + r.key + "/image?v=" + r.version])),
  });
});

mapRoutes.get("/admin/map-settings", ...guard("map_settings list"), async (c) => {
  const s = await mapSettings(c.get("db"), c.env);
  const { mapbox_public_token: _token, ...safe } = s;
  return c.json({ data: safe, encryption_configured: (c.env.SETTINGS_ENCRYPTION_KEY ?? "").length >= 32 });
});

const updateSchema = z.object({
  provider: z.enum(["auto", "google", "osm", "mapbox"]),
  osm_tile_url: z.string().trim().url().max(300).refine((u) => u.startsWith("https://") && u.includes("{z}") && u.includes("{x}") && u.includes("{y}"), "Use an https:// tile address containing {z}, {x} and {y}."),
  osm_routing_url: z.string().trim().url().max(300).refine((u) => u.startsWith("https://"), "Use an https:// address."),
  mapbox_enabled: z.boolean().optional(),
  mapbox_region_bordering_enabled: z.boolean().optional(),
  mapbox_style_uri: z.string().trim().max(300).refine((u) => u === "" || u.startsWith("mapbox://styles/"), "Use a Mapbox style URI such as mapbox://styles/mapbox/streets-v12.").optional(),
  mapbox_public_token: z.string().trim().max(500).nullable().optional(),
});

mapRoutes.put("/admin/map-settings", ...guard("map_settings edit"), async (c) => {
  const p = updateSchema.safeParse(await readBody(c));
  if (!p.success) {
    const errors: Record<string, string[]> = {};
    for (const i of p.error.issues) (errors[String(i.path[0] ?? "map")] ??= []).push(i.message);
    return validationFailed(c, errors);
  }
  const db = c.get("db"), env = c.env, current = await mapSettings(db, env);
  let token = "";
  const encryptedRow = (await db.query("select value #>> '{}' as v from app.settings where key = 'mapbox_public_token_enc'")).rows[0]?.v;
  if (encryptedRow) token = await decryptValue(encryptedRow, env.SETTINGS_ENCRYPTION_KEY).catch(() => "");
  const tokenInput = p.data.mapbox_public_token;
  if (tokenInput === null) {
    await db.query("delete from app.settings where key in ('mapbox_public_token_enc','mapbox_public_token_verified_at')");
    token = "";
  } else if (tokenInput?.trim()) {
    if (!tokenInput.startsWith("pk.")) return c.json({ message: "Use a Mapbox public access token beginning with pk." }, 422);
    if ((env.SETTINGS_ENCRYPTION_KEY ?? "").length < 32) return c.json({ message: "Configure SETTINGS_ENCRYPTION_KEY (32+ characters) before saving Mapbox credentials." }, 503);
    await saveSetting(db, "mapbox_public_token_enc", await encryptValue(tokenInput, env.SETTINGS_ENCRYPTION_KEY));
    await db.query("delete from app.settings where key = 'mapbox_public_token_verified_at'");
    token = tokenInput;
  }
  const credentialsChanged = tokenInput === null || Boolean(tokenInput?.trim());
  const styleChanged = p.data.mapbox_style_uri !== undefined && p.data.mapbox_style_uri.trim() !== current.mapbox_style_uri;
  if (styleChanged) await db.query("delete from app.settings where key = 'mapbox_public_token_verified_at'");
  const enabled = credentialsChanged || styleChanged ? false : (p.data.mapbox_enabled ?? current.mapbox_enabled);
  const regionEnabled = credentialsChanged || styleChanged ? false : (p.data.mapbox_region_bordering_enabled ?? current.mapbox_region_bordering_enabled);
  const verified = token && (await db.query("select 1 from app.settings where key = 'mapbox_public_token_verified_at'")).rowCount;
  if (enabled && (!token || !verified)) return c.json({ message: "Save a Mapbox public token and pass Test Connection before enabling Mapbox." }, 422);
  if (regionEnabled && !enabled) return c.json({ message: "Enable and validate Mapbox before enabling Mapbox region bordering." }, 422);
  let selectedProvider = p.data.provider;
  if (!enabled && selectedProvider === "mapbox" && current.provider === "mapbox") selectedProvider = "auto";
  if (selectedProvider === "mapbox" && !enabled) return c.json({ message: "Enable and validate Mapbox before selecting it." }, 422);

  await saveSetting(db, "map_provider", selectedProvider);
  await saveSetting(db, "osm_tile_url", p.data.osm_tile_url);
  await saveSetting(db, "osm_routing_url", p.data.osm_routing_url);
  await saveSetting(db, "mapbox_enabled", enabled ? "true" : "false");
  await saveSetting(db, "mapbox_region_bordering_enabled", regionEnabled ? "true" : "false");
  await saveSetting(db, "mapbox_style_uri", p.data.mapbox_style_uri?.trim() || DEFAULT_MAPBOX_STYLE);
  await saveSetting(db, "mapbox_config_updated_at", new Date().toISOString());
  await db.query("delete from app.settings where key = 'google_maps_failed_at'");
  await audit(c, "map_settings", "map_provider", { provider: selectedProvider, mapbox_enabled: enabled, mapbox_region_bordering_enabled: regionEnabled, token_changed: credentialsChanged, style_changed: styleChanged });
  return c.json({ message: "Saved" });
});

/** Validate the saved public token against the selected Mapbox style without returning it to the browser. */
mapRoutes.post("/admin/map-settings/test", ...guard("map_settings edit"), async (c) => {
  const db = c.get("db");
  const row = (await db.query("select value #>> '{}' as v from app.settings where key = 'mapbox_public_token_enc'")).rows[0]?.v;
  if (!row) return c.json({ message: "Save a Mapbox public token first." }, 422);
  let token = "";
  try { token = await decryptValue(row, c.env.SETTINGS_ENCRYPTION_KEY); }
  catch { return c.json({ message: "The saved token cannot be decrypted. Check SETTINGS_ENCRYPTION_KEY and replace the token." }, 503); }
  const styleUri = (await mapSettings(db, c.env)).mapbox_style_uri;
  const match = /^mapbox:\/\/styles\/([^/]+)\/([^/?#]+)$/.exec(styleUri);
  if (!match) return c.json({ message: "Enter a valid Mapbox style URI before testing." }, 422);
  const url = "https://api.mapbox.com/styles/v1/" + encodeURIComponent(match[1]) + "/" + encodeURIComponent(match[2]) + "?access_token=" + encodeURIComponent(token);
  try {
    const response = await fetch(url, { headers: { Accept: "application/json" } });
    if (!response.ok) return c.json({ message: response.status === 401 || response.status === 403 ? "Mapbox rejected this token or it cannot read the selected style." : "Mapbox returned HTTP " + response.status + "." }, 422);
    const testedAt = new Date().toISOString();
    await saveSetting(db, "mapbox_public_token_verified_at", testedAt);
    await audit(c, "map_settings", "mapbox_connection_test", { success: true, style_uri: styleUri });
    return c.json({ message: "Mapbox connection successful.", tested_at: testedAt });
  } catch {
    await audit(c, "map_settings", "mapbox_connection_test", { success: false });
    return c.json({ message: "Could not reach Mapbox. Check the Worker network and try again." }, 503);
  }
});
