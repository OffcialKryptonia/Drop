import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { readBody, validationFailed } from "../lib/legacy";
import { driverEligibility } from "../lib/commission";
import { driverOnlineBlock, requireApprovedDriver } from "../lib/roles";

export const driverOnlineRoutes = new Hono<AppEnv>();
const mw = [withDb, requireAuth, requireApprovedDriver] as const;

const coord = z.object({
  latitude: z.coerce.number({ error: "The latitude is required." }).min(-90).max(90),
  longitude: z.coerce.number({ error: "The longitude is required." }).min(-180).max(180),
});

/** What the driver home screen shows: online state, wallet against the minimum, and why going online may be blocked. */
driverOnlineRoutes.get("/driver/status", ...mw, async (c) => {
  const db = c.get("db");
  const me = c.get("user");
  const row = (await db.query("select u.is_online, p.service_id from app.users u left join app.driver_profiles p on p.user_id = u.id where u.id = $1", [me.id])).rows[0];
  const e = await driverEligibility(db, me.id, row?.service_id);
  const block = await driverOnlineBlock(db, me.id, row?.service_id);
  return c.json({
    is_online: row?.is_online === true,
    wallet: { balance: e.balance, minimum: e.minimum, eligible: e.eligible },
    online_block: block,
  });
});

/** Go online or offline. Going online needs Driver mode, valid documents and a wallet at or above the minimum. */
driverOnlineRoutes.post("/driver/online", ...mw, async (c) => {
  const body = await readBody(c);
  const wantOnline = body.online === true || body.online === "true" || body.online === 1 || body.online === "1";
  const db = c.get("db");
  const me = c.get("user");

  if (!wantOnline) {
    await db.query("update app.users set is_online = false, is_available = false where id = $1", [me.id]);
    return c.json({ status: true, is_online: false });
  }
  if (me.active_mode !== "driver") return c.json({ status: false, code: "not_in_driver_mode", message: "Switch to Driver mode first." }, 409);

  const pos = coord.safeParse(body);
  if (!pos.success) return validationFailed(c, { location: ["We need your location to go online."] });
  const prof = (await db.query("select service_id from app.driver_profiles where user_id = $1", [me.id])).rows[0];
  const block = await driverOnlineBlock(db, me.id, prof?.service_id);
  if (block) return c.json({ status: false, ...block }, 403);

  await db.query("update app.users set is_online = true, is_available = true, latitude = $2, longitude = $3 where id = $1", [me.id, pos.data.latitude, pos.data.longitude]);
  return c.json({ status: true, is_online: true });
});

/** Location ping while online. Ignored (not an error) once the driver is offline. */
driverOnlineRoutes.post("/driver/location", ...mw, async (c) => {
  const pos = coord.safeParse(await readBody(c));
  if (!pos.success) return validationFailed(c, { location: ["The location is invalid."] });
  const r = await c.get("db").query("update app.users set latitude = $2, longitude = $3 where id = $1 and is_online", [c.get("user").id, pos.data.latitude, pos.data.longitude]);
  return c.json({ status: true, updated: (r.rowCount ?? 0) > 0 });
});
