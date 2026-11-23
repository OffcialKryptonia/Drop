import type { Client } from "pg";
import type { Bindings } from "../env";
import { decryptValue } from "./crypto";

export type MapProvider = "auto" | "google" | "osm" | "mapbox";
export const DEFAULT_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
export const DEFAULT_ROUTING_URL = "https://router.project-osrm.org";
export const DEFAULT_MAPBOX_STYLE = "mapbox://styles/mapbox/streets-v12";
const FAILURE_WINDOW_MS = 30 * 60 * 1000;

async function text(db: Client, key: string, fallback: string): Promise<string> {
  const v = (await db.query("select value #>> '{}' as v from app.settings where key = $1", [key])).rows[0]?.v;
  return typeof v === "string" && v ? v : fallback;
}
async function flag(db: Client, key: string): Promise<boolean> {
  const v = await text(db, key, "false");
  return v === "true" || v === "1";
}
async function mapboxToken(db: Client, env: Bindings): Promise<string> {
  const encrypted = await text(db, "mapbox_public_token_enc", "");
  if (!encrypted) return "";
  try { return await decryptValue(encrypted, env.SETTINGS_ENCRYPTION_KEY); } catch { return ""; }
}

/** Mapbox activates only when enabled and its saved public token has passed the admin connection test. */
export async function mapSettings(db: Client, env: Bindings) {
  const raw = await text(db, "map_provider", "auto");
  const provider: MapProvider = raw === "google" || raw === "osm" || raw === "mapbox" ? raw : "auto";
  const failedAt = Number(await text(db, "google_maps_failed_at", "0")) || 0;
  const googleKeySet = Boolean(env.GOOGLE_MAPS_SERVER_KEY);
  const failedRecently = failedAt > 0 && Date.now() - failedAt < FAILURE_WINDOW_MS;
  const token = await mapboxToken(db, env);
  const mapboxEnabled = await flag(db, "mapbox_enabled");
  const verifiedAt = await text(db, "mapbox_public_token_verified_at", "");
  const mapboxConfigured = Boolean(token.startsWith("pk.") && verifiedAt);
  const mapboxAvailable = mapboxEnabled && mapboxConfigured;
  const regionBorderingEnabled = mapboxAvailable && await flag(db, "mapbox_region_bordering_enabled");
  const fallback: "google" | "osm" = googleKeySet && !failedRecently ? "google" : "osm";
  let active: "google" | "osm" | "mapbox";
  let fallbackReason: string | null = null;
  if (provider === "mapbox") {
    if (mapboxAvailable) active = "mapbox";
    else { active = fallback; fallbackReason = "Mapbox is selected but is not enabled and validated; using the existing fallback provider."; }
  } else if (provider === "google") active = "google";
  else if (provider === "osm") active = "osm";
  else active = fallback;

  return {
    provider, active, fallback_reason: fallbackReason,
    osm_tile_url: await text(db, "osm_tile_url", DEFAULT_TILE_URL),
    osm_routing_url: await text(db, "osm_routing_url", DEFAULT_ROUTING_URL),
    google_server_key_set: googleKeySet,
    google_failed_at: failedAt > 0 ? new Date(failedAt).toISOString() : null,
    google_failed_recently: failedRecently,
    mapbox_enabled: mapboxEnabled,
    mapbox_configured: mapboxConfigured,
    mapbox_connection_status: mapboxConfigured ? "validated" : token ? "not_tested" : "missing",
    mapbox_public_token_set: Boolean(token),
    mapbox_public_token_masked: token ? "••••" + token.slice(-4) : "",
    mapbox_public_token: active === "mapbox" ? token : null,
    mapbox_style_uri: await text(db, "mapbox_style_uri", DEFAULT_MAPBOX_STYLE),
    // Optional night style. Empty = the app picks the matching official dark style (streets/outdoors/light -> dark-v11).
    mapbox_dark_style_uri: await text(db, "mapbox_dark_style_uri", ""),
    mapbox_region_bordering_enabled: regionBorderingEnabled,
    mapbox_last_verified_at: verifiedAt || null,
    mapbox_last_updated_at: await text(db, "mapbox_config_updated_at", ""),
  };
}

export async function recordGoogleFailure(db: Client) {
  await db.query("insert into app.settings (key, value) values ('google_maps_failed_at', to_jsonb($1::text)) on conflict (key) do update set value = excluded.value", [String(Date.now())]).catch(() => {});
}
