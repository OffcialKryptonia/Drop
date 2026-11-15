import { Hono } from "hono";
import { z } from "zod";
import type { AppEnv } from "../env";
import { withDb } from "../db";
import { requireAuth } from "../auth/middleware";
import { readBody, validationFailed } from "../lib/legacy";
import { regionAt } from "../lib/ride-pricing";
import { equivalentService } from "../lib/region";

export const regionRoutes = new Hono<AppEnv>();
const mw = [withDb, requireAuth] as const;
const label = (r: { id: unknown; name: string | null }) => r.name?.trim() || `Region ${r.id}`;

const point = z.object({
  lat: z.coerce.number({ error: "Location is missing." }).min(-90).max(90),
  lng: z.coerce.number({ error: "Location is missing." }).min(-180).max(180),
});

async function onRide(db: import("pg").Client, userId: number): Promise<boolean> {
  return ((await db.query("select 1 from app.ride_requests where (rider_id = $1 or driver_id = $1) and status in ('searching','accepted','arrived','in_progress') limit 1", [userId])).rowCount ?? 0) > 0;
}

/**
 * Where is this phone, and is it in the region the person works in? A person with no region yet is placed in the one
 * they are standing in. Crossing into another region returns needs_confirm so the app can ask first.
 */
regionRoutes.get("/region/at", ...mw, async (c) => {
  const p = point.safeParse({ lat: c.req.query("lat"), lng: c.req.query("lng") });
  if (!p.success) return validationFailed(c, { location: ["Location is missing."] });
  const db = c.get("db");
  const me = c.get("user");
  const here = await regionAt(db, p.data);
  const cur = (await db.query(
    "select g.id, g.name from app.users u join app.regions g on g.id = u.region_id and g.status where u.id = $1", [me.id])).rows[0] ?? null;

  if (here && !cur) {
    await db.query("update app.users set region_id = $2, region_changed_at = now() where id = $1", [me.id, here.id]);
    return c.json({ status: true, region: { id: Number(here.id), name: label(here), currency: String(here.currency).trim() }, current: { id: Number(here.id), name: label(here) }, needs_confirm: false });
  }
  const region = here ? { id: Number(here.id), name: label(here), currency: String(here.currency).trim() } : null;
  const current = cur ? { id: Number(cur.id), name: label(cur) } : null;
  if (!here || !cur || Number(here.id) === Number(cur.id)) return c.json({ status: true, region, current, needs_confirm: false });

  const busy = await onRide(db, me.id);
  const prof = (await db.query("select p.service_id, p.status from app.driver_profiles p where p.user_id = $1", [me.id])).rows[0];
  let service: { id: number; name: string } | null = null;
  let can_switch = !busy;
  if (prof?.service_id && prof.status === "approved") {
    service = await equivalentService(db, Number(prof.service_id), Number(here.id));
    if (!service) can_switch = false;
  }
  return c.json({ status: true, region, current, needs_confirm: !busy, on_ride: busy, can_switch, service });
});

/** The person accepted the change: they now work in this region. Drivers move to the matching ride type there. */
regionRoutes.put("/region/me", ...mw, async (c) => {
  const body = await readBody(c);
  const p = point.extend({ region_id: z.coerce.number().int().positive() }).safeParse({ lat: body.lat, lng: body.lng, region_id: body.region_id });
  if (!p.success) return validationFailed(c, { region_id: ["Choose a region."] });
  const db = c.get("db");
  const me = c.get("user");
  const here = await regionAt(db, p.data);
  if (!here || Number(here.id) !== p.data.region_id) return c.json({ status: false, code: "not_in_region", message: "You are not inside that region right now.", }, 409);
  if (await onRide(db, me.id)) return c.json({ status: false, code: "on_ride", message: "Finish your current ride first." }, 409);

  const prof = (await db.query("select service_id, status from app.driver_profiles where user_id = $1", [me.id])).rows[0];
  let service: { id: number; name: string } | null = null;
  if (prof?.service_id && prof.status === "approved") {
    service = await equivalentService(db, Number(prof.service_id), p.data.region_id);
    if (!service) return c.json({ status: false, code: "no_matching_service", message: `${label(here)} has no ride type matching yours yet. Please contact DROP support.` }, 409);
  }
  try {
    await db.query("begin");
    await db.query("update app.users set region_id = $2, region_changed_at = now() where id = $1", [me.id, p.data.region_id]);
    if (service) {
      await db.query("update app.driver_profiles set service_id = $2 where user_id = $1", [me.id, service.id]);
      await db.query("update app.users set service_id = $2 where id = $1", [me.id, service.id]);
      await db.query("delete from app.driver_services where driver_id = $1", [me.id]);
      await db.query("insert into app.driver_services (driver_id, service_id) values ($1, $2)", [me.id, service.id]);
    }
    await db.query("commit");
  } catch (e) {
    await db.query("rollback").catch(() => undefined);
    throw e;
  }
  return c.json({ status: true, message: `You are now in ${label(here)}.`, region: { id: Number(here.id), name: label(here), currency: String(here.currency).trim() }, service });
});
