import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { sniff } from "../lib/files";

/** Vehicle pictures drawn on the map. Built-in keys fall back to icons bundled in the app until an admin uploads one. */
export const mapIconRoutes = new Hono<AppEnv>();
export const adminMapIconRoutes = new Hono<AppEnv>();

const MAX_ICON_BYTES = 1024 * 1024;

/** The icon key a ride type uses when the admin has not chosen one: from its category. */
export const iconKeyFor = (category: string | null | undefined, chosen: string | null | undefined) =>
  chosen || ({ car: "car", bike: "bike", tricycle: "keke", van: "van", bus: "van", delivery: "car_dispatch" } as Record<string, string>)[String(category ?? "")] || "car";

/** The picture itself. Public (it is only a vehicle icon) and cached; the ?v= number changes when an admin replaces it. */
mapIconRoutes.get("/map-icons/:key/image", withDb, async (c) => {
  const row = (await c.get("db").query("select file_key, content_type from app.map_icons where key = $1", [c.req.param("key")])).rows[0];
  if (!row?.file_key || !c.env.DOCS) return c.json({ message: "Not found", status: 404 }, 404);
  const obj = await c.env.DOCS.get(row.file_key);
  if (!obj) return c.json({ message: "Not found", status: 404 }, 404);
  return new Response(obj.body, { headers: { "Content-Type": row.content_type, "Cache-Control": "public, max-age=86400" } });
});

adminMapIconRoutes.get("/admin/map-icons", ...guard("map_settings list"), async (c) => {
  const rows = (await c.get("db").query("select key, label, builtin, file_key is not null as custom_image, version from app.map_icons order by builtin desc, key")).rows;
  const origin = new URL(c.req.url).origin;
  return c.json({ data: rows.map((r) => ({ ...r, url: r.custom_image ? `${origin}/api/map-icons/${r.key}/image?v=${r.version}` : null })) });
});

/** Add an extra icon slot (for example "Ambulance"). The picture is uploaded next. */
adminMapIconRoutes.post("/admin/map-icons", ...guard("map_settings edit"), async (c) => {
  const label = String((await readBody(c)).label ?? "").trim().slice(0, 40);
  if (!label) return validationFailed(c, { label: ["Give the icon a name."] });
  const base = label.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 30) || "icon";
  const db = c.get("db");
  let key = base;
  for (let n = 2; (await db.query("select 1 from app.map_icons where key = $1", [key])).rowCount; n++) key = `${base}_${n}`;
  await db.query("insert into app.map_icons (key, label, builtin) values ($1, $2, false)", [key, label]);
  await audit(c, "map_icon_add", key, { label });
  return c.json({ message: "Icon added. Upload its picture.", key });
});

/** Upload or replace the picture: raw PNG or WebP bytes in the body (transparent background, pointing up). */
adminMapIconRoutes.put("/admin/map-icons/:key/image", ...guard("map_settings edit"), async (c) => {
  if (!c.env.DOCS) return c.json({ message: "File uploads are not set up yet.", status: 503 }, 503);
  const key = c.req.param("key");
  const db = c.get("db");
  const row = (await db.query("select file_key from app.map_icons where key = $1", [key])).rows[0];
  if (!row) return c.json({ message: "Icon not found", status: 404 }, 404);
  const bytes = new Uint8Array(await c.req.arrayBuffer());
  if (bytes.length === 0) return validationFailed(c, { image: ["No file received."] });
  if (bytes.length > MAX_ICON_BYTES) return c.json({ message: "That picture is too large (1 MB maximum).", status: 413 }, 413);
  const kind = sniff(bytes);
  if (!kind || (kind.type !== "image/png" && kind.type !== "image/webp")) return c.json({ message: "Upload a PNG or WebP picture with a transparent background.", status: 415 }, 415);
  const fileKey = `map-icons/${key}-${crypto.randomUUID()}.${kind.ext}`;
  await c.env.DOCS.put(fileKey, bytes, { httpMetadata: { contentType: kind.type } });
  await db.query("update app.map_icons set file_key = $2, content_type = $3, version = version + 1, updated_at = now() where key = $1", [key, fileKey, kind.type]);
  if (row.file_key) await c.env.DOCS.delete(row.file_key).catch(() => undefined);
  await audit(c, "map_icon_upload", key, {});
  return c.json({ message: "Picture saved." });
});

/** Back to the built-in picture. */
adminMapIconRoutes.delete("/admin/map-icons/:key/image", ...guard("map_settings edit"), async (c) => {
  const key = c.req.param("key");
  const db = c.get("db");
  const row = (await db.query("select file_key from app.map_icons where key = $1", [key])).rows[0];
  if (!row) return c.json({ message: "Icon not found", status: 404 }, 404);
  await db.query("update app.map_icons set file_key = null, content_type = null, version = version + 1, updated_at = now() where key = $1", [key]);
  if (row.file_key && c.env.DOCS) await c.env.DOCS.delete(row.file_key).catch(() => undefined);
  await audit(c, "map_icon_reset", key, {});
  return c.json({ message: "Back to the built-in picture." });
});

/** Extra icons only; the six built-in ones stay. Ride types using it fall back to their category icon. */
adminMapIconRoutes.delete("/admin/map-icons/:key", ...guard("map_settings edit"), async (c) => {
  const key = c.req.param("key");
  const db = c.get("db");
  const row = (await db.query("select file_key, builtin from app.map_icons where key = $1", [key])).rows[0];
  if (!row) return c.json({ message: "Icon not found", status: 404 }, 404);
  if (row.builtin) return c.json({ message: "Built-in icons cannot be deleted. Use Reset to go back to the default picture.", status: 422 }, 422);
  await db.query("delete from app.map_icons where key = $1", [key]);
  if (row.file_key && c.env.DOCS) await c.env.DOCS.delete(row.file_key).catch(() => undefined);
  await audit(c, "map_icon_delete", key, {});
  return c.json({ message: "Deleted." });
});
