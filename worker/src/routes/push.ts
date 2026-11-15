import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { audit, guard } from "../lib/permissions";
import { readBody, validationFailed } from "../lib/legacy";
import { encryptValue } from "../lib/crypto";
import { pushConfig, sendPush } from "../lib/push";

export const pushRoutes = new Hono<AppEnv>();

/** The apps read this at start-up to switch push notifications on. The app id is public; the REST key never leaves the server. */
pushRoutes.get("/push/config", withDb, async (c) => {
  const { appId } = await pushConfig(c.get("db"), c.env);
  return c.json({ app_id: appId });
});

pushRoutes.get("/admin/push-settings", ...guard("push_settings list"), async (c) => {
  const { appId, restKey } = await pushConfig(c.get("db"), c.env);
  const devices = (await c.get("db").query("select count(*)::int n from app.users where player_id is not null and player_id <> ''")).rows[0].n;
  return c.json({ data: { app_id: appId, key_set: Boolean(restKey), key_last4: restKey ? restKey.slice(-4) : null, devices } });
});

pushRoutes.put("/admin/push-settings", ...guard("push_settings edit"), async (c) => {
  const p = z.object({
    app_id: z.string().trim().regex(/^[0-9a-f-]{36}$/i, "Paste the OneSignal App ID (it looks like 1220ba48-ec1a-4deb-9cf2-0a0e223b3ee8).").optional(),
    rest_key: z.string().trim().min(20, "That REST API key looks too short.").max(300).optional(),
  }).safeParse(await readBody(c));
  if (!p.success) { const e: Record<string, string[]> = {}; for (const i of p.error.issues) (e[String(i.path[0] ?? "push")] ??= []).push(i.message); return validationFailed(c, e); }
  const db = c.get("db");
  if (p.data.app_id) await db.query("insert into app.settings (key, value) values ('push_app_id', to_jsonb($1::text)) on conflict (key) do update set value = excluded.value", [p.data.app_id]);
  if (p.data.rest_key) {
    if (!c.env.SETTINGS_ENCRYPTION_KEY) return c.json({ message: "The server has no encryption key set, so the key cannot be saved safely.", status: 503 }, 503);
    await db.query("insert into app.settings (key, value) values ('push_rest_key_enc', to_jsonb($1::text)) on conflict (key) do update set value = excluded.value", [await encryptValue(p.data.rest_key, c.env.SETTINGS_ENCRYPTION_KEY)]);
  }
  await audit(c, "push_settings", "push", { app_id: p.data.app_id ?? null, key_changed: Boolean(p.data.rest_key) });
  return c.json({ message: "Saved" });
});

/** Sends a test notification to one person (by email) so the admin can see push working end to end. */
pushRoutes.post("/admin/push-settings/test", ...guard("push_settings edit"), async (c) => {
  const p = z.object({ email: z.string().trim().email("Enter the person's email.") }).safeParse(await readBody(c));
  if (!p.success) return validationFailed(c, { email: ["Enter the person's email."] });
  const db = c.get("db");
  const u = (await db.query("select id, player_id from app.users where lower(email) = lower($1) and deleted_at is null", [p.data.email])).rows[0];
  if (!u) return c.json({ message: "No account has that email.", status: 404 }, 404);
  const cfg = await pushConfig(db, c.env);
  if (!cfg.appId || !cfg.restKey) return c.json({ message: "Save the App ID and REST key first.", status: 409 }, 409);
  if (!u.player_id) return c.json({ message: "That person has not allowed notifications on a phone with the new app yet.", status: 409 }, 409);
  const n = await sendPush(db, c.env, [Number(u.id)], { title: "DROP", body: "Test notification from the DROP admin." });
  return n ? c.json({ message: "Sent. It should arrive in a few seconds." }) : c.json({ message: "OneSignal did not accept it. Check the App ID and REST key.", status: 502 }, 502);
});
