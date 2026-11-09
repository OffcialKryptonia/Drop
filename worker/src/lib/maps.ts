import type { Client } from "pg";
import type { Bindings } from "../env";

export type MapProvider = "auto" | "google" | "osm";
export const DEFAULT_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
export const DEFAULT_ROUTING_URL = "https://router.project-osrm.org";
const FAILURE_WINDOW_MS = 30 * 60 * 1000;

async function text(db: Client, key: string, fallback: string): Promise<string> {
  const v = (await db.query("select value #>> '{}' as v from app.settings where key = $1", [key])).rows[0]?.v;
  return typeof v === "string" && v ? v : fallback;
}

/**
 * Which map service DROP uses.
 *  - "google" / "osm": forced by the admin.
 *  - "auto": Google while its server key is set and it has not failed in the last 30 minutes, otherwise OpenStreetMap.
 */
export async function mapSettings(db: Client, env: Bindings) {
  const raw = await text(db, "map_provider", "auto");
  const provider: MapProvider = raw === "google" || raw === "osm" ? raw : "auto";
  const failedAt = Number(await text(db, "google_maps_failed_at", "0")) || 0;
  const googleKeySet = Boolean(env.GOOGLE_MAPS_SERVER_KEY);
  const failedRecently = failedAt > 0 && Date.now() - failedAt < FAILURE_WINDOW_MS;
  const active: "google" | "osm" = provider === "google" ? "google" : provider === "osm" ? "osm" : googleKeySet && !failedRecently ? "google" : "osm";
  return {
    provider,
    active,
    osm_tile_url: await text(db, "osm_tile_url", DEFAULT_TILE_URL),
    osm_routing_url: await text(db, "osm_routing_url", DEFAULT_ROUTING_URL),
    google_server_key_set: googleKeySet,
    google_failed_at: failedAt > 0 ? new Date(failedAt).toISOString() : null,
    google_failed_recently: failedRecently,
  };
}

/** Remembered so "auto" moves to OpenStreetMap while Google is not answering. */
export async function recordGoogleFailure(db: Client) {
  await db
    .query("insert into app.settings (key, value) values ('google_maps_failed_at', to_jsonb($1::text)) on conflict (key) do update set value = excluded.value", [String(Date.now())])
    .catch(() => {});
}
