import { Hono } from "hono";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireWebOrBearer } from "../auth/web-or-bearer";
import { MAX_UPLOAD_BYTES, newKey, sniff } from "../lib/files";

export const profilePhotoRoutes = new Hono<AppEnv>();
const mw = [withDb, requireWebOrBearer] as const;

/** Upload one authenticated user's profile image. Accepts multipart (Flutter) or raw image bytes (web). */
profilePhotoRoutes.put("/profile/photo", ...mw, async (c) => {
  if (!c.env.DOCS) return c.json({ message: "Profile photo storage is not configured.", status: 503 }, 503);
  const type = c.req.header("content-type") ?? "";
  let bytes: Uint8Array;
  if (type.includes("multipart/form-data")) {
    const form = await c.req.parseBody();
    const file = form.profile_image;
    if (!(file instanceof File)) return c.json({ message: "Choose a photo to upload.", status: 422 }, 422);
    bytes = new Uint8Array(await file.arrayBuffer());
  } else {
    bytes = new Uint8Array(await c.req.arrayBuffer());
  }
  if (!bytes.length) return c.json({ message: "Choose a photo to upload.", status: 422 }, 422);
  if (bytes.length > MAX_UPLOAD_BYTES) return c.json({ message: "Photo must be 5 MB or smaller.", status: 413 }, 413);
  const kind = sniff(bytes);
  if (!kind || kind.type === "application/pdf") return c.json({ message: "Upload a JPG, PNG or WebP image.", status: 415 }, 415);

  const me = c.get("user");
  const db = c.get("db");
  const key = newKey(`profiles/${me.id}`, "avatar", kind.ext);
  await c.env.DOCS.put(key, bytes, { httpMetadata: { contentType: kind.type } });
  const old = (await db.query("select profile_image_key from app.users where id = $1", [me.id])).rows[0]?.profile_image_key as string | null;
  try {
    await db.query("update app.users set profile_image_key = $2, updated_at = now() where id = $1", [me.id, key]);
  } catch (error) {
    await c.env.DOCS.delete(key).catch(() => undefined);
    throw error;
  }
  if (old) await c.env.DOCS.delete(old).catch(() => undefined);
  c.header("Cache-Control", "no-store");
  return c.json({ status: true, message: "Profile photo saved.", profile_image: `/api/users/${me.id}/profile-photo` });
});

/** Authenticated profile image delivery; photos are private, never exposed as public R2 objects. */
profilePhotoRoutes.get("/users/:userId/profile-photo", ...mw, async (c) => {
  if (!c.env.DOCS) return c.json({ message: "Not found", status: 404 }, 404);
  const id = /^\\d{1,15}$/.test(c.req.param("userId")) ? Number(c.req.param("userId")) : NaN;
  if (!Number.isSafeInteger(id)) return c.json({ message: "Not found", status: 404 }, 404);
  const key = (await c.get("db").query("select profile_image_key from app.users where id = $1 and deleted_at is null", [id])).rows[0]?.profile_image_key as string | null;
  if (!key) return c.json({ message: "Not found", status: 404 }, 404);
  const obj = await c.env.DOCS.get(key);
  if (!obj) return c.json({ message: "Not found", status: 404 }, 404);
  return new Response(obj.body, { headers: {
    "Content-Type": obj.httpMetadata?.contentType ?? "application/octet-stream",
    "Cache-Control": "private, no-store",
    "X-Content-Type-Options": "nosniff",
    "Content-Disposition": "inline",
  }});
});

profilePhotoRoutes.delete("/profile/photo", ...mw, async (c) => {
  if (!c.env.DOCS) return c.json({ message: "Profile photo storage is not configured.", status: 503 }, 503);
  const me = c.get("user");
  const db = c.get("db");
  const old = (await db.query("select profile_image_key from app.users where id = $1", [me.id])).rows[0]?.profile_image_key as string | null;
  await db.query("update app.users set profile_image_key = null, updated_at = now() where id = $1", [me.id]);
  if (old) await c.env.DOCS.delete(old).catch(() => undefined);
  return c.json({ status: true, message: "Profile photo removed." });
});
